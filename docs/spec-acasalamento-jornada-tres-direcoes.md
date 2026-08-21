# Acasalamento — jornada das três direções (C → B → A)

> Decisão de 2026-08-21 (Pedro + Luciano). Referência de design: artefato Claude
> "Mimba — Acasalamento: três direções" (`Main.dc.html`, `Conselho.dc.html`,
> `Confluencia.dc.html`, `DossieSelado.dc.html`). Cores, tipografia e animações
> devem seguir **exatamente** esse artefato — este spec só adapta os dados
> (mock → real) e o encadeamento das telas.

## Por que uma jornada, não uma escolha única

Dois perfis de usuário coexistem: quem quer analisar uma cruza com calma, efeito
e "perfumaria" (fim de tarde, decisão importante), e quem precisa despachar um
volume grande de cruzas rápido (fila de trabalho). Em vez de escolher uma das
três direções do artefato, elas viram **estágios de uma mesma jornada**, cada
um parando num ponto de valor diferente:

1. **C — O Conselho.** Ponto de entrada. Escolhe-se a égua; o sistema ranqueia
   todas as fontes de cobertura do ciclo por nota. Já resolve a pergunta "com
   quem cruzo?" e já embute o filtro de consanguinidade na nota — é onde o
   usuário apressado pode parar.
2. **B — Confluência de Sangues.** Ao escolher uma fonte do ranking, abre o
   diagrama de linhagens cruzando as duas árvores genealógicas. Explica o
   *porquê* da nota (não só o veredito) — segundo ponto de parada, pra quem
   quer entender o risco antes de aprovar.
3. **A — O Dossiê Selado.** Ferramenta final, sob demanda ("Rodar dossiê
   selado"), pro acasalamento que já está quase escolhido — o carimbo oficial,
   com a lista de pendências (vacina, AIE, saldo) antes de aprovar de fato.

Isso substitui a tela de duas colunas (clique garanhão → clique égua) e o modal
de confirmação com "Simulando..." (`_renderSimulacaoAcasalamento`,
[index.html:9723](../index.html)) — que viram, respectivamente, o passo C e o
corpo do passo A.

## Fluxo

```
[Lista de éguas do ciclo]
        │ clique numa égua
        ▼
┌─────────────────────────┐
│  C · O CONSELHO          │  baralho embaralhando (1.5–2.4s) → lista ranqueada
│  "Quem combina com ela?" │  de fontes do ciclo, por nota
└───────────┬───────────────┘
            │ clique "Acasalar" numa linha do ranking
            ▼
┌─────────────────────────┐
│  B · CONFLUÊNCIA DE       │  duas árvores genealógicas correndo uma contra
│  SANGUES                  │  a outra; ancestral comum acende e pulsa
│  "Cruzar linhagens"       │  → aqui já dá pra "Aprovar mesmo assim" ou
└───────────┬───────────────┘     "Comparar com outra fonte" (volta pro C)
            │ (opcional) "Rodar dossiê selado"
            ▼
┌─────────────────────────┐
│  A · O DOSSIÊ SELADO      │  arena aproxima os dois → núcleo pulsa → selo
│  ceremonial final         │  carimba → dossiê completo (sangue projetado,
└───────────┬───────────────┘     histórico, pendências) → Aprovar acasalamento
            │
            ▼
     salvarAcasalamento() [já existe, sem mudança de contrato]
```

Usuário apressado: C → clica "Acasalar" → já está em B → clica "Aprovar mesmo
assim" direto, sem nunca abrir A. Usuário com calma: C → B → "Rodar dossiê
selado" → A → "Aprovar acasalamento".

## Design tokens (copiados literalmente do artefato)

```css
--ink:#2B2419; --ink-70:rgba(43,36,25,.7); --ink-50:rgba(43,36,25,.52);
--ink-30:rgba(43,36,25,.3); --ink-15:rgba(43,36,25,.14); --ink-08:rgba(43,36,25,.07);
--campo:#4F6B2E; --campo-deep:#33461C; --campo-soft:#DEE7C9;
--terracota:#B15A2E; --terracota-soft:#F3DCC9; --terracota-ink:#7A3B1C;
--ouro:#B8860B; --ouro-soft:#F1E2B8;
--critico:#9B3226; --critico-soft:#F4DAD3;
--atencao:#A9791E; --atencao-soft:#F1E3C2;
--areia:#F4EFE6; --pergaminho:#FCF9F3; --pergaminho2:#F8F3EA;
--sh-sm:0 1px 2px rgba(43,36,25,.09);
--sh-md:0 1px 1px rgba(43,36,25,.06), 0 14px 26px -12px rgba(43,36,25,.28);
--sh-lg:0 2px 3px rgba(43,36,25,.07), 0 30px 56px -16px rgba(43,36,25,.34);
--serif:'Playfair Display',Georgia,serif; --sans:'DM Sans',-apple-system,sans-serif; --mono:'DM Mono','SF Mono',monospace;
```

Fontes via Google Fonts (`Playfair Display`, `DM Sans`, `DM Mono`) — a mesma
família já usada na marca Mimba (ver `CLAUDE.md`), então entram como um novo
`<link>` no `<head>` do `index.html`, sem conflito.

Este é um tema **paralelo** ao tema padrão do app (`--green`/`--chrome-*`
etc.) — só se aplica dentro do container da jornada de acasalamento
(namespace `.jornada-ac`), não vaza pro resto do app.

## Direção C — O Conselho

**Gatilho:** lista de éguas do ciclo (reaproveita o filtro de
`renderAcasalamentosMatch`: fêmeas "Na Cabanha" com estágio Cria, sem
acasalamento não-cancelado no ciclo). Clique numa égua monta o card "Égua
escolhida" (`.alvo`) e mostra o botão "Quem combina com ela?".

**Animação:** 3 cartas (`.carta.c1/.c2/.c3`) girando em looping
(`@keyframes gira1/2/3`, 1.5s cubic-bezier) por ~2.4s (tempo real do cálculo,
não fixo — ver Dados). Texto: "cruzando a linhagem de {égua} contra N fontes
do ciclo {ciclo}".

**Resultado:** lista ranqueada (`.linha`, entrada animada `@keyframes entra`
com delay escalonado), nota 0–100 com barra colorida por faixa
(`--campo`/`--atencao`/`--critico`), linha de "porquê" em uma frase, botão
"Acasalar" por linha (`.btn2`/`.btn2.forte` na primeira colocada).

### Fórmula da nota (documentada no próprio artefato, usar literalmente)

```
nota = consanguinidade (peso 5) + diversidade de sangue (peso 3) + saldo e sanidade da fonte (peso 2)
```

Componentes, em escala 0–10 cada, multiplicados pelo peso e somados (nota
final 0–100 = 5·consang + 3·diversidade + 2·saldo_sanidade × 2, escala
ajustada pra fechar em 100):

- **Consanguinidade (peso 5):** reaproveita o IC estimado já calculado em
  `_renderSimulacaoAcasalamento` ([index.html:9802-9817](../index.html)) via
  `sangues_linhagem.ancestrais_pos` (Wright, gen 1–5). Nível 1 (proibido/1º
  grau) → nota 0 e a fonte nem entra no ranking. Nível 2 (ancestral comum
  gen ≤2) → nota baixa (ex.: 10–30). IC estimado > 6,25% → nota proporcional
  decrescente. IC = 0 → nota 10 (máxima).
- **Diversidade de sangue (peso 3):** proporção de nomes de ancestrais
  **distintos** entre os dois lados nas gerações 1–3 (menos sobreposição de
  linhagem, mesmo abaixo do limiar de consanguinidade, pontua mais alto) —
  mesma fonte de dados (`ancestrais_pos`), sem consulta nova.
- **Saldo e sanidade da fonte (peso 2):** saldo disponível/total
  (`_saldoFonteCobertura`, já existe) + validade de exames obrigatórios do
  garanhão (AIE etc., mesma checagem que hoje aparece como alerta de texto
  solto na Fase Controle do Kanban reprodutivo) combinados em nota 0–10.

Fontes com nível 1 (proibido) somem do ranking. As demais entram ordenadas
por nota. Nenhuma chamada de rede nova — todo dado já é local
(`animais`, `fontesCobertura`, `sangues_linhagem` via `_supa`, igual ao que
`_renderSimulacaoAcasalamento` já busca hoje).

## Direção B — Confluência de Sangues

**Gatilho:** botão "Acasalar" numa linha do ranking do Conselho.

**Diagrama:** duas árvores genealógicas (SVG) partindo da raiz (garanhão à
esquerda, égua à direita) até a geração em que houver dado
(`ancestrais_pos`, até gen 3 — a profundidade que os dados reais sustentam
hoje; a arte do artefato usa gen 1–3 fixas, mesma profundidade). Ramos
(`.ramo`) desenham com `stroke-dashoffset` animado
(`@keyframes corre`, 1.15s). Nós (`.no`) acendem em sequência
(`@keyframes acende`). Se houver ancestral comum: nó vira `.no.comum`
(vermelho, pulsa — `@keyframes bate`), ponte entre os dois lados aparece, halo
pulsante (`@keyframes halo`) marca o ponto.

Diferença do artefato: lá as coordenadas são fixas (mock de um caso
específico). Aqui o layout é **gerado por função** (árvore binária simples,
posições calculadas por geração/índice), pra caber qualquer combinação real
de profundidade e nomes — reaproveitando a mesma gramática visual (cores,
espessura de traço, keyframes, timing) mas sem coordenadas fixas.

**Se não houver ancestral comum:** desenha as duas árvores sem ponte, sem nó
`.comum`, e o painel abaixo mostra "Sem ancestral comum até a Nª geração"
(verde, sem `.veredito` vermelho) em vez do bloco de alerta.

**Ações:** "Comparar com outra fonte" (volta ao ranking do Conselho, C, com
a mesma égua) · "Aprovar mesmo assim" (vai direto pro save, pulando A) ·
"Rodar dossiê selado" (avança pra A).

## Direção A — O Dossiê Selado

**Gatilho:** botão "Rodar dossiê selado" em B, OU direto de C se o usuário
pular B (ex.: nota já alta e sem alerta) — mesmo componente, substitui
inteiramente `_renderSimulacaoAcasalamento` como o corpo do modal de
confirmação (`modal-acasalamento`).

**Animação:** arena com os dois cards se aproximando (`.fase-1`/`.fase-2`,
`transform:translateX`), fio dourado acendendo no meio, núcleo pulsante
(`.nucleo`, `@keyframes pulsa`/`onda`) durante os "passos" (texto com check,
`@keyframes entra` escalonado — reaproveita as mesmas frases que hoje já
existem: "Consultando SBB X e Y na ABCCC", "Montando gerações", etc.), selo
carimbando (`@keyframes carimbo`, cubic-bezier com overshoot) com halo de
impacto (`@keyframes impacto`).

**Dossiê (grade de 3 blocos):**
1. Sangue projetado na cria — % por linhagem, mesma base de
   `ancestrais_pos` usada em B.
2. Histórico entre os dois — cruzamentos anteriores (`acasalamentos`
   filtrados por par, já existe em `_renderSimulacaoAcasalamento`) + crias do
   garanhão na cabanha + partos anteriores da égua.
3. Antes de aprovar — checklist de pendências reais: vacina/exame em dia,
   AIE do garanhão, saldo da fonte (mesmos dados que hoje aparecem soltos
   em alertas de texto pelo Kanban reprodutivo, agora agrupados aqui).

**Ações finais:** "Testar outro par" (volta pro início/C) · "Salvar rascunho"
· "Aprovar acasalamento" → chama `salvarAcasalamento()` sem mudança de
contrato.

## Dados — o que já existe vs. o que precisa de código novo

| Precisa | Fonte | Status |
|---|---|---|
| Lista de éguas do ciclo | `animais` filtrado (já existe em `renderAcasalamentosMatch`) | reaproveita |
| Fontes do ciclo + saldo | `fontesCobertura`, `_saldoFonteCobertura` | reaproveita |
| IC estimado / ancestrais comuns | `sangues_linhagem.ancestrais_pos` via `_supa` | reaproveita (mesma query de hoje) |
| Nota do Conselho (fórmula) | combina os 3 acima | **novo** — função `_acNotaFonte(egua, fonte)` |
| Diversidade de sangue | `ancestrais_pos` (contagem de nomes distintos) | **novo** — mesma fonte, cálculo novo |
| Validade de exames/AIE | tabela `exames`/eventos de saúde do garanhão | **novo** — checar o que já existe pro Kanban reprodutivo e reaproveitar a mesma query |
| Layout do diagrama (B) | gerado em JS a partir de `ancestrais_pos` | **novo** — função de posicionamento em árvore binária |
| Cruzamentos anteriores, crias, partos | `acasalamentos`, `gestacoes` | reaproveita |

Nenhuma migration nova é necessária — tudo já está nas tabelas atuais do
schema por cabanha.

## Fases de implementação

1. **C — Conselho** (entrada): substitui a coluna de éguas + fluxo de seleção
   da tela de match atual. Autocontido, testável isolado.
2. **B — Confluência**: acionado a partir de C. Maior risco técnico (gerador
   de árvore SVG dinâmico) — validar com 2–3 casos reais (com e sem
   ancestral comum, profundidades diferentes) antes de seguir.
3. **A — Dossiê**: substitui `_renderSimulacaoAcasalamento` como corpo do
   modal de confirmação existente; reaproveita `salvarAcasalamento()` sem
   mudança de assinatura.

Cada fase é testável e "shippable" isolada — dá pra parar depois de C ou
depois de B se o tempo apertar, sem deixar nada pela metade (a tela antiga
de duas colunas só é removida quando C estiver pronta e testada).
