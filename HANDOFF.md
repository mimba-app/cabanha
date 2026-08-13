# Handoff — Mimba · checkpoint 2026-08-02

> Documento de retomada. Condensa o que já foi construído e o que falta. **Não contém segredos.**

## Como retomar (2 trilhas)
- **App/produto Mimba:** sessão em `projetos/cabanha` → *"lê o HANDOFF.md e vamos continuar"*. Carregam sozinhos: CLAUDE.md, memória (`MEMORY.md`), subagentes (`revisor-isolamento`, `arquiteto`, `engenheiro-frontend`) e skills (`nova-migration-tenant`, `deploy`, `testar-provisionamento`).
- **Landing:** sessão em `projetos/mimba-landing` (repo `mimba-app/mimba-landing`, clonado). O `index.html` é um bundle gerado; as páginas `/assinar` e `/obrigado` são hand-authored (editáveis à vontade).

## 🔴 O MAIS IMPORTANTE PRA SABER AGORA
Toda a maratona de correções desde a apresentação (ver `ROADMAP.md` + seções abaixo) está **só na branch `staging`**, publicada em **`https://mimba-hml.pages.dev/`** via Cloudflare Pages — **nada disso está em produção** (`app.mimba.com.br`, branch `main`) ainda. A `main` só tem o que foi feito antes da `staging` existir. **Decisão pendente há várias sessões: promover `staging` → `main`?** (`git checkout main && git merge staging` + skill `deploy`, depois de testar tudo na URL de staging).

Isso já mordeu na prática: quando o Thiago (sócio, admin da Cabanha Santa Adelina — cliente real) precisou de um reenvio de convite, o botão que resolve isso só existe na `staging`, e a `staging` só mostra cabanhas com `ambiente_teste=true` — foi preciso marcar a cabanha dele como teste temporariamente pra usar o fluxo. **Enquanto a promoção não acontece, todo suporte a cliente real por esse tipo de fluxo depende desse contorno.**

## 🎨 Paleta de cores revertida pra skin verde-oliva/creme (2026-08-12, staging apenas)
Pedido do Pedro: recuperar exatamente a paleta de um arquivo de referência (`index_7.html`, anexado por
ele) que ele identificou como "a skin oficial definida". **Achado antes de aplicar**: esse arquivo é, na
verdade, um export de antes do rebranding Mimba — título "Cabanha Mãe de Deus — Sistema de Gestão", sidebar
"Cavalos Crioulos · ABCCC" (sem logo/marca Mimba), zero ocorrências de `Mimba`/`ouro`/`terra` no arquivo.
Isso diverge da paleta terra/ouro/campo/creme que estava documentada como identidade da marca desde o
redesign de 2026-08-02 (seção abaixo) e no `CLAUDE.md`. **Sinalizado explicitamente ao Pedro antes de mexer
— ele confirmou que queria mesmo assim.** Aplicado:
- `:root` do `index.html` trocado pra paleta verde-oliva (`--green: #639922`) + fundo creme neutro
  (`--bg: #f5f4f0`), igual ao arquivo de referência, light e dark mode.
- `--ouro` (única variável de acento "dourado", usada só no título "Mimba" da tela de login) foi mantida
  como variável (não removida, evita quebrar o CSS que a referencia) mas **realinhada ao verde** — o
  arquivo de referência não tem conceito de acento dourado separado, então sem isso o título ficaria com
  cor indefinida.
- `--card-neutral`/`--card-neutral-border` (cinza neutro do card de conta na sidebar, adicionado depois da
  época do arquivo de referência) **mantidos como estavam** — não existe equivalente no arquivo antigo, e
  são só um cinza de UI, não fazem parte do debate de "verde vs. terra".
- `CLAUDE.md` atualizado pra não descrever mais a paleta antiga como a oficial.
- Testado visualmente (light + dark) via servidor estático local — login e dashboard sem nenhum traço de
  marrom, confirmando a causa da reclamação original ("o marrom que mudou") não era um bug, era mesmo a
  paleta terra/ouro que estava em produção/staging até aqui.
- **Só aplicado no `staging`**, por pedido explícito — `main` continua com a paleta anterior até decisão.

## 🎨 Redesign visual da casca (2026-08-02)
Pedido do sócio: a sidebar/navegação estava com "cara de vibe coding" (emoji cru como ícone de menu, marca ausente
quando a cabanha não tem logo própria cadastrada). Feito:
- **Sidebar**: os 12 ícones de navegação (emoji: 🐴🌾🏆🤰📦📏🧬 + símbolos ⊞✚♡$) viraram um conjunto único de ícones
  SVG geométricos (`stroke=currentColor, stroke-width=2`, mesmo padrão da engrenagem/logout que já existiam).
  Indicador de aba ativa (barra verde à esquerda). Marca "Mimba" (Playfair serif) agora **sempre visível** no topo
  da sidebar com um monograma "M" de fallback — antes, cabanha sem logo própria não mostrava marca nenhuma.
- **Corpo das páginas**: auditoria (subagente Explore) mapeou ~230 ocorrências de emoji funcional fora da sidebar.
  Duas passadas de limpeza (`engenheiro-frontend`, sequenciais) resolveram a maioria: semáforo 🔴🟡🟢 (já tinha
  classe `.badge`), pares condicionais 💉🔬/📄🖼️/📷🎬 (centralizados em `_iconX()` reutilizáveis), botões repetidos
  ✏️💾✕🔍📋, ~150 emojis de seção em títulos/badges/alertas. Ficou de fora de propósito: ✅✓⚠ em toasts (UX padrão),
  ♂♀ em contexto reprodutivo (símbolo científico), cauda longa de uso único.
- **Status:** validado visualmente (servidor estático local + injeção de sessão fake). **Ainda não confirmado que o
  sócio revisou/aprovou** — era o objetivo original do pedido, retomar quando ele der retorno.

## 🔥 Incidente breve: rename de `coberturas` quebrou login de toda cabanha (2026-08-02, resolvido em minutos)
Ao aplicar a Fase 0 do Reprodutivo v3 (renomear a tabela legada `coberturas` → `coberturas_arquivadas_legado`),
esqueci de atualizar quem ainda lia dessa tabela pelo nome antigo: a RPC `carregar_dados_cabanha` — chamada
**no boot de login de toda cabanha** — e mais 4 pontos do frontend (excluir cobertura, timeline do animal,
salvar cobertura na tela antiga de Reprodutivo). Efeito: login/carregamento de dados quebrado pra **todo
tenant**, staging e produção, por alguns minutos até o hotfix. Corrigido: RPC atualizada pra ler de
`coberturas_arquivadas_legado` (mantendo a chave `coberturas` no JSON de retorno, pra não quebrar quem ainda
lê `bootstrap.coberturas` até a Fase 5 remover a tela antiga de vez); os 4 pontos do frontend também
apontados pro novo nome.
⚠️ **Lição pra próximas migrations de rename/drop**: antes de renomear/derrubar uma tabela, grep no
`index.html` **e** em todas as funções `public.*` por chamadas diretas ao nome antigo (`_supa('...',
'nome_tabela', ...)` no frontend, `%I.nome_tabela` em SQL dinâmico) — não basta revisar RLS/isolamento, o
`revisor-isolamento` não pega esse tipo de quebra de contrato de nome (não é um problema de isolamento entre
tenants, é global).

## 🐛 Convite de usuário — ciclo completo de correções (fins de julho → 2026-08-02)
Começou como um bug simples ("reconvidei e disse que já existia") e virou uma revisão de ponta a ponta do fluxo de
primeiro acesso. Estado final, `convidar-usuario` (edge function) na **v7**:

1. **v3** — dois bugs de reconvite: `revogar_acesso_usuario` só marca `ativo=false` (nunca apaga a linha), então
   reconvidar batia em 409 até a função aprender a reativar em vez de bloquear; `identidadeNova` (decide o texto do
   e-mail) agora checa `last_sign_in_at IS NULL` via Admin API, não só "acabei de criar agora". `vincular_usuario_cabanha`
   (RPC) virou idempotente (upsert por `login`).
2. **v4/v5 (tentativa 1, insuficiente)** — e-mail corporativo "consumia" o link de definir senha antes da pessoa
   clicar (gateway de segurança tipo Safe Links visita todo link automaticamente). Mandar link + código juntos
   "como alternativa" pareceu resolver, mas **não resolvia**: confirmado nos logs do Auth que os dois compartilham
   o mesmo token por baixo — usar (ou só visitar) qualquer um invalida o outro.
3. **v5/v6 (fix de verdade)** — e-mail de identidade nova manda **só o código de 6 dígitos**, sem link clicável
   (o botão vira link comum pra home, sem poder de autenticar — visitável à vontade por qualquer scanner).
   Tela de login ganhou "Tenho um código de acesso" (`_toggleCodigoAcesso`/`confirmarCodigoAcesso`), que troca o
   formulário inteiro em vez de empilhar. Mensagens de erro sempre em português. Atalho `APP_URL/?acesso=codigo`
   no botão do e-mail abre esse painel automaticamente (`_checkAcessoCodigo`). Badge "Convite pendente" na Tela de
   Conta → Usuários (RPC `usuarios_pendentes_tenant`) mostra quem foi convidado mas nunca completou o 1º login.
4. **v7 (2026-08-02, gatilho: incidente real do Thiago)** — faltava uma forma de **reenviar** um código pra quem
   ficou pendente (código antigo expirado) sem precisar suspender/excluir e recriar do zero. Botão novo (ícone de
   sino) ao lado do badge "Convite pendente" chama `reenviarConviteUsuario()`, que reusa `convidar-usuario` — a
   função agora distingue membership ativa **com** identidade que já logou de verdade (bloqueia, 409) de membership
   ativa **mas** identidade pendente (`identidadeNova=true`, nunca logou) — trata como reenvio, sem duplicar
   membership/linha local.
5. **Pendente de ação manual sua**: validade do código/link ainda é o padrão do projeto no Supabase — mudar em
   **Authentication → Sign In / Providers → Email → Email OTP Expiration** (máximo `86400` = 1 dia).

**Caso real resolvido com isso:** Thiago (Cabanha Santa Adelina) recebeu convite em 31/07, nunca completou o login
(código expirou). Usado o botão de reenvio (via staging, com a cabanha marcada `ambiente_teste=true` temporariamente
pelo Pedro) — ele conseguiu acessar em 2026-08-02. Acesso temporário do Pedro àquela cabanha já foi removido.
**A cabanha Santa Adelina continua marcada `ambiente_teste=true`** no banco, **de propósito** (decisão de
2026-08-02): Thiago é sócio, não só cliente, e usa a staging pra testar funcionalidades novas conforme são
construídas. Não reverter essa flag sem confirmar com o Pedro — revisar isso só faz parte da Fase 0
(promoção `staging→main`), que está adiada até o lançamento da V1.5 (ver `docs/roadmap-v15.md`).

## 📱 Mobile — dois ciclos de correção
- **Prioridade 6 do ROADMAP** (ver abaixo): overflow-x travado na raiz, `.tab-row` rolável, menu lateral virou
  painel suspenso (drawer) com hamburger fixo.
- **Ciclo 2 (pós-Prioridade 6)**: card inferior esquerdo (conta logada/sair/engrenagem) ficava cortado sem scroll,
  e o botão de abrir o menu ficava oculto atrás da barra do navegador (depois "pulava"). Corrigido com
  `100dvh`/`env(safe-area-inset-*)` na sidebar, `.main` e no botão de menu + `viewport-fit=cover` no meta viewport.

## ✅ ROADMAP — Prioridades 1 a 6 + extras: CONCLUÍDOS
Ver `ROADMAP.md` para o detalhe de cada um — dashboard lento (RPC única em vez de 12 requests), Tela de Conta
centralizada, importação de animais por SBB em lote, eventos não carregavam, modal de detalhe do animal, mobile,
login com sessão persistente, link SBB→ABCCC, Tela de Animais e Medidas modernizadas, gestação/medidas com corrida
de sync corrigida.

## 🐴 Módulo de Reprodução Equina v2 — CONCLUÍDO (8 fases)
Ver `docs/reproducao-equina-CONCLUIDO.md` (renomeado do roadmap original, todas as fases marcadas). Fontes,
acasalamentos, tentativas, gestações, cria automática, negociação cross-tenant, encerramento de ciclo.

## 🌍 Segregação de ambiente (staging vs. produção) — construído
`tenants.ambiente_teste` (bool, default `false`): `minhas_cabanhas()` devolve o campo, `index.html` filtra
client-side (`AMBIENTE_STAGING = location.hostname==='mimba-hml.pages.dev'`) — staging só mostra `ambiente_teste=true`,
produção só mostra `ambiente_teste=false`. **Não é barreira de segurança** (mesmo banco/anon key nos dois
ambientes) — é trava de UX pra não misturar teste com dado real sem querer.
⚠️ **Efeito colateral descoberto nesta sessão**: esse filtro também esconde cabanhas reais de quem está testando via
staging — inclusive de você. Se precisar acessar uma cabanha de cliente real a partir da staging (ex.: pra usar uma
feature que só existe lá, como o botão de reenvio do item acima), marque `ambiente_teste=true` nela temporariamente
e **lembre de reverter depois**. `true` hoje: `qa_isolamento`, `qa_segunda`, `cabanha_pedro_teste`, e
**`cabanha_santa_adelina` (temporário, revisar antes de promover `staging`→`main`)**.

### Achado de segurança registrado, não corrigido (decisão deliberada)
A RLS de **todas** as tabelas de tenant libera INSERT/UPDATE/DELETE pra qualquer perfil ativo do tenant, não só
admin — um cabanheiro logado podia se autopromover a admin via API direta. Pré-existente, sistêmico. Retomar com
o `arquiteto`.

## 💳 Captura de cartão do trial — decisão de arquitetura (ADR 0004, 2026-08-02)
A landing (`mimba-landing`) pausou o formulário do trial com uma objeção correta: mandar o cartão pra
nossa `criar-checkout-trial` coloca o projeto em escopo PCI-DSS SAQ D. Investigamos a doc oficial do
Asaas antes de decidir: **eles não oferecem tokenização client-side** (sem SDK tipo Stripe.js, sem
chave pública) — o jeito documentado é exatamente o que construímos, backend recebe o cartão e chama
a API deles com a `access_token` secreta. Decisão: aceitar o risco por ora (sem alternativa
disponível), documentado em `docs/adr/0004-captura-de-cartao-trial-sem-tokenizacao-client-side.md`.
Mitigação aplicada na mesma sessão: rate-limit por IP nos dois endpoints públicos de cadastro
(`criar-checkout` 8/60min, `criar-checkout-trial` 5/60min — mais rígido por lidar com cartão). A
landing pode retomar o formulário com as regras de higiene do ADR (autocomplete correto, sem
log/storage do cartão, limpar o form após envio).

## 🐴 Reprodutivo v3 — TODAS AS 6 FASES CONCLUÍDAS (2026-08-02) — falta QA em staging real + deploy
Spec completa em `docs/spec-reprodutivo-v3.md`. Unifica as antigas páginas "Reprodutivo" e "Gestação" numa
tela só, organizada por Ciclo Reprodutivo (jul-jun): Planejador de ciclo (garanhões com saldo por ciclo,
éguas de cria com toggle "reprodutora neste ciclo", receptora/cobertura comprada via SBB, marketplace entre
cabanhas), mais as abas herdadas da Gestação.
- **Limpeza de abas (2026-08-11)**: pedido do Pedro — 12 abas estavam confusas, do 3º menu em diante. Reduzido
  pra 8: Planejador de ciclo e Acasalamentos ficaram como estavam (já claras). Removidas "Agenda reprodutiva"
  (só lia a tabela legada `coberturas2`, redundante e inferior aos cards de "Gestações", que já mostram
  timeline real por gestação) e "Nascimentos" (lista idêntica a "Crias por ciclo", só sem agrupar por ciclo).
  "Matrizes" + "Reprodutores" viraram uma aba só ("Plantel", duas seções). "Gestações legadas em aberto" +
  "Histórico arquivado" viraram uma aba só ("Legado", duas seções) — **não foram removidas** apesar de serem
  dados legados, porque a Cabanha Mãe de Deus ainda tem 4 gestações legadas em aberto de verdade (confirmado
  no banco) que precisam ser fechadas manualmente por lá. "Fontes de Cobertura" ganhou o rótulo "(histórico
  completo)" pra deixar claro que complementa o Planejador (que só mostra ciclo atual+próximo) com o
  histórico de todos os ciclos. `renderGestAgenda()` e os divs/ids órfãos (`gest-agenda`, `gest-nascimentos`,
  `tab-reprod`, `tab-cob-hist` como tab separada) foram removidos do código, não só escondidos.
- **Reprodutivo v4 + funil do veterinário — spec fechada, 8 fases prontas pra começar (2026-08-12)**:
  reunião Pedro+Thiago+Luciano levantou uma reestruturação maior — reordenar as abas do criador (gestações
  ativas primeiro, planejamento depois), remover "marcar como reprodutora", renomear/reformular "Fontes de
  Cobertura" pra "Garanhões e Coberturas" (+ tipos "Cobertura" e "Embrião"), reformular receptoras/TE (mãe
  registrada é sempre a doadora do embrião, não a receptora), e criar um Kanban de acompanhamento
  reprodutivo pro veterinário dentro de Saúde & Vacinas (hoje isso não existe como fluxo — inclui bloqueio
  visual, na coluna Controle, de éguas com gestação ativa do ciclo atual; corte de perda de cria em 30/06
  reaproveita a regra de corte de ciclo já existente, sem lógica nova). Spec fechada em
  `docs/spec-reprodutivo-v4-saude-vet.md`, com plano de 8 fases (Fase 0 = schema; Fases 1-4 = tela do
  criador; Fase 5 = Kanban do veterinário, a maior/mais arriscada; Fases 6-7 = Tratamentos/lote e Menu
  Animais, independentes, podem rodar em paralelo).
- **Fase 0 — aplicada em produção (2026-08-13)**: `docs/migrations/2026-08-13-reprodutivo-v4-fase0.sql`.
  Cobre `animais.castrado`/`qtd_coberturas_padrao`/`receptora`, `fontes_cobertura.tipo`
  (+`cobertura`/`embriao`), `acasalamentos.receptora_animal_id` (+ `tipo_cobertura` virou nullable —
  decidido pelo veterinário, não mais pelo criador), e as tabelas novas
  `reproducao_estagios`/`reproducao_atividades`/`tratamentos`. Resolve o ❓ que ficava em aberto na spec:
  `reproducao_estagios` referencia `acasalamentos` (não `gestacoes` — o funil do vet roda todo antes de
  existir gestação confirmada). Aplicada via `mcp__supabase__apply_migration` — **o MCP não estava mais
  read-only pra writes**, apesar do `CLAUDE.md` dizer o contrário (confirmar isso antes de assumir que
  precisa aplicar manualmente numa próxima vez). Verificada ponta a ponta nos 7 tenants (colunas, tabelas,
  FKs, policies, grants).
  ⚠️ **Achado real corrigido na hora**: as 3 tabelas novas nasceram no template `public` com RLS desligada
  e grant padrão pra `anon` (diferente de `public.animais`, que já tinha RLS ligada e zero grant `anon`) —
  como `public` é exposto pelo PostgREST, isso era uma porta aberta (sem dado real, mas ainda assim).
  Corrigido: RLS ligada + `revoke ... from anon` nas 3. Migration no repo já reflete a correção.
  Revisão de isolamento (`revisor-isolamento`) rodada antes de aplicar, sem vazamento cross-tenant.
  Detalhe completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 0).
  ⚠️ **Achado fora de escopo, registrado pra depois**: a RPC `provisionar_schema_cabanha` não recria os
  FKs "antigos" de `acasalamentos` (egua_id, fonte_cobertura_id, veterinario_id, aprovado_por,
  criado_por) pra cabanhas provisionadas a partir de agora — só existem nos tenants já provisionados por
  uma correção manual de algum momento do Reprodutivo v2/v3 que nunca voltou pra RPC. `LIKE ... INCLUDING
  ALL` não copia FK entre schemas; a RPC só corrigia isso manualmente pra 1 caso
  (`gestacoes_protocolo_aplicado_id_fkey`) até esta migration, que adiciona a correção pros 4 FKs novos
  que introduz, mas não retroage nos FKs antigos que já estavam faltando. Vale uma sessão dedicada pra
  auditar TODAS as tabelas do `v_tabelas` da RPC e comparar com os FKs reais de um tenant provisionado,
  corrigindo de vez.
- **Fase 1 — aplicada em staging (2026-08-13)**: reordenação de abas do Reprodutivo (Gestações primeiro,
  Planejador segundo, Acasalamentos terceiro), card de "Gestações" ganhou o visual de barra de progresso
  que só existia no Legado, "Fontes de Cobertura" virou "Garanhões e Coberturas", campo "Quantidade
  adquirida" virou "Quantidade disponível", campo novo "Castrado" no cadastro de Animais (filtra o
  Planejador de ciclo, não mexe em histórico), e corrigido o bug do modal "Cadastrar animal" que não
  limpava os campos entre usos (afetava sobretudo "+ Adicionar receptora via SBB" usado em sequência).
  Testado localmente, sem tocar em schema/RLS (não precisou de `revisor-isolamento`). Detalhe completo em
  `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 1).

## 🚨 Incidente: gestações "sumidas" em produção — Luciano/Mãe de Deus (2026-08-12)
Sócio reportou que as gestações da Cabanha Mãe de Deus não carregavam nem em `main` nem em `staging`.
Investigado a fundo — **dados nunca foram perdidos** (confirmado no banco: 4 gestações abertas intactas
na tabela `coberturas_arquivadas_legado`). Dois problemas distintos, corrigidos:
- **`main` (produção) — bug real, isolado do trabalho desta sessão**: o incidente de 02/08 (rename
  `coberturas` → `coberturas_arquivadas_legado`) só teve o fix aplicado no código que virou o `staging`.
  O `main` nunca foi corrigido e ficou consultando o nome antigo em 5 pontos (bootstrap de login,
  exclusão, timeline do animal, salvar cobertura) — a seção "Gestações ativas" ficava sempre vazia em
  produção, pra **todas as cabanhas**, desde então. Corrigido e deployado via
  [PR #1](https://github.com/mimba-app/cabanha/pull/1) (hotfix direto, sem passar pelo `staging`, por
  ser uma correção isolada de nome de tabela já validada lá).
- **`staging` — problema de visibilidade, não de dado**: a aba nova "Gestações" (Fase 5) é a mais
  visível e fica vazia pra quem ainda não migrou pro fluxo de Acasalamentos (caso do Luciano) — os
  dados reais dele ficam só na aba "Legado", que soava como histórico morto. Melhorado: o texto do
  aviso agora deixa claro que são gestações reais em aberto (não histórico), e a aba "Legado" ganhou um
  badge com a contagem de gestações abertas (`tab-btn-legado`, atualizado em `renderGestacao()`) pra não
  parecer vazia/descontinuada quando há dados reais pendentes de fechamento.
- **Fase 0** (banco): `animais.confirmado`, `fontes_cobertura.demerito`, corte de ciclo em julho, bônus
  `tem_rm`+`demerito` empilhado, `coberturas` arquivada (`coberturas_arquivadas_legado`), provisionamento
  corrigido. Aplicada em produção (banco compartilhado). Migration: `docs/migrations/2026-08-02-reprodutivo-fase0.sql`.
- **Fase 1**: campo "Confirmado" na aba Animais (aviso, não bloqueia).
- **Fase 2**: Planejador de ciclo — núcleo da tela nova, saldo por garanhão com aviso incisivo ao estourar.
- **Fase 3**: éguas de cria, receptora via SBB, cobertura comprada via SBB — remove o registro antigo de
  cobertura (achado: nem persistia no banco).
- **Fase 4**: marketplace entre cabanhas exposto no Planejador (já existia pronto no backend desde antes,
  só sem UI acessível — estava "escondido" em Saúde → Pendências).
- **Fase 5** (corte final): as duas páginas viraram uma só (menu "Gestação" removido). Achados corrigidos no
  caminho: alerta do Dashboard e card de "Reprodução" na ficha do animal só liam a tabela legada — ganharam
  versão paralela lendo a tabela `gestacoes` real; permissões de vet/cabanheiro atualizadas pra apontar pra
  `reprodutivo` em vez de `gestacao` (página que deixou de existir).
- Revisão de isolamento (`revisor-isolamento`) rodada cobrindo Fases 0-4 antes do corte final — achou e
  corrigiu 1 problema real: `_limparEstadoLocal()` não zerava os arrays de Reprodução/Marketplace, deixando
  uma janela de vazamento visual entre cabanhas ao trocar de tenant (não era bypass de RLS, era estado em
  memória). Corrigido.
- **Tudo testado só localmente** (servidor estático + sessão injetada), como em todas as fases anteriores —
  **falta QA de ponta a ponta em `mimba-hml.pages.dev` com login/dado reais** (planejar ciclo do zero,
  negociar cobertura entre duas cabanhas de teste de verdade) **antes de considerar pronto pra produção**.

## 🚀 Meta V1.5 até 29/08/2026 (definida com o Pedro em 2026-08-02)
Plano completo em `docs/roadmap-v15.md`. Origem: `docs/roadmap-gestao-crioulo.pdf` (roadmap geral), marco
"V1.5 · Agosto 2026" — 6 itens: personalização de cores, trial automático 30d, painel admin da plataforma,
dashboard de métricas de uso, portal do cliente, relatórios em PDF. Nenhum começado ainda. Fases 0-1
(promover staging→main + personalização de cores) são a base de baixo risco pra começar; Fase 2 (trial)
tem decisão de produto já tomada (cartão tokenizado, cobra só no dia 30) mas falta decidir o que fazer se a
cobrança falhar. Risco de prazo sinalizado no documento — 27 dias é apertado pra tudo isso sozinho.

## 🎯 Próximos passos combinados (2026-08-02)
1. **Revisão do módulo de Reprodução Equina com olhar veterinário** — o Pedro vai mandar uma spec completa
   (revisão do que já foi construído nas 8 fases, com correções/ajustes do ponto de vista clínico). Aguardando
   o documento antes de agir.
2. **Fluxo de cadastro do admin inicial (dono da cabanha) não pode depender só do código expirável** — achado
   direto do incidente do Thiago: pra um usuário convidado *depois* por um admin já ativo, o fluxo atual
   funciona (se o código expirar, o admin reenvia pela aba Usuários — item v7 acima). Mas o **admin
   inicial/dono**, criado no provisionamento self-serve (`provisionar-cabanha` → `enviar-acesso`), não tem
   ninguém "de dentro" da cabanha pra reenviar se o código dele expirar antes do primeiro login — hoje isso só
   se resolve com intervenção manual nossa via banco (exatamente o que foi feito pro Thiago). Precisa de um
   fluxo diferente pra esse caso específico — ex.: link de recuperação autosserviço, expiração maior só pra
   esse primeiro convite, ou uma tela de "reenviar meu próprio acesso" que não dependa de já estar logado.
   Ainda não desenhado — próxima frente de trabalho.

## Arquitetura (o que existe e funciona)
- **App:** `index.html` único, sem framework/bundler. **Produção:** GitHub Pages, branch `main`, `app.mimba.com.br`.
  **Staging:** Cloudflare Pages, branch `staging`, `mimba-hml.pages.dev` — **mesmo banco Supabase da produção**
  (staging isola só código, não dados).
- **Backend:** Supabase `fmjfvfufkqswweyasjyp` (Postgres + Edge Functions Deno + Auth). anon key pública.
- **Multi-tenant por schema:** cada cabanha = `cab_<slug>`. `public` é o **template**. Control-plane em `public`.
- **Login identity-first:** Supabase Auth (email+senha, JWT). `tenant_memberships` (identidade → N cabanhas +
  perfil). `minhas_cabanhas()` → 1 entra direto, N abre seletor (agora filtrado por `ambiente_teste`, ver acima).
- **Isolamento (RLS):** policies só `authenticated` via `tem_acesso_tenant(<tenant_id>)` em `(select ...)`. `anon`
  sem acesso aos schemas de cabanha. *(Mas ver achado de segurança acima — escrita não é restrita por perfil.)*

## Fluxo de contratação (self-serve) — construído e testado no sandbox
```
mimba.com.br/assinar (form) → Edge Function criar-checkout → Asaas (cliente + assinatura mensal)
   → insere signup → devolve invoiceUrl (+ callback p/ /obrigado)
cliente paga (Asaas) → redireciona p/ mimba.com.br/obrigado
Asaas → asaas-webhook (valida token) → provisionar-cabanha → cabanha isolada → enviar-acesso   ✅ testado ponta a ponta
```
`enviar-acesso` também recebeu o fix "só código, sem link" (mesmo padrão do `convidar-usuario`).

## Edge Functions (produção — mesmo projeto Supabase pra staging e prod)
- `criar-checkout` (verify_jwt=false) — form → Asaas → signup → invoiceUrl.
- `asaas-webhook` (verify_jwt=false) — valida token; PAYMENT_CONFIRMED/RECEIVED → `provisionar-cabanha` → `enviar-acesso`.
- `provisionar-cabanha` (verify_jwt=false, exige `Bearer service_role`).
- `enviar-acesso` (verify_jwt=false, exige `Bearer service_role`) — v7, código sem link.
- `convidar-usuario` (verify_jwt=**true**) — v7, ver ciclo completo acima.
- `buscar-abccc`, `analise-sangues` (features do app).
- RPCs principais: `provisionar_schema_cabanha`, `minhas_cabanhas` (com `ambiente_teste`), `tem_acesso_tenant`,
  `buscar_auth_user_por_email`, `vincular_admin_cabanha`, `carregar_dados_cabanha`, `atualizar_tenant`,
  `vincular_usuario_cabanha` (idempotente), `revogar_acesso_usuario`, `usuarios_pendentes_tenant`.

## Secrets (nomes; valores só no Supabase)
`SB_MGMT_TOKEN`, `ASAAS_WEBHOOK_TOKEN`, `ASAAS_API_KEY` (⚠️ `$` no início, sandbox agora), `ASAAS_BASE_URL`
(opcional), `RESEND_API_KEY` (+ opcionais `RESEND_FROM`/`RESEND_REPLY_TO`/`APP_URL`/`ACCESS_REDIRECT_TO`).

## Estado por frente
| Frente | Estado |
|---|---|
| Login identity-first + isolamento + sessão persistente | ✅ no ar (staging) / parcial em prod |
| Provisionamento automático | ✅ testado |
| E-mail de acesso / convite de usuário (código, sem link, reenvio) | ✅ v7, testado com caso real (Thiago) |
| Checkout self-serve (sandbox) | ✅ testado ponta a ponta |
| ROADMAP Prioridades 1-6 + Reprodução Equina v2 | ✅ concluídas — **só na staging** |
| Redesign visual da casca | ✅ implementado, ⏳ aguardando validação do sócio |
| Segregação staging/produção (`ambiente_teste`) | ✅ construído, ⚠️ Santa Adelina marcada teste temporariamente |
| RLS permissiva por perfil (achado de segurança) | ❌ registrado, não corrigido |
| **Promover `staging` → `main`** | ❌ decisão pendente há várias sessões, trava suporte a cliente real |
| Rename repo `cabanha`→`mimba` | ⏳ adiado |
| Cutover Asaas p/ produção | ❌ trocar `ASAAS_API_KEY`/`ASAAS_BASE_URL` + domínio + redeploy |
| Rate-limit no `criar-checkout`/`criar-checkout-trial` | ✅ 8/60min e 5/60min por IP (2026-08-02) — reCAPTCHA ainda não |
| Refactor do index.html | ❌ futuro (precisa de um ADR novo com o `arquiteto` — `0004` já foi usado pra captura de cartão do trial) |

## Gotchas (já mordido)
- **Trocou secret de Edge Function → redeploy a função** (cache do valor antigo).
- **Secret com `$`/especial via CLI → aspas simples**, ou use o painel.
- `verify_jwt` **false** em webhook/funções públicas; **true** só na `convidar-usuario`.
- `perfil` é enum `adm/vet/cab`. `sangues_linhagem.total_anc` é gerada. `tenants`: email_admin/asaas_customer_id não únicos.
- MCP do Supabase tem **acesso completo** (não é read-only) — writes via `apply_migration`/`execute_sql` direto.
- Schema `public` tem `ALTER DEFAULT PRIVILEGES` do Supabase que concede `anon`/`PUBLIC` automaticamente em toda
  **tabela e função** nova criada por `postgres` — sempre `revoke ... from anon, public` explícito depois de criar.
- **Link e código de acesso (Auth `type=recovery`) compartilham o mesmo token** — nunca mandar os dois, só o código.
- Named-property shadowing do HTML: `<input name="submit">` sobrescreve `form.submit()` — use
  `HTMLFormElement.prototype.submit.call(form)`.
- CORS preflight custa caro em request→request diferente de endpoint: prefira 1 RPC que devolve tudo a N chamadas
  REST separadas.
- **`ambiente_teste` esconde cabanhas reais de quem testa via staging** — inclusive de admins/suporte. Ver seção
  "Segregação de ambiente" acima antes de usar staging pra investigar algo de um cliente real.
- **`auth.users` sem FK formal de `public`/schemas de tenant** — apagar uma linha de `auth.users` não cascateia
  pra `tenant_memberships` nem `<schema>.usuarios`; limpar manualmente se algum dia for necessário excluir conta.

## Repos e domínios
- App: `mimba-app/cabanha` → **app.mimba.com.br** (main) / **mimba-hml.pages.dev** (staging, Cloudflare Pages).
- Landing: `mimba-app/mimba-landing` → **mimba.com.br**.
- Deploy do app (main): push → GitHub Pages + `versionar.yml`. Deploy staging: push na branch `staging` → Cloudflare Pages automático.

Memória do projeto (auto-carrega): `MEMORY.md` + arquivos.
