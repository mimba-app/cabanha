# 0009 — Especialista ABCCC (caso de uso 3): destravado para o lançamento via sincronização periódica pra produção

**Status:** Proposto (2026-08-25). Decisão de escopo do founder (Luciano); arquitetura técnica desenhada nesta ADR, **a validar com o Pedro antes de implementar** — em especial a viabilidade no prazo (ver "Risco de calendário" abaixo).

## Contexto

A ADR 0007 adiou o caso de uso 3 do agente de IA (especialista ABCCC — genealogia, campeões,
ancestralidade) por dois motivos:

1. A invariante da ADR 0010 (nenhuma requisição originada de uma cabanha pode tocar o projeto
   `mimba-analytics`, nem direta nem por proxy) só deixava duas opções — (A) artefato estático
   agregado, que não serve para consulta paramétrica sob demanda, ou (B) proxy de produção, que
   reabre o risco do incidente de 19/08 sem necessidade validada.
2. Cobertura de genealogia real no Lab era baixíssima: **836 de ~26.000 SBBs (3%)** tinham
   pedigree carregado.

Duas coisas mudaram desde então, ambas em 2026-08-25:

- **Cobertura de genealogia subiu substancialmente.** Backfill por casamento de nome dentro da
  própria base do Lab (sem nenhuma chamada externa — `dados_registros` já tinha "Pai"/"Mãe" em
  texto desde 1982, só não resolvido para SBB), rodado de forma recursiva/convergente até não
  haver mais ganho (função `public.backfill_genealogia_por_nome()`, projeto `njynlsugmvtuvcczmuld`,
  migration `backfill_genealogia_recursivo_convergente`). Resultado: de 836/26.000 (3%) para
  **18.391/26.593 (69%) de `sbb_pai`** e **7.286/26.593 (27%) de `sbb_mae`**. Essa é exatamente
  uma das duas condições que a própria ADR 0007 listou como gatilho para reconsiderar o adiamento.
- **Pedro está carregando, em paralelo**, os catálogos de finalistas 2020–2026 e todos os
  resultados de campeões desde 1982, e vai buscar a 5ª geração de todos os animais que aparecem
  nesses dois grupos — deve elevar a cobertura ainda mais antes do lançamento.
- **O founder redefiniu o escopo de lançamento.** Decisão de produto: o Agente Mimba deve ter,
  desde o lançamento, dois contextos complementares — a cabanha do usuário (já coberto pelos
  casos de uso 1/2 da ADR 0006) e a raça Crioula (estatística agregada do Mimba Lab), com o valor
  concentrado no cruzamento dos dois. As "provas principais" definidas para o lançamento (termo
  de mercado — ver base de conhecimento nova, `docs/agente-ia-base-conhecimento-abccc.md`; "Tier 1"
  é vocabulário interno, nunca aparece para o usuário) são Morfologia Expointer, Final do Freio de
  Ouro e Doma de Ouro.

**Achado no caminho, corrigido em 2026-08-26**: esta ADR originalmente registrava "Doma de Ouro"
como prova sem fonte de dado identificada. Verificado direto no Lab ao desenhar o schema desta
ADR: **"Doma de Ouro" já está carregada** em `resultados_competitivos` (336 linhas, `tier=2`),
distinta de "Bocal de Ouro" (1038 linhas, `tier=2` — semifinal de seleção para o Freio de Ouro, só
animais inéditos, confirmado com o Luciano que não são a mesma prova). Colocação de Doma de Ouro
vem como posição numérica (`01`, `04`...), sem a hierarquia textual (Grande Campeão etc.) que
"Morfologia Expointer" e "Final Freio de Ouro" têm — dá pra citar posição/finalista, não a
hierarquia completa da seção 6. As 3 provas principais prometidas para o lançamento **já têm dado
carregado no Lab** — deixa de ser um risco em aberto.

**Risco de calendário, registrado explicitamente**: o lançamento é 29/08, ou seja, 4 dias a partir
desta ADR. O escopo abaixo — schema novo em produção, job de sincronização, RPCs novas do agente,
wiring do chat — é trabalho real, somado a um V1.5 que, até a data desta ADR, não tinha nenhum dos
outros itens (trial automático, painel admin, portal cliente, PDF) implementado. Esta ADR não
resolve esse risco — só o torna explícito para a decisão do Pedro/Luciano sobre o que sai da lista
ou se "no lançamento" admite ativar o caso de uso 3 logo em seguida, não no dia exato.

## Decisão

**Tirar o caso de uso 3 do "adiado" — entra no escopo do lançamento**, mas com o mecanismo técnico
desenhado para preservar a invariante da ADR 0010 (não reabri-la), diferente da opção (B) que a
ADR 0007 descrevia como único caminho para atender consulta paramétrica sob demanda.

### Mecanismo: sincronização periódica, não proxy ao vivo

Em vez do agente (ou qualquer parte do caminho de requisição de uma cabanha) chamar o Lab durante
uma conversa, um **job de sincronização periódica** — rodando fora do caminho de requisição de
qualquer cabanha, mesma natureza de "manutenção nossa" que a ADR 0007 já havia validado como
aceitável para o artefato estático — materializa um resumo estatístico do Lab **para dentro do
projeto de produção** (`fmjfvfufkqswweyasjyp`).

- **Tabela nova em produção** (nome provisório: `public.abccc_estatisticas_animal`), chave por
  SBB, contendo o que o agente precisa responder sem tocar o Lab: participações/colocações nas
  provas principais, contagem de finalistas/campeões produzidos (para citar como evidência —
  ver base de conhecimento), presença em linhagens em alta, resumo genealógico (linha
  alta/linha baixa já resolvidas, prontas para narrativa).
- **Job de refresh**: roda periodicamente (frequência a definir — diário é suficiente, já que o
  Lab não muda durante o dia a dia; nada aqui precisa ser tempo real). Lê do `mimba-analytics`
  com credencial própria daquele projeto, escreve na tabela de produção. Esse job **não é uma
  requisição originada por uma cabanha** — é rotina nossa, exatamente como já era o artefato
  estático da ADR 0007, só que agora é uma tabela relacional real em vez de um blob de texto.
- **O agente consulta essa tabela como dado normal de produção** — mesmo padrão de RPC/RLS de
  tudo mais no projeto (não precisa de `tem_acesso_tenant`, porque esse dado não pertence a
  nenhuma cabanha específica). Pode fazer `JOIN` direto com o SBB de um animal da própria cabanha
  do usuário, na mesma consulta — é exatamente esse cruzamento que entrega "os dois cérebros se
  encontrando".

Isso preserva a invariante da ADR 0010 **literalmente**: nenhuma requisição de cabanha toca o
projeto `mimba-analytics`, nem direta nem por proxy — o Lab só é tocado pelo job de sincronização,
que não nasce de nenhuma cabanha.

### O que continua fora de escopo

**Cálculo ao vivo de um cruzamento hipotético nunca testado** (par garanhão×égua específico,
escolhido livremente no chat, sem histórico de resultado real entre eles) — isso ainda exigiria
computação sob demanda que uma tabela sincronizada não cobre sozinha. Luciano não pediu isso
explicitamente na redefinição de escopo; fica registrado como não incluído, não como "ainda
adiado por decisão" — se a necessidade aparecer, é uma nova decisão a tomar, não coberta aqui.

## Consequências

- (+) Preserva a invariante da ADR 0010 mesmo destravando o caso de uso 3 — não reabre o
  acoplamento que causou o incidente de 19/08.
- (+) Entrega a visão de produto do founder para o lançamento — os "dois cérebros" se encontram
  de verdade, com poder de consulta/`JOIN`, não só um texto estático genérico.
- (+) Reaproveita o padrão de segurança já validado (a tabela nova em produção segue o mesmo
  modelo de RLS/RPC de qualquer outra tabela do projeto).
- (+) O achado de cobertura de hoje (69%/27%) já torna essa decisão mais sólida do que seria há
  poucos dias — não é uma aposta às cegas.
- (−) Trabalho de implementação real e novo, apertado contra o prazo de 4 dias: schema novo,
  job de sync, RPCs do agente, wiring do chat — precisa de validação explícita de viabilidade
  com o Pedro, não presumida por esta ADR.
- (−) Cruzamento hipotético ao vivo continua fora do escopo — expectativa do usuário final
  precisa ser calibrada para não prometer isso ainda.
- (?) Frequência do job de sincronização (diário? por evento de carga no Lab?) não decidida
  nesta ADR — detalhe de implementação.

## Alternativas consideradas

- **Proxy de produção ao vivo (opção B da ADR 0007)**: rejeitada pelos mesmos motivos que a
  0007 já registrou — reabre a invariante da ADR 0010 sem necessidade, e ainda tensiona o plano
  free do projeto do Lab a cada conversa de qualquer cabanha.
- **Artefato estático simples (texto/markdown, opção A da ADR 0007)**: rejeitado para este
  escopo — perde a capacidade de `JOIN` com o SBB específico do animal da cabanha do usuário,
  que é justamente o "encontro dos dois cérebros" que o founder está pedindo. Continua sendo o
  mecanismo certo para conteúdo verdadeiramente estático (ex. `agente-ia-base-conhecimento.md`,
  caso de uso 4), só não para este.
- **Esperar a cobertura de genealogia ficar ainda mais completa antes de destravar**: rejeitada
  por decisão de escopo do founder — 69%/27% já é considerado suficiente para lançar, com o
  entendimento de que a cobertura pré-2000 continua baixa e vai crescer com o trabalho do Pedro
  (catálogos + campeões + 5ª geração) em paralelo, não como bloqueio.

## Status (atualizado 2026-08-27): implementado e no ar

Todo o escopo técnico desta ADR foi implementado, revisado (`revisor-isolamento`, aprovado nas
duas rodadas) e validado com dado real em produção:

- Schema `abccc_estatisticas_animal` + `abccc_linhagens_em_alta` aplicado
  (`docs/migrations/2026-08-26-agente-caso-uso3-schema-abccc.sql`).
- Job de sincronização (`supabase/functions/sync-abccc-estatisticas/index.ts`) deployado e
  testado ponta a ponta: 29.282 animais sincronizados, ranking de linhagens em alta batendo
  exatamente com os números validados na base de conhecimento.
- Agendado via `pg_cron`/`pg_net`/Vault pra rodar sozinho todo dia às 06:00 UTC
  (`docs/migrations/2026-08-27-cron-sync-abccc-estatisticas.sql`).
- RPCs `abccc_resumo_animal`/`abccc_ranking_linhagens` aplicadas e conectadas ao `agente-ia`
  (`docs/migrations/2026-08-27-agente-caso-uso3-rpcs-abccc.sql`), sem nenhum JOIN cross-schema
  com dado de tenant — a ponte com o animal da própria cabanha do usuário acontece em duas
  chamadas de tool-use separadas do modelo.
- FAB do chat reativado no `index.html` (estava escondido a pedido do Luciano desde 2026-08-25).

**Único bloqueio real** *(resolvido em 2026-08-28 — Luciano carregou US$ 20 de crédito na
organização Anthropic, confirmado via console)*: `ANTHROPIC_API_KEY` configurada, mas sem
créditos carregados ainda — sem isso não dá pra validar o comportamento do modelo numa conversa
de verdade (a parte de banco/RPC/job já foi validada independente da Anthropic). Falta só um
teste ponta a ponta numa conversa real pra fechar de vez.

**Achado corrigido no caminho**: "Doma de Ouro" (registrado nesta ADR como sem fonte de dado
identificada) na verdade já estava carregada no Lab — não era um risco real. Metodologia de
"linhagens em alta" também foi corrigida (era descrita como recorrência na 5ª geração da árvore
inteira; a validada de fato é pai direto do ciclo mais recente — ver base de conhecimento seção
4.3 e o comentário em `abccc_exportar_linhagens_em_alta` no Mimba Lab).
