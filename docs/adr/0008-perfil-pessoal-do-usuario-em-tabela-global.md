# 0008 — Perfil pessoal do usuário: tabela global em `public`, não `usuarios_master`

**Status:** Aceito (2026-08-25).

## Contexto
"Meu Perfil" (Conta → Meu Perfil) grava `nome`, `cargo`, `telefone_pessoal`, `notif_email`, `idioma`,
`fuso_horario`, `foto_url` com:

```js
_supaPub('PATCH', 'usuarios_master', patch, '?id=eq.' + usuarioAtual.id);
```

Isso está quebrado de duas formas independentes:

1. **Id do espaço errado.** `usuarioAtual.id` é montado em `_entrarCabanha()` (index.html ~16178) a partir
   de `GET usuarios ?auth_user_id=eq.<auth uid>` — o `id` da linha em `usuarios` **do schema da cabanha
   ativa** (`cab_<slug>`), por-tenant. `usuarios_master` vive em `public` (control-plane) e tem seu
   próprio espaço de `id`. O `PATCH` filtra `usuarios_master.id = <id de outro schema>` — não bate
   nenhuma linha, quase sempre.
2. **RLS já fecha a porta mesmo se o id acertasse.** A migration
   `docs/migrations/2026-08-23-otimizacao-performance-indices-rls.sql` (linha 203) tem
   `usuarios_master` com policy `service_role only`. Uma sessão `authenticated` normal (usuário logado no
   app) não tem `UPDATE` nessa tabela de jeito nenhum — RLS bloqueia antes mesmo do filtro de id importar.

Como `_supaPub` usa `Prefer: return=minimal`, um `PATCH` de 0 linhas ainda retorna `204` — o app mostra
"✅ Perfil atualizado" mesmo sem gravar nada. Os campos também nunca são lidos do banco no login (só ficam
em `usuarioAtual` via `Object.assign` local pós-save, na mesma sessão) — um F5 ou novo login reseta a tela.

`usuarios_master` é legada: é a tabela do login antigo (senha em texto puro comparada via query string,
substituído pelo Supabase Auth — ver ADR 0002) e tem seu próprio `senha_hash`, desconectado do
`auth.users` atual. Uma sessão anterior (Fase 3 da V1.5, `docs/roadmap-v15.md` linhas 75-79) já bateu no
mesmo problema pro painel admin da plataforma e **optou por não reaproveitar `usuarios_master`**, criando
`mimba_staff` do zero em vez de tentar consertá-la. Outra sessão (migration
`2026-08-26-add-crmv-usuarios.sql`) chegou à mesma conclusão pro campo `crmv`: usou `usuarios` por-tenant
(que já é carregado de verdade no login) em vez de estender `usuarios_master`.

A identidade hoje é **identity-first** (ADR 0002): `auth.users` (global) + `tenant_memberships` (N
cabanhas por identidade, um `perfil` — adm/vet/cab — por membership). Uma pessoa pode ter N linhas
diferentes em `usuarios` (uma por schema `cab_*` onde tem acesso).

## Decisão
Criar uma tabela nova em `public` (control-plane), **1:1 com a identidade global**, não com o tenant.
Nome final: `preferencias_usuario` (não `perfil_usuario` — já existe um ENUM `public.perfil_usuario`
usado em `usuarios.perfil`, colidiria):

```sql
create table public.preferencias_usuario (
  auth_user_id    uuid primary key references auth.users(id) on delete cascade,
  cargo           text,
  telefone_pessoal text,
  foto_url        text,
  notif_email     boolean not null default true,
  idioma          text not null default 'pt-BR',
  fuso_horario    text not null default 'America/Sao_Paulo',
  updated_at      timestamptz not null default now()
);

alter table public.perfil_usuario enable row level security;

create policy self_select on public.perfil_usuario for select
  using (auth_user_id = (select auth.uid()));
create policy self_upsert on public.perfil_usuario for insert
  with check (auth_user_id = (select auth.uid()));
create policy self_update on public.perfil_usuario for update
  using (auth_user_id = (select auth.uid()));
```

- `nome` **continua** em `usuarios` por schema `cab_*` — já funciona hoje (é lido de verdade no login via
  `_entrarCabanha`), e nome de exibição por-cabanha não é um problema real que precise de solução (ex.:
  alguém pode preferir aparecer diferente numa cabanha de consultoria vs. na própria). Não mexer.
- `crmv` continua em `usuarios` por schema `cab_*`, como já decidido na migration de 26/08.
- Os 6 campos de preferência pessoal (`cargo`, `telefone_pessoal`, `foto_url`, `notif_email`, `idioma`,
  `fuso_horario`) passam a viver em `perfil_usuario`, chaveados por `auth_user_id` — carregados uma vez no
  login (junto com `minhas_cabanhas()` ou uma RPC/`GET` própria) e reaproveitados em qualquer cabanha que a
  pessoa entrar na mesma sessão.
- `perfil_usuario` **não é clonada pelo provisionamento** — não é template por-tenant, é control-plane,
  igual `tenants`/`tenant_memberships`/`mimba_staff`. Isso é intencional: a regra "migration no template
  reflete em todos os `cab_*`" (skill `nova-migration-tenant`) não se aplica aqui.

## Consequências
- (+) Corrige o bug na raiz: o filtro passa a ser `auth_user_id = auth.uid()` — sempre o id certo, sem
  depender de nenhum id por-tenant vazando pro control-plane.
- (+) RLS por linha própria (`auth.uid()`) é mais simples e mais segura que reabrir `usuarios_master` pra
  `authenticated` — não precisa tocar numa tabela legada que carrega `senha_hash` e outras colunas do login
  antigo.
- (+) Preferências pessoais (idioma, fuso, foto, notificação) ficam corretamente **por pessoa**, não
  duplicadas por cabanha — evita a pessoa ter que reconfigurar em cada cabanha que acessa.
- (−) `cargo` e `telefone_pessoal` também ficam globais por essa decisão, mas são conceitualmente mais
  discutíveis (alguém pode ter cargo diferente em cada cabanha, ex.: dono numa e consultor técnico noutra).
  Hoje não há evidência de que isso seja um problema real nem pedido de usuário — manter simples (global)
  e só criar um caminho por-tenant se aparecer uma necessidade concreta (viraria outro ADR).
- (−) Fica pendente, fora do escopo desta decisão (é implementação, não arquitetura): carregar
  `perfil_usuario` no login (hoje só `usuarios` por-tenant é lido) e popular `usuarioAtual` com esses
  campos antes de abrir a tela "Meu Perfil" — sem isso, ainda que o PATCH passe a acertar a linha certa, a
  tela reabre vazia após F5/novo login até esse carregamento existir.
- (−) `usuarios_master` fica intocada, órfã — nenhum código do app escreve nela depois desta mudança
  (nunca escreveu de fato, dado o bug). Não decido aqui se ela deve ser dropada; é dado potencialmente
  sensível de um sistema de login descontinuado, então isso merece checagem própria (linhas, dependências)
  antes de qualquer DROP — não fazer isso "de brinde" numa migration que resolve outro problema.
- Toca RLS/dado pessoal do usuário → passa pelo `revisor-isolamento` antes do PR, mesmo sendo uma tabela
  nova pequena (política de "só a própria linha" é simples, mas ainda é RLS).

## Confirmação pendente (SQL, fica pro Pedro ou pra próxima sessão com MCP autorizado)
Esta sessão não teve acesso ao Supabase MCP (sem autorização) pra checar o estado real de
`usuarios_master`:
- `select count(*) from public.usuarios_master;` — quantas linhas existem hoje.
- `select id, nome, cargo, telefone_pessoal from public.usuarios_master limit 20;` — se há dado real que
  valeria migrar manualmente pra `perfil_usuario` (ex.: fotos/telefones que alguém já cadastrou, mesmo que
  o PATCH nunca tenha persistido — pode haver linhas de um cadastro inicial/seed anterior ao bug).
- Confirmar que nenhuma Edge Function ou RPC lê/escreve `usuarios_master` hoje além do que já está
  documentado (Fase 3 do roadmap já afirma que não; vale um `grep` cross-check na pasta de functions numa
  sessão com esse acesso).

## Alternativas consideradas
- **Opção A — ressuscitar `usuarios_master`** (religar `auth_user_id` → `auth.users.id`, ajustar RLS pra
  `authenticated` na própria linha). Rejeitada: exige tocar RLS de uma tabela legada que carrega colunas do
  sistema de login antigo (`senha_hash` etc.), misturando o conserto com uma tabela que duas sessões
  anteriores já escolheram deliberadamente não reaproveitar (`mimba_staff`, `crmv` em `usuarios`). Uma
  tabela nova e limpa é mais fácil de revisar (`revisor-isolamento`) e não carrega dívida alheia.
- **Opção C — campos em `tenant_memberships`** (por cabanha). Rejeitada pros 4 campos claramente pessoais
  (`foto_url`, `idioma`, `fuso_horario`, `notif_email`): duplicaria e permitiria divergência de algo que é
  a mesma pessoa preenchendo o mesmo formulário de preferências — sem ganho nenhum, só mais estado pra
  manter sincronizado.
