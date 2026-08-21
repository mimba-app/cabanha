# Handoff — Mimba Lab e inteligência de Cruzamentos

> Documento pedido pelo Luciano para dar contexto de negócio e técnico completo sobre a área
> de inteligência de dados da Mimba ("Mimba Lab") a quem for trabalhar na funcionalidade de
> **Cruzamentos** do produto principal. Cobre o que existe, como os dois mundos (Lab e produto)
> se relacionam hoje — e onde **não** se relacionam ainda, que é o ponto mais importante para
> quem for evoluir a parte de inteligência de cruzamento.

## 1. O que é o Mimba Lab

**Mimba Lab** (também chamado internamente de "Área de Dados") é a área de inteligência de
dados da Mimba — uma ferramenta interna, restrita a staff/sócios (`public.mimba_staff`), para
carregar, explorar e analisar dados de referência da raça Crioula: resultados históricos de
competições da ABCCC, rankings de garanhões/matrizes/criadores, e — o pedaço mais relevante
para Cruzamentos — um motor de **genealogia e score de cruzamento**.

**Não é** uma tela do produto que o cliente final vê. É uma ferramenta de bastidor: hoje
alimenta análises e, no roadmap, deve virar a base para o "especialista ABCCC" do futuro
agente de IA interno (ver `docs/adr/0006-agente-de-ia-interno-arquitetura.md` e
`docs/roadmap-fase-produto-2026-08.md`, item 4).

### 1.1 Onde vive — e por quê (a história importa)

Em 19/08/2026 a primeira versão da Área de Dados foi construída **dentro do banco de
produção** (o mesmo Supabase que atende as cabanhas pagantes). Uma carga de 83.778 linhas
inserida uma a uma, numa tabela com 4 índices de expressão jsonb, mais uma materialized view
com `refresh` não-concorrente, levou a CPU (plano FREE, compartilhado) a 72% e **derrubou a
produção inteira** — API em 522, timeout no login de qualquer cabanha. A funcionalidade foi
desmontada da produção no mesmo dia.

A decisão que se seguiu (registrada em ADR — ver nota abaixo) foi **separar por consumidor**:

- **Exploração de staff** (2 pessoas, escreve dados, tolera esperar) → um **segundo projeto
  Supabase**, em organização separada da produção, plano free. É onde o Mimba Lab roda hoje:
  `lab/index.html`, uma página HTML standalone (não faz parte do `index.html` do produto),
  com login próprio contra esse segundo projeto e seu próprio `mimba_staff`/`sou_staff_mimba()`
  (deliberadamente **não** compartilha JWT secret com produção — um projeto comprometido não
  deve valer token de produção).
- **Consumo pelo app** (todo cliente logado, zero tolerância a indisponibilidade) → deveria
  virar um **artefato estático** publicado no GitHub Pages junto do `index.html`, gerado a
  partir do projeto analítico ~1×/temporada, para que nenhuma requisição de cabanha jamais
  toque o projeto analítico (nem direto, nem por proxy) — assim, se o Lab cair, pausar ou ser
  deletado, a produção não sente nada.

> **Nota sobre os documentos-fonte**: o ADR que registra essa decisão em detalhe
> (`0005-onde-mora-a-area-de-dados.md`) e o handoff técnico original
> (`HANDOFF-AREA-DADOS.md`, com a matriz de segurança testada e o post-mortem completo do
> incidente) **não estão na `main`** — ficaram numa branch de recuperação,
> `recuperacao/area-dados-fora-de-producao`. Vale trazê-los de volta pra `docs/` numa próxima
> sessão; por ora, este handoff resume o que importa pra Cruzamentos.

### 1.2 O que está implementado vs. o que ficou só no papel

- ✅ **A parte de exploração (Mimba Lab em si) está implementada e rodando** — `lab/index.html`,
  segundo projeto Supabase, 3 abas (Dados / Inteligência / Cruzamentos — ver seção 2).
- ⚠️ **A parte de consumo pelo app (artefato estático `ref/abccc/*.json`) não foi
  implementada.** Não existe diretório `ref/` no repo. Isso significa que **hoje o Mimba Lab e
  o produto principal são dois mundos desconectados** — nenhuma tela do app chama o Mimba Lab
  ou lê o que foi carregado nele. A funcionalidade de Cruzamentos do produto (seção 3) tem seu
  **próprio** mecanismo de genealogia, independente e mais simples que o do Lab.

Este é o ponto mais importante pra quem for melhorar Cruzamentos com o que já foi construído no
Lab: **o trabalho de genealogia e score do Lab existe, foi validado, mas não está plugado no
produto ainda.** Plugar é trabalho a fazer, não uma integração que já existe e só precisa achar.

## 2. O que tem dentro do Mimba Lab

Três abas em `lab/index.html`:

### 2.1 Dados
Upload de CSV/Excel (SheetJS via CDN, sob demanda — não é build step), catálogo do que foi
carregado, e um botão "Atualizar agora" que importa os resultados da ABCCC automaticamente
(RPCs `abccc_importar_disparar`/`abccc_importar_coletar`, via `pg_net`, assíncrono, paginado).

### 2.2 Inteligência
Rankings sobre os resultados da ABCCC — por garanhão, matriz, criador, animal, prova, cidade —
ponderados por um índice de pontos **próprio da Mimba, não oficial da ABCCC**: Grande Campeão =
10, Campeão de categoria/1º lugar = 5, Reservado = 3, demais colocações = 0,5–2
(`public.abccc_pontos`). Mais busca de animal por nome/SBB.

### 2.3 Cruzamentos (a parte relevante)

É aqui que mora o motor de genealogia e o score de cruzamento do Lab. Schema
(`docs/migrations/dados-2026-08-20-fase5-genealogia.sql` — prefixo `dados-` porque roda no
projeto analítico, não em produção):

- **`animais_genealogia`** — um animal por linha (SBB, nome, sexo, pelagem, nascimento,
  `sbb_pai`/`sbb_mae` auto-referenciados, `fonte` ∈ {`abccc`, `catalogo_pdf`,
  `plantel_cabanha`, `manual`}).
- **`resultados_competitivos`** — uma premiação por linha, com `tier` (1/2/3) vindo de
  **`provas_tier`**, uma tabela de lookup fixa (evento → tier + tipo: morfologia, funcional,
  resistência, doma, paleteada, rienda).
- **`animal_posicoes`** — materialized view com 6 "posições" genealógicas por animal: pai (p1),
  avô e avó paternos (p2/p3), mãe (m1), avô e avó maternos (m2/m3). **Só 2 gerações de
  profundidade**, mesmo o schema tendo campo (`geracoes_completas`) que sugere suportar até 5 —
  é uma limitação de implementação documentada, não um bug.

**`genealogia_resumo()`** — RPC informativa (métricas de dashboard: quantos animais, quantos
com genealogia, quantos resultados de catálogo, quantas posições calculadas). Não é o motor de
score — é só contagem.

**`analisar_cruzamento(p_sbb_garanhao, p_sbb_egua, p_objetivo)`** — este sim é o motor de score,
e é o coração da funcionalidade de Cruzamentos do Lab:

- **`score_competitivo`**: procura, em `resultados_competitivos`, animais cuja própria
  genealogia bate com ≥2 das 6 posições do cruzamento proposto — "alguém com essa mesma
  combinação de sangue já competiu, como foi?". Cada resultado pontua `tier × (2 se a prova bate
  com o objetivo escolhido, senão 1)`, somado e limitado a 100.
- **`ic_estimado`** (coeficiente de endogamia, fórmula de Wright): soma `0.5^(profundidade_pai +
  profundidade_mãe + 1)` para cada posição de ancestral compartilhada entre o lado paterno do
  garanhão e o lado materno da égua. Limitado a 2 gerações (mesma limitação de
  `animal_posicoes`).
- **`score_limpeza`**: função-degrau do IC — 0% → 100, ≤3% → 80, ≤6,25% → 50, ≤12,5% → 20,
  acima disso → 0.
- **`nota_geral`** = `score_competitivo × 0,6 + score_limpeza × 0,4`.

O header da migration documenta **dois bugs corrigidos** em relação ao spec original do
Luciano (`analytics-prompt_1.md`): o cálculo de IC do rascunho estava matematicamente quebrado
(agregava numa linha só e tentava fatiar um UUID como se fosse lista), e a ponderação por
`p_objetivo` era um no-op (o `CASE` original devolvia o mesmo array em todo branch — hoje
aplica de fato um multiplicador 2x).

### 2.4 Cobertura real de genealogia — o gargalo

Isto é crítico para calibrar expectativa: **a genealogia real (SBB-a-SBB) é rasa hoje.**

- Os CSVs da ABCCC (`dados/abccc/painel-resultados-todos-ciclos.csv`, 83.778 linhas, ~26.121
  SBBs distintos) trazem **pai e mãe só como texto** (nome), não SBB — não dá pra popular
  `sbb_pai`/`sbb_mae` a partir daí.
- A única fonte com parentesco SBB-a-SBB de verdade hoje é
  `dados/genealogia/catalogos_animais.csv` — **836 linhas**. É carregado via
  `carregar_catalogo_genealogia(p_linhas jsonb)`, chamado pela aba Cruzamentos do Lab
  ("Carregar catálogo com genealogia").
- Ou seja: de ~26 mil SBBs conhecidos pela ABCCC, só ~836 têm genealogia real hoje.
  `analisar_cruzamento` só funciona bem para pares dentro desse conjunto pequeno.

## 3. Como Cruzamentos funciona hoje no produto (e como isso se compara ao Lab)

O produto principal (`index.html`) tem sua **própria** funcionalidade de cruzamento, chamada
"Cruzamentos" (dentro de Reprodutivo) — completamente independente do Mimba Lab, com um motor
de genealogia mais simples baseado em `public.sangues_linhagem` (tabela por tenant, populada
pelas edge functions de produção `buscar-abccc`/`analise-sangues`, que consultam a ABCCC ao
vivo por animal, até 5 gerações).

Isso já foi documentado com detalhe em `docs/spec-acasalamento-jornada-tres-direcoes.md` — aqui
vai só o resumo pra comparação com o Lab:

- **`_jaConsanguinidade(egua, fonte)`** classifica o par em 4 níveis: **nível 1** (proibido —
  pai/filha, mãe/filho ou irmãos completos, excluído do ranking), **nível 2** (meio-irmãos ou
  ancestral comum até geração 3, IC ≥ 12,5%), **nível 3** (IC calculado > 6,25% sem overlap em
  gen ≤3), **nível 0** (dentro do limite recomendado).
- **Fórmula do Conselho**: `nota = 5·consanguinidade + 3·diversidade + 2·saldo_e_sanidade`
  (0–100), reprovando de cara qualquer fonte nível 1.
- A jornada completa (Conselho → Confluência de Sangues → Dossiê Selado) e o modo Rápido
  (tela clássica de duas colunas, sem ranking) estão implementados e — no momento deste
  documento — ainda só em `staging`, aguardando validação final do Luciano antes de ir pra
  produção.

### 3.1 Tabela comparativa — os dois motores de cruzamento

| | **Mimba Lab** (`analisar_cruzamento`) | **Produto** (`_jaConsanguinidade` / Conselho) |
|---|---|---|
| Onde roda | Projeto Supabase analítico separado | Produção, por tenant |
| Fonte de genealogia | `animal_posicoes` (836 SBBs com pedigree real) | `sangues_linhagem` (cache por consulta à ABCCC ao vivo, por animal) |
| Profundidade | 2 gerações (pai/mãe + avós) | até 5 gerações |
| IC (endogamia) | Wright, 2 gerações | Wright, até 5 gerações; + regra dura pra parentesco de 1º grau/irmãos completos |
| Score competitivo | Sim — cruza com histórico real de resultados por combinação de sangue | Não — só considera saldo/sanidade da fonte, não histórico competitivo |
| Cobertura | Só ~836 SBBs com pedigree carregado | Qualquer animal com SBB (mas genealogia rasa se a ABCCC não tiver os pais indexados) |
| Consumido por quem | Só staff, dentro do Lab | Todo cliente, na tela de Cruzamentos |

**Os dois foram construídos de forma independente e não se falam.** Nenhuma chamada de rede liga
um ao outro hoje.

## 4. Onde isso deveria convergir (e ainda não converge)

O roadmap negociado com o Luciano (`docs/roadmap-fase-produto-2026-08.md`, item 4 — Agente de
IA interno) já propõe explicitamente reaproveitar `analisar_cruzamento`/`genealogia_resumo` do
Lab como a fonte de dados do "especialista ABCCC" do futuro agente. O ADR 0006
(`docs/adr/0006-agente-de-ia-interno-arquitetura.md`) lista `abccc_analisar_cruzamento` e
`abccc_genealogia_resumo` como ferramentas planejadas — nomes que ainda não existem
literalmente no banco (são a versão "exposta pro agente" do que já existe no Lab).

O que falta pra essa convergência acontecer, em ordem de esforço:

1. **Decidir o caminho de acesso** — o app não pode chamar o projeto analítico diretamente
   (é exatamente a invariante que motivou separar os dois depois do incidente). As opções já
   avaliadas foram: artefato estático (JSON publicado, o plano original — bom pra dado que muda
   pouco, como o resumo agregado de resultados ABCCC) vs. uma Edge Function em produção fazendo
   proxy (mais acoplado, mas dá pra rodar `analisar_cruzamento` sob demanda em vez de só ler um
   resumo pré-calculado). Pra **score de cruzamento sob demanda** (par específico
   garanhão×égua, não um resumo agregado), o artefato estático não serve — é preciso decidir
   entre replicar a lógica em produção (duplicar `analisar_cruzamento` contra
   `sangues_linhagem`) ou aceitar uma chamada de rede ao projeto analítico só para essa
   consulta pontual (o que reabriria a discussão de acoplamento do ADR 0005).
2. **Aumentar a cobertura de genealogia real** — hoje só 836 SBBs têm pedigree carregado no
   Lab. Sem mais catálogos com `sbb_pai`/`sbb_mae`, o motor mais sofisticado do Lab (que tem
   score competitivo, coisa que o produto não tem) só serve pra uma fração pequena do plantel
   de cada cabanha.
3. **Decidir se vale duplicar ou unificar os dois motores de IC** — hoje o produto já calcula
   um IC próprio (mais profundo, 5 gerações) via `sangues_linhague`; o Lab calcula outro (mais
   raso, mas com score competitivo). Não faz sentido manter os dois pra sempre — a pergunta de
   produto é se o valor está em trazer o score competitivo pro motor do produto, ou se o Lab
   deveria consumir `sangues_linhagem` também (que tem mais profundidade e mais cobertura).

## 5. Referências rápidas

| O quê | Onde |
|---|---|
| Mimba Lab (frontend) | `lab/index.html` |
| Schema de genealogia/score do Lab | `docs/migrations/dados-2026-08-20-fase5-genealogia.sql` |
| Backfill do histórico ABCCC no Lab | `docs/migrations/dados-2026-08-20-fase6-backfill-abccc.sql` |
| CSVs brutos da ABCCC | `dados/abccc/*.csv` + `dados/abccc/extrair.mjs` (decodificador Power BI DSR) |
| Catálogo com pedigree real (836 SBBs) | `dados/genealogia/catalogos_animais.csv` |
| Spec da jornada de Cruzamentos do produto | `docs/spec-acasalamento-jornada-tres-direcoes.md` |
| Motor de score do produto | `index.html`, funções `_jaConsanguinidade`/`_jaScoreConsang`/`_jaScoreDiversidade`/`_jaAnalisar` |
| Roadmap negociado (item 4 = agente de IA) | `docs/roadmap-fase-produto-2026-08.md` |
| Arquitetura planejada do agente | `docs/adr/0006-agente-de-ia-interno-arquitetura.md` |
| ADR de onde mora a Área de Dados (histórico completo, incidente) | branch `recuperacao/area-dados-fora-de-producao`, `docs/adr/0005-onde-mora-a-area-de-dados.md` — não está na `main` |
