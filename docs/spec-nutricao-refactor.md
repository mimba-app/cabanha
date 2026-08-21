# Spec — Refactoring de Nutrição (persistência + templates configuráveis + múltiplos itens)

> Pedido do Luciano (2026-08-21), 3 pontos: projeto nutricional não salva no banco, precisa
> poder criar novos templates, e precisa poder ter mais de um item do mesmo tipo dentro de um
> template/projeto (ex.: animal consome dois tipos de ração). Diagnóstico feito lendo o código
> real de `index.html` antes de propor solução — não é um bug de sincronização, é um módulo que
> nunca teve backend.

## 1. Diagnóstico

Toda a seção de Nutrição (`index.html`, bloco `── NUTRIÇÃO ──`, linha ~7369 em diante) roda
**inteiramente em memória do navegador**. Confirmado por busca — zero ocorrências de `_supa(`,
`fetch`, ou qualquer chamada de rede em toda a seção de Nutrição:

```js
let nutProj = {};
animais.forEach((a,i) => { nutProj[i] = nutVazio(); });
```

Esse objeto é **recriado do zero, vazio**, toda vez que a página carrega (`animais.forEach`
sobrescreve `nutProj` no boot). Qualquer edição feita pelo usuário (`salvarNutItem`,
`salvarSupl`, `aplicarTemplate`) só grava nesse objeto em memória — no F5 seguinte, some. Isso
explica exatamente o sintoma reportado: "salva na seção mas não vai pro banco" — porque nunca
houve banco.

Os templates (`NUT_TEMPLATES`, linha ~7392) são uma constante JS hardcoded com **exatamente 7
chaves fixas** (`CAMPO`, `PISTA MORFOLOGIA`, `PISTA FUNCIONAL`, `ARREIO CABANHA`, `LAÇO`, `DOMA`,
`CRIA` — meio que espelha o enum de `estagio` do animal). Existe um mecanismo de
"personalização" (`nutTemplatesCustom`), mas ele **também só vive em memória** — o comentário no
próprio código admite isso: `// persiste no save`, referindo-se a um "backup" que não existe mais
no fluxo atual (era um resquício da versão antiga de salvar/carregar arquivo, removida na
Prioridade 2 do ROADMAP). Não dá pra criar um 8º template — a UI de edição
(`abrirEditarTemplate`) só sabe editar uma das 7 chaves já existentes.

Cada projeto/template tem **5 slots fixos**: `racao`, `aveia`, `alfafa`, `verde`, `sal` — cada um
um objeto único (`{produto, qty, freq, obs}`), não uma lista. É por isso que não dá pra ter dois
tipos de ração: o segundo simplesmente sobrescreveria o primeiro no mesmo campo `racao`. Os
únicos itens que já são lista hoje são os **suplementos** (`suplementos: []`) — o padrão certo já
existe no código, só não foi aplicado aos outros 5 componentes.

**Resumindo os 3 pedidos e a causa de cada um:**

| Pedido do Luciano | Causa raiz |
|---|---|
| Não salva no banco | Nunca existiu chamada de banco — `nutProj` é 100% client-side |
| Criar novos templates | `NUT_TEMPLATES` é uma constante JS com 7 chaves fixas, sem CRUD |
| Múltiplos itens do mesmo tipo | `racao`/`aveia`/`alfafa`/`verde`/`sal` são campos únicos, não arrays — só `suplementos` já era array |

## 2. Objetivo

1. Projeto nutricional por animal persiste de verdade no Supabase (schema por tenant, mesmo
   padrão do resto do app).
2. Templates deixam de ser uma constante JS fixa e viram registros no banco — o usuário
   (adm/vet) pode criar, renomear e excluir templates livremente, não só editar os 7 que já
   existem.
3. Tanto templates quanto projetos por animal usam uma **lista de itens**, não campos fixos —
   qualquer quantidade de itens do mesmo tipo (dois tipos de ração, dois suplementos com o mesmo
   nome em dosagens diferentes, etc.).
4. Suplementos deixam de ser um caso especial à parte — viram só mais um tipo de item na mesma
   lista, unificando o modelo.

## 3. Modelo de dados novo

Duas entidades, cada uma com uma tabela "cabeçalho" e uma tabela "itens" (1:N) — mesmo padrão
já usado no projeto (ex.: `acasalamentos` + `reproducao_atividades`).

### 3.1 Templates

```sql
create table if not exists public.nutricao_templates (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  estagio_vinculado text,  -- opcional: sugere este template quando o animal tem esse estagio
                            -- (mesmo enum de animais.estagio) — não obrigatório, não único
  obs text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);

create table if not exists public.nutricao_template_itens (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.nutricao_templates(id) on delete cascade,
  tipo text not null,       -- 'racao' | 'aveia' | 'alfafa' | 'verde' | 'sal' | 'suplemento' | 'outro'
                             -- livre o suficiente pra não precisar migration a cada categoria nova
  produto text,
  marca text,                -- relevante sobretudo pra suplemento; vazio nos demais tipos
  quantidade text,           -- mantém texto livre como já era ("2 kg/dia") — não virar numérico
                              -- agora, ver nota na seção 6
  frequencia text,
  periodo text,               -- ex.: "pré-morfologia", só usado por suplemento hoje
  obs text,
  ordem integer not null default 0,
  criado_em timestamptz not null default now()
);
```

### 3.2 Projetos por animal

```sql
create table if not exists public.nutricao_projetos (
  id uuid primary key default gen_random_uuid(),
  animal_id uuid not null references public.animais(id),
  dt_inicio date,
  dt_fim date,
  status text not null default 'ativo' check (status in ('ativo','finalizado')),
  obs_projeto text,
  template_origem_id uuid references public.nutricao_templates(id),
    -- rastreia de qual template este projeto nasceu (nullable — projeto pode ser criado do zero)
  med_inicial jsonb,   -- {cernelha, torax, canela, peso, escore, data, obs} — mantém como hoje,
  med_final   jsonb,   -- não vale a pena normalizar agora (ver seção 6)
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);

create table if not exists public.nutricao_projeto_itens (
  id uuid primary key default gen_random_uuid(),
  projeto_id uuid not null references public.nutricao_projetos(id) on delete cascade,
  tipo text not null,
  produto text,
  marca text,
  quantidade text,
  frequencia text,
  periodo text,
  obs text,
  ordem integer not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
```

**Por que projeto é uma tabela "cabeçalho + histórico" e não 1 linha fixa por animal:** a UI já
tem um botão "Finalizar projeto" (`status_proj='finalizado'`) — ou seja, o produto já pensa em
projeto como algo com ciclo de vida, não um cadastro único e eterno por animal. Modelar como
`nutricao_projetos` com `animal_id` (não únique) permite histórico real: quando o criador
finaliza um projeto e começa outro, o antigo continua consultável, em vez de ser sobrescrito.
A tela de "projeto ativo do animal" simplesmente filtra `status='ativo'` (deveria ser no máximo 1
por animal — vale um índice único parcial, ver seção 5).

## 4. Migração dos 7 templates hardcoded existentes

Pra ninguém perder o que já está calibrado (`CAMPO`, `PISTA MORFOLOGIA` etc.), a migration que
cria as tabelas já faz o **seed** dos 7 templates atuais como registros reais em
`nutricao_templates`/`nutricao_template_itens`, com `estagio_vinculado` preenchido igual à chave
que tinham hoje. Depois disso, `NUT_TEMPLATES` (a constante JS) pode ser removida do código —
tudo vira dado.

## 5. RLS, provisionamento, replicação nos tenants

Segue o padrão já estabelecido (ver `docs/migrations/2026-08-13-reprodutivo-v4-fase0.sql` como
referência de forma, e a skill `nova-migration-tenant`):

- As 4 tabelas nascem no template `public` **com RLS ligada e sem grant a `anon`** desde o
  início (não repetir o achado de segurança do Reprodutivo v4 Fase 0, onde tabelas novas
  nasceram abertas por padrão do Postgres).
- Policies `select/insert/update/delete` para `authenticated`, via `tem_acesso_tenant(<tenant_id>)`
  — mesmíssimo padrão das outras tabelas operacionais.
- Replicar em todos os 7 schemas `cab_*` já provisionados (bloco `do $$ ... loop` sobre
  `public.tenants where provisionado = true`).
- Atualizar `provisionar_schema_cabanha()` pra que cabanhas novas herdem as 4 tabelas — como são
  simples (`LIKE ... INCLUDING ALL` já cobre estrutura+RLS+grants de tabela nova no template),
  só confirmar que entram no array `v_tabelas` da RPC, sem precisar de lógica extra (ao contrário
  das FKs manuais que o Reprodutivo v4 precisou).
- Índice único parcial pra impedir dois projetos "ativo" simultâneos no mesmo animal:
  `create unique index on nutricao_projetos (animal_id) where status = 'ativo';`
- `revisor-isolamento` roda antes do PR (toca RLS/tabela nova, mesmo sendo mecânico).

## 6. O que **não** entra nesta rodada (decisão consciente, registrar e seguir)

- **Não normalizar `quantidade` pra numérico+unidade agora.** Continua texto livre
  ("2 kg/dia", "À vontade") como já é hoje. Bom pra fazer depois (destravaria soma real na Lista
  de Compras sem parsing frágil de string — ver `renderCompras()`, que já faz
  `parseFloat((n.racao.qty||'0').replace(',','.'))` hoje, um parsing best-effort que quebra
  silenciosamente pra "À vontade" etc.), mas normalizar unidade é escopo de produto separado
  (decidir unidades permitidas, conversão), não faz parte de resolver os 3 pedidos originais.
- **Não normalizar `med_inicial`/`med_final` em colunas** — ficam como `jsonb`, mesmo formato
  de hoje. Baixo ganho em separar agora.
- **Não trocar a chave de indexação client-side de array-index (`animais.indexOf(a)`) por
  `animal_id`/`db_id` em todo o resto do app** — é um padrão usado em várias outras seções
  (vacinas, exames, medidas), não é escopo deste refactor mudar o app inteiro. Mas **dentro do
  código novo de Nutrição**, usar `animal_id` (o `db_id` real) como chave, não o índice do array
  — já que agora existe uma tabela real com FK de verdade, não faz sentido reintroduzir a
  fragilidade do índice posicional num código que está sendo escrito do zero.

## 7. Frontend — o que muda em `index.html`

- **Bootstrap**: `carregar_dados_cabanha()` (RPC de login) precisa passar a trazer
  `nutricao_templates`+itens e `nutricao_projetos`+itens junto do payload — hoje não traz nada
  disso (é código 100% novo pra essa RPC). Seguir o mesmo formato que ela já usa pra outras
  entidades (array de objetos com itens aninhados, montado em SQL).
- **`nutProj`** deixa de ser inicializado vazio no boot — passa a ser montado a partir do que
  veio do bootstrap, indexado por `animal_id`.
- **Persistência**: toda função que hoje só muta `nutProj[i]` (`salvarNutItem`, `salvarSupl`,
  `removerSupl`, `aplicarTemplate`, finalizar projeto) precisa de uma chamada real ao Supabase
  logo em seguida — criar `_dbSalvarProjetoNutricional`, `_dbSalvarItemNutricional`,
  `_dbExcluirItemNutricional`, seguindo o padrão de `_dbSalvarTratamento`/`_dbExcluirTratamento`
  já existente no app.
- **UI de itens**: os 5 blocos fixos (Ração/Aveia/Alfafa/Verde/Sal) na tela de projeto e na tela
  de template viram uma lista renderizada dinamicamente (`itens.map(...)`), com um botão
  "+ Adicionar item" que abre o mesmo modal de item hoje usado só pra editar um dos 5 fixos —
  só que agora sem `field` fixo, perguntando o `tipo` também (select, não mais implícito pelo
  botão que foi clicado).
- **Templates — CRUD novo**: `renderTemplatesPage()` deixa de iterar um array fixo de 7 estágios
  e passa a iterar `nutricao_templates` carregado do banco. Novo botão "+ Novo template" (nome +
  estágio vinculado opcional, começa vazio ou copiando um existente). Excluir um template não
  apaga projetos que nasceram dele (`template_origem_id` fica órfão, o que é aceitável — o
  projeto já foi "copiado" pro animal no momento da aplicação, exatamente como funciona hoje com
  `{...JSON.parse(JSON.stringify(tmpl))}`).
- **Lista de Compras** (`renderCompras()`): a agregação por produto já usa um objeto chaveado por
  nome do produto (`racoes[key]`) — isso generaliza de graça pra "N itens tipo ração" contanto
  que a função passe a iterar a lista de itens do projeto em vez dos 5 campos fixos
  (`n.racao`, `n.aveia`, ...). Suplementos já funcionavam assim — replicar o mesmo `forEach` pros
  demais tipos.

## 8. Fases sugeridas

1. **Fase 0 — Schema**: migration completa (tabelas, RLS, seed dos 7 templates, replicação nos
   tenants, provisionamento). Sem tocar frontend ainda.
2. **Fase 1 — Bootstrap + carregar do banco**: `carregar_dados_cabanha()` passa a trazer os dados
   novos; `nutProj` passa a nascer preenchido do banco (ainda sem salvar edições — só leitura,
   pra validar que o modelo bate com o que a UI espera antes de plugar escrita).
3. **Fase 2 — Persistência de projeto por animal**: salvar/editar/excluir item, suplemento,
   finalizar projeto — tudo grava no banco de verdade.
4. **Fase 3 — Templates configuráveis**: CRUD completo de template (criar/renomear/excluir/editar
   itens), aplicar template a animal lendo do banco em vez da constante JS. Remove
   `NUT_TEMPLATES`/`nutTemplatesCustom` do código.
5. **Fase 4 — Múltiplos itens do mesmo tipo na UI**: ajustar telas de projeto e template pra
   lista dinâmica (já é consequência natural do modelo de dados da Fase 0, mas vale como fase
   separada pra isolar risco visual do risco de dado).

## 9. Referências rápidas

| O quê | Onde |
|---|---|
| Código atual de Nutrição (a ser substituído) | `index.html`, bloco `── NUTRIÇÃO ──`, linha ~7369 |
| Padrão de tabela cabeçalho+itens de referência | `docs/migrations/2026-08-13-reprodutivo-v4-fase0.sql` (`tratamentos`, `reproducao_atividades`) |
| Skill de migration que reflete em todos os tenants | `.claude/skills/nova-migration-tenant/SKILL.md` |
| Bootstrap de login (onde plugar a leitura) | RPC `carregar_dados_cabanha()` |
