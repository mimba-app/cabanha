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

**Achado no caminho, ainda sem solução**: "Doma de Ouro" **não existe hoje** como prova na base do
Lab (`resultados_competitivos`). O que existe é "Bocal de Ouro" — prova **diferente** (semifinal de
seleção para o Freio de Ouro, só animais inéditos), confirmado com o Luciano que não são a mesma
coisa. Doma de Ouro (animal domado para correr, com vistoria de 21–30 dias antes) provavelmente
precisa de uma fonte de dado própria, ainda não identificada.

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
- (−) "Doma de Ouro" não tem fonte de dado identificada ainda — uma das 3 provas prometidas para
  o lançamento fica sem histórico até isso ser resolvido.
- (−) Cruzamento hipotético ao vivo continua fora do escopo — expectativa do usuário final
  precisa ser calibrada para não prometer isso ainda.
- (?) Frequência do job de sincronização (diário? por evento de carga no Lab?) não decidida
  nesta ADR — detalhe de implementação.

## Alternativas consideradas

- **Proxy de produção ao vivo (opção B da ADR 0007)**: rejeitada pelos mesmos motivos que a
  0007 já registrou — reabre a invariante da 0005 sem necessidade, e ainda tensiona o plano
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

## Próximos passos (fora desta ADR)

- Validar com o Pedro a viabilidade desse escopo nos 4 dias restantes — se não couber, decidir o
  que sai da lista ou se o caso de uso 3 ativa logo após o dia 29, não no lançamento em si.
- Identificar a fonte de dado para Doma de Ouro (mesma origem do painel público da ABCCC que
  alimentou as outras provas, ou outra fonte — a definir).
- Desenhar o schema exato de `abccc_estatisticas_animal` e a RPC que o agente vai chamar
  (`revisor-isolamento` no loop, mesma regra de sempre para qualquer tabela/RPC nova tocando
  dado de produção).
- Definir a frequência do job de sincronização.
- Base de conhecimento de terminologia/regras de narrativa (`docs/agente-ia-base-conhecimento-abccc.md`)
  já escrita nesta mesma sessão — serve de insumo direto para o conteúdo que a
  `abccc_estatisticas_animal` precisa carregar e para o system prompt do agente.
