# Roadmap — Módulo de Reprodução Equina v2.0

> ✅ **CONCLUÍDO** (2026-07-28) — Fases 1-8 implementadas, commitadas e publicadas em `staging`. Mantido aqui como
> registro histórico das decisões/armadilhas de banco encontradas, não como pendência ativa. Itens cortados
> deliberadamente (documentados fase a fase): concentração de sangue projetada completa (Fase 2), verificação
> sanitária automática de eventos ABCCC (Fase 5). ~~Pendente pra depois: migração definitiva de `coberturas` →
> módulo novo com descontinuação da tela antiga (hoje coexistem)~~ — retomado em `docs/spec-reprodutivo-v3.md`
> (Fase 0): a tabela `coberturas` foi **renomeada** para `coberturas_arquivadas_legado` (2026-08-02), dado
> preservado, tela antiga removida na Fase 5 dessa spec nova. Referências a `coberturas` neste documento abaixo
> são históricas (nome válido na época) — o nome atual da tabela arquivada é `coberturas_arquivadas_legado`.

> Origem: spec funcional/técnica do sócio (`spec-reproducao-mimba-v2.docx`, MimbaTech, julho 2026).
> Este documento quebra a spec em fases executáveis, na ordem sugerida pela própria spec (seção 11).
> Cada fase é um refactor/extensão do módulo reprodutivo atual (tabela `coberturas` simples → modelo completo).

## Como usar este documento
- Checkbox por fase e por sub-item. Marcar `[x]` ao concluir.
- Toda tabela nova entra no schema `public` (template) via skill `nova-migration-tenant` — nunca DDL direta em `cab_*`.
- Mudanças em RLS/auth passam pelo `revisor-isolamento` antes de mergear.
- Tenants existentes hoje: `cab_cabanha_pedro_teste`, `cab_cabanha_santa_enoema`, `cab_mae_de_deus`, `cab_qa_isolamento`, `cab_qa_segunda`.

## ⚠️ Armadilha nova descoberta (Fase 7) — anon ganha EXECUTE automático em função nova
Mesma raiz da armadilha da Fase 1, mas para **funções**: `pg_default_acl` do schema `public` tem uma entrada
`defaclobjtype='f'` que concede `EXECUTE` a `anon`/`authenticated`/`service_role` automaticamente em toda função
nova criada por `postgres`. Toda função nova (mesmo `SECURITY DEFINER` com `tem_acesso_tenant` na primeira linha)
precisa de `revoke execute on function public.<fn>(<assinatura>) from anon, public;` explícito, senão ela some do
padrão das funções mais sensíveis do projeto (que já tinham isso revogado) e fica exposta a chamadas anônimas —
mesmo que a lógica interna acabe barrando, é defesa em profundidade que vale a pena manter. Note também que
`CREATE OR REPLACE FUNCTION` pode reintroduzir o grant a `anon` mesmo numa função que já tinha sido corrigida —
sempre reconferir `information_schema.routine_privileges` depois de qualquer `CREATE OR REPLACE`.

## ⚠️ Armadilha nova descoberta (Fase 1) — anon ganha grant automático em tabela nova
O schema `public` tem `ALTER DEFAULT PRIVILEGES` do Supabase que concede `anon`/`authenticated` automaticamente
em **toda tabela nova** criada por `postgres`/`supabase_admin` — mesmo com RLS habilitada, isso deixa `anon`
com grant (embora RLS sem policy já bloqueie o acesso a dados). Toda tabela nova do template precisa de
`revoke all privileges on public.<tabela> from anon;` logo após o `create table`, senão ela sai do padrão das
tabelas antigas (`animais`, `coberturas`, `usuarios` etc., que não têm grant nenhum para `anon`). Válido para
todas as tabelas novas das Fases 2-8.

## Decisão de migração
A tabela `coberturas` atual (simples: 1 linha por cobertura, sem saldo/ciclo/planejamento) é **substituída** pelo
modelo novo (`fontes_cobertura` + `acasalamentos` + `tentativas` + `gestacoes` + `crias`). Dados existentes em
`coberturas` precisam de migração de linha (fonte "avulsa" retroativa) — tratar isso na Fase 1, não descartar dado.

---

## Fase 1 — Fontes de Cobertura (base) ✅
- [x] Tabela `fontes_cobertura` (tipo, garanhão, saldo, ciclo, vigência, status) — seção 2.3 da spec.
  Criada no template `public` + replicada nos 5 schemas `cab_*` existentes + RPC `provisionar_schema_cabanha`
  atualizada pra tenants novos. Isolamento revisado (`revisor-isolamento` + verificação manual de
  `pg_policies`/grants/RPC): policies corretas por schema, sem grant a `anon` (bug do default privilege do
  Supabase corrigido — ver armadilha abaixo).
- [x] Enum/regras de saldo: `quantidade_adquirida − confirmadas − negociadas` — decisão tomada na Fase 3 (client-side,
  a partir dos arrays já sincronizados, sem coluna nova) e estendida na Fase 7 pra descontar negociações também.
  Ver `_saldoFonteCobertura()`.
- [x] Migração de dados: linhas existentes em `coberturas` viram fontes "próprio" retroativas (1 unidade cada, ciclo 25/26,
  obs marcando a origem/id original). Rodada em todos os schemas — só `cab_mae_de_deus` (4) e `cab_cabanha_pedro_teste` (2)
  tinham dados; migration idempotente (não duplica se rodar de novo).
- [x] RLS por tenant (`tem_acesso_tenant`), sem diferenciação de perfil ainda (ver achado `rls-permissiva-por-perfil`)
- [x] Tela: lista de cards por garanhão, barra de saldo, filtros, ação "Nova fonte" — implementada como 5ª aba dentro de
  "Gestação" no `index.html` (ver `renderFontesCobertura`/`modal-fonte-cobertura`). Saldo ainda fixo em 100% disponível —
  será alimentado de verdade pelas Fases 2/3 (consumo por confirmação de prenhez).
- [x] RPC `carregar_dados_cabanha` atualizada para devolver `fontes_cobertura` (evita chamada REST extra / preflight CORS,
  mesma lição da Prioridade 1 do roadmap de ajustes menores).
- Dependências: nenhuma. **Base de tudo.**

## Fase 2 — Acasalamentos + Simulação Genética Fase 1 ✅
- [x] Tabela `acasalamentos` (égua × fonte × ciclo, fluxo de status rascunho→simulado→aprovado→em_curso→confirmado/cancelado).
  Criada no template `public` + replicada nos 5 schemas `cab_*` + `provisionar_schema_cabanha` e `carregar_dados_cabanha`
  atualizadas. Isolamento verificado (mesmo padrão da Fase 1, sem grant a `anon`) — RPC de provisionamento agora também
  revoga `anon` de **todas** as tabelas do schema novo, não só uma, corrigindo a raiz do bug achado na Fase 1.
- [x] Painel de simulação: cruzamentos anteriores (via `coberturas2` histórico) e alerta de consanguinidade (comparação de
  `sangues_linhagem.ancestrais_pos`, `gen ≤ 3`, com fallback neutro se SBB ainda não analisado). **Não implementado**:
  concentração de sangue projetada completa (parte mais avançada da Fase 2 original da spec) — cortado deliberadamente,
  fica para revisitar se o sócio pedir.
- [x] Kanban de planejamento (Rascunho/Simulado/Aprovado/Em Curso/Concluído + lista de Cancelados separada).
- [x] Transições de status rascunho→simulado→aprovado implementadas com os botões certos por card; cancelamento sempre
  exige `motivo_cancelamento`. Transição aprovado→em_curso fica para a Fase 3 (é o veterinário que inicia).
- Dependências: Fase 1, análise de sangues existente (`sangues_linhagem`).

## Fase 3 — Tentativas + confirmação de prenhez + saldo ✅
- [x] Tabela `tentativas` (N por acasalamento, sem decremento de saldo até confirmação). Template + 5 schemas `cab_*` +
  `provisionar_schema_cabanha`/`carregar_dados_cabanha` atualizadas. Isolamento verificado (10 colunas em todos os
  schemas, sem grant a `anon`).
- [x] Regra: saldo só decrementa na confirmação; cancelamento sem tentativa devolve saldo, com tentativa frustrada não
  devolve. **Saldo real implementado** (não mais placeholder da Fase 1): `disponivel = quantidade_adquirida − count(
  acasalamentos com status='confirmado' daquela fonte)`, calculado client-side a partir dos arrays já sincronizados —
  sem coluna nova no banco. Devolução automática por design: acasalamento cancelado nunca chega a 'confirmado', então
  nunca é descontado.
- [x] Flag `especialidade_reproducao` em `usuarios` (veterinário reprodutor) — coluna adicionada + exposta em
  `carregar_dados_cabanha`. Seletor de veterinário no registro de tentativa filtra por essa flag, com fallback pra
  todos os usuários se nenhum estiver marcado (evita travar o fluxo em cabanhas que ainda não configuraram o perfil).
- [x] Transição automática aprovado→em_curso na primeira tentativa registrada; em_curso→confirmado ao marcar resultado
  'prenha' de uma tentativa (data_resultado obrigatória). Resultado 'vazia' mantém em_curso, permitindo nova tentativa.
- [x] Seletor de fonte no "+ Novo acasalamento" (Fase 2) agora só mostra fontes com saldo real > 0 e status ativa.
- Dependências: Fase 2, perfil vet reprodutor.

## Fase 4 — Gestações + linha do tempo ✅
- [x] Tabela `gestacoes` (criada automaticamente ao confirmar prenhez — nunca manual, sem UI de criação exposta em
  lugar nenhum). Template + 5 schemas `cab_*` + RPCs atualizadas. Isolamento verificado (13 colunas em todos os
  schemas, sem grant a `anon`).
- [x] Cálculo automático de `parto_previsto` — coluna `GENERATED ALWAYS AS (data_cobertura + 340 dias) STORED` no
  próprio Postgres (não calculado em JS, evita divergência entre telas).
- [x] Status: gestando/parida/abortada/perdida. Auto-criação plugada no mesmo ponto da Fase 3 onde a tentativa com
  resultado 'prenha' confirma o acasalamento (`_confirmarResultadoTentativa`).
- [x] Card visual por trimestre (1º/2º/3º, calculado a partir de `data_cobertura`) + alerta de parto próximo (≤30 dias)
  ou atrasado + timeline expandida reaproveitando as tentativas da Fase 3. Ações: registrar parto/aborto/perda.
- [x] Nova aba "Gestações" coexistindo com a aba antiga "Gestações ativas" (`coberturas2`/tabela `coberturas`) — a
  substituição definitiva fica para depois que todas as fases estiverem prontas (ver Decisão de migração no topo).
- ⚠️ **Não implementado nesta fase (propositalmente)**: criação automática do animal-cria ao registrar parto — isso é
  a Fase 6. O botão "Registrar parto" só marca `status='parida'` + `parto_real`; o ponto de gancho pra Fase 6 está
  comentado no código.
- Dependências: Fase 3.

## Fase 5 — Protocolos + kanban de saúde reprodutivo ✅
- [x] Tabela `protocolos_reproducao` (templates) + `protocolo_aplicado` (instância por gestação, D0 = confirmação,
  UNIQUE por gestação, FK real de `gestacoes.protocolo_aplicado_id`). Template + 5 schemas `cab_*` + RPCs atualizadas.
  Isolamento verificado (8/7 colunas em todos os schemas, sem grant a `anon`).
- [x] Estrutura de etapas em JSONB (`dia_relativo`, `tipo`, `descricao`, `obrigatorio`, `obs`) — editor dinâmico de
  etapas na tela "Protocolos" (nova 8ª aba em Gestação). Ao aplicar um template a uma gestação, `protocolo_aplicado`
  guarda cópia independente das etapas com `data_prevista` calculada (`d0 + dia_relativo`) + `concluida`/`data_real`/
  `obs_execucao` — editável sem alterar o template original. Etapas avulsas (não previstas no template) suportadas.
- [x] Aba nova em Saúde: kanban "Protocolo Reprodutivo" (Em dia/Atenção ≤7d/Vencido), mesmo padrão visual dos kanbans
  de vacina/exame. Só considera gestações ativas (`status='gestando'`); etapas concluídas saem para o histórico na
  timeline da própria gestação (Fase 4).
- ⚠️ **Não implementado (propositalmente)**: inclusão na "verificação sanitária automática de eventos ABCCC" — não
  existe hoje nenhum mecanismo equivalente no app (nem para vacinas/exames), não havia onde plugar. Cortado, igual
  fizemos com a concentração de sangue projetada na Fase 2.
- Dependências: Fase 4, módulo Saúde existente.

## Fase 6 — Cria automática no parto ✅
- [x] Ao registrar parto: cria animal com `status_cadastro = 'rascunho'` (coluna nova em `animais`, template + 5
  schemas `cab_*`, herdada automaticamente por tenants novos via clonagem — sem mudança de RPC necessária, já vem
  em `select *`). "Registrar parto" (Fase 4) agora pede nome provisório + sexo antes de criar.
- [x] Campos herdados: pai (via gestação → acasalamento → fonte de cobertura → `garanhao_sbb`, vazio se a fonte não
  tiver SBB cadastrado — não trava o fluxo), mãe (SBB da égua, com fallback pro nome dela se não tiver SBB), ciclo
  calculado automaticamente da data do parto (`_calcCiclo`, extraído do `_autoCiclo` já existente).
- [x] Rascunhos saem das listagens padrão de Animais (badge amarelo "Rascunho — aguardando SBB" + filtro dedicado
  "Rascunhos (aguardando SBB)" no select de situação).
- [x] Ao informar SBB real na edição do animal: busca automática ABCCC (reaproveita `_buscarAbccc('edit')` já
  existente) e, se encontrado, `status_cadastro` vira `'ativo'` — só persiste no salvar explícito da edição, não no
  blur do campo.
- Dependências: Fase 4, módulo Animais.

## Fase 7 — Negociação de coberturas + financeiro ✅
- [x] Tabela `coberturas_negociadas` (venda/doação, comprador externo ou outro tenant Mimba). Template + 5 schemas
  `cab_*` + RPCs de provisionamento/bootstrap atualizadas. Isolamento verificado (15 colunas em todos os schemas,
  sem grant a `anon`).
- [x] Fluxo comprador externo → insert direto no próprio schema (`status='aceito'` imediato, sem espera de terceiro)
  + lançamento de receita automático (reaproveita `_dbSalvarLancamento`) se for venda com valor.
- [x] Fluxo comprador Mimba → **3 RPCs `SECURITY DEFINER` novas**, únicas escritas cross-schema do projeto até agora:
  `negociar_cobertura_mimba` (cria oferta pendente + notifica via `pendencias` no schema do comprador),
  `aceitar_negociacao_cobertura` (cria a `fontes_cobertura` automaticamente no schema do comprador + marca aceito no
  schema do vendedor + lançamento de receita se venda), `recusar_negociacao_cobertura` (marca cancelado). Mais uma
  RPC auxiliar `buscar_tenant_para_negociacao` (busca só id+nome de outras cabanhas, nunca dados sensíveis).
  **Revisão de isolamento formal feita e APROVADA** pelo `revisor-isolamento` (2 rodadas — a 1ª pediu correção de
  race condition de aceite duplo e do grant residual a `anon`/`PUBLIC`, ambos corrigidos e reconfirmados antes da
  aprovação final). Frontend usa exclusivamente essas RPCs para qualquer coisa cross-tenant — nenhum `_supa()` direto
  contra outro schema, confirmado por grep e leitura de código.
- [x] Fluxo cadastro manual pelo comprador (sem depender do vendedor ser usuário Mimba) — já funcionava desde a
  Fase 1 ("+ Nova fonte" na tela de Fontes de Cobertura), zero código novo necessário.
- [x] Saldo real (`_saldoFonteCobertura`, Fase 3) atualizado para descontar também negociações com status
  `aceito`/`quitado` daquela fonte.
- Dependências: Fase 1, módulo Financeiro (`lancamentos`), multi-tenant (`tenants`).

## Fase 8 — Job de encerramento de ciclo (automação) ✅
- [x] Implementado como **função Postgres agendada via `pg_cron`** (não Edge Function — mais simples/confiável, evita
  HTTP/auth extra; a spec permitia as duas opções). Extensão `pg_cron` habilitada. Job `encerramento-ciclo-reproducao`
  agendado pra `0 3 1 8 *` (03:00 de todo 1º de agosto, todo ano — cron recorre naturalmente).
- [x] `public.encerrar_ciclo_reproducao()`, `SECURITY DEFINER`, **não exposta a `authenticated`/`anon`** (só roda via
  cron, como owner do banco) — itera todos os tenants provisionados e, por schema: (1) vence fontes `proprio` com
  saldo > 0 (mesma fórmula de saldo real das Fases 3/7, replicada em SQL); (2) cancela `acasalamentos` `em_curso` com
  `motivo_cancelamento='Encerramento de ciclo'`; (3) recria uma fonte `proprio` por garanhão distinto pro ciclo novo
  (limite 120 ou 150 conforme `tem_rm`), idempotente — não duplica se o job rodar de novo pro mesmo ciclo; (4) vence
  `cota`/`direito_uso` com `vigencia_fim` expirada.
- [x] Log de execução por tenant em `public.webhook_log` (reaproveitada, sem tabela nova — `evento =
  'encerramento_ciclo_reproducao'`, `payload` com as contagens).
- [x] Validado com uma simulação **somente leitura** (sem invocar a função de verdade, pra não mexer em dados reais
  de cabanhas como a Mãe de Deus antes da data real de corte): confirmado que hoje (28/07) o cálculo de ciclo ainda
  dá "25/26" — a função não teria efeito nenhum se rodasse agora, e só passa a calcular "26/27" a partir de 1º/08,
  quando o cron efetivamente dispara.
- Dependências: todas as fases anteriores.

---

## 🎉 Módulo completo — Fases 1-8 implementadas
Todas as 8 fases da spec do sócio estão no banco (isolamento revisado em cada uma, revisão formal obrigatória na
Fase 7 por ser cross-tenant) e no `index.html`. Itens cortados deliberadamente (documentados fase a fase, não
esquecidos): concentração de sangue projetada completa (Fase 2), verificação sanitária automática de eventos
ABCCC (Fase 5) — ambos por falta de base/infra existente pra plugar, não por decisão de escopo arbitrária.
~~Pendente pra depois: migração de dados definitiva de `coberturas`→ módulo novo com descontinuação da tela
antiga (hoje coexistem)~~ — ver nota no topo deste documento: retomado e resolvido via `docs/spec-reprodutivo-v3.md`.
Testar o job da Fase 8 de verdade num schema descartável antes de 1º/08/2026.

---

## Glossário (da spec, seção 12)
Ciclo ABCCC = 1º/ago a 31/jul (notação "26/27"). RM = Registro de Mérito (eleva limite 120→150).
Saldo de cobertura = adquirida − confirmadas − negociadas, decrementado só na confirmação. D0 = data de confirmação de prenhez.

## Referência
Documento fonte completo: `~/Downloads/spec-reproducao-mimba-v2.docx` (não versionado — spec interna do sócio).
