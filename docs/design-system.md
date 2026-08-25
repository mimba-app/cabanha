# Mimba — Design System "Registro Vivo"

> Documento oficial e decisório da identidade visual do Mimba, no nível
> **operacional**: como a marca vira componente, token, tela e protótipo no
> código. A fonte da verdade da marca em si — princípio, wordmark, cor,
> voz, o que é e o que não é a Mimba — é o **Manual de Identidade Visual
> (MIV)**; este documento é alimentado a partir dele, traduzindo suas
> diretrizes pra decisão de implementação. Se um encontrar o outro
> divergente, o MIV vence e este documento precisa ser atualizado.
>
> Consolida o que já está implementado e aprovado (redesign "Registro Vivo",
> 2026-08-19) com a extensão que veio da jornada de acasalamento
> (2026-08-21) — que não é um desvio, é a mesma linguagem aplicada a um
> momento de mais peso. Este é o documento de referência para qualquer
> decisão futura de UI no Mimba.

## 1. Princípio

**Livro de registro, não painel de SaaS genérico.** Mimba trata os dados de uma
cabanha — genealogia, ciclos, cada animal — como um livro de registro físico:
pergaminho, selos, carimbos, tipografia editorial. A metáfora central é o
**registro** — algo que se carimba, se lacra, se consulta — não o dashboard
corporativo com cards achatados e azul genérico.

Isso não é decoração. É a diferença entre "um sistema que guarda dados de
cavalo" e "o livro de registro da sua cabanha, digital". A segunda é a
categoria que a Mimba quer ocupar.

## 2. Cor

Um único conjunto de tokens semânticos, com **claro e escuro definidos lado a
lado** — nunca um tema "principal" com o outro invertido às pressas. Ambos são
tratados como primeiros-cidadãos desde a origem. A troca é automática via
`prefers-color-scheme`, sem toggle manual na interface hoje.

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `--ink` | `#2B2419` | `#F0EFE9` | **Cor principal da marca** (auditoria 2026-08-25) — texto, e fundo do símbolo/monograma "M." (fixo em `#2B2419`, não muda com o tema — contraste maior que o verde). |
| `--campo` / `--campo-deep` | `#4F6B2E` / `#33461C` | `#8FB35A` / `#A9CD7A` | Verde da marca — uso pontual (positivo, "aprovado"). **Não é mais a cor primária** — Ink assumiu esse papel. |
| `--terracota` / `--terracota-ink` | `#B15A2E` / `#7A3B1C` | `#E08A54` / `#E08A54` | Acento secundário — eyebrows, links, destaque editorial |
| `--ouro` | `#B8860B` | `#E8C567` | **Reservado.** Só no ponto final do wordmark "Mimba." e do monograma "M." (login, rodapé da sidebar, sidebar) — a palavra/letra em si usa a cor de texto do contexto, só o ponto é sempre dourado — e no núcleo/selo da cerimônia de acasalamento. Nunca em fundo, UI ou hover — dourado em excesso vira "app de cassino", não "livro de registro". |
| `--critico` | `#9B3226` | `#E2776A` | Erro, proibido, consanguinidade alta |
| `--atencao` | `#A9791E` | `#E3B95E` | Alerta, vencimento próximo |
| `--areia` / `--pergaminho` / `--pergaminho2` | `#F4EFE6` / `#FCF9F3` / `#F8F3EA` | `#1A1A18` / `#242422` / `#1F1F1C` | Fundo de página / superfície de card / superfície aninhada |

**Regra de contraste no escuro:** os tons vívidos de `--campo` no claro
(`#4F6B2E`) ficam ilegíveis como texto sobre fundo escuro — por isso o escuro
usa uma variante mais clara (`#8FB35A`) para as MESMAS funções semânticas. Nunca
inverter cor sem checar contraste — cada par claro/escuro foi calibrado, não
gerado por fórmula.

**Regra de profundidade:** no claro, cards não têm borda — a profundidade vem
só de sombra (`--sh-sm` em repouso, `--sh-md` no hover). No escuro, sombra
sozinha não marca contorno nenhum contra um fundo já escuro, então todo card
ganha `border: 1px solid var(--ink-08)` (token `--card-border`) só nesse tema.
Borda dura + sombra fraca nos dois temas é o que faz um app parecer desenho 2D
— a Mimba usa uma técnica por tema, não a mesma em ambos.

## 3. Tipografia

Três famílias, três papéis — nunca misturados:

- **Manrope** (geométrica, peso 700/800 — token `--serif`, nome histórico
  mantido) — títulos, números grandes, nomes de animais, o "A" carimbado no
  selo. Trocou de Playfair Display em 2026-08-22 (pedido do sócio: a
  serifada lia como "antiga e romântica" pra um sistema com tecnologia
  embarcada; comparada com Space Grotesk e Bricolage Grotesque antes de
  decidir — ver `/design-system`, seção 03). Itálico usado só como acento
  pontual (uma palavra por vez) sai como itálico sintético — Manrope não tem
  face itálica de verdade no Google Fonts.
- **DM Sans** (400–700) — todo o resto: corpo de texto, botões, labels de
  formulário, navegação. A voz de trabalho, neutra e legível.
- **DM Mono** (400–500) — eyebrows (rótulos em caixa alta, letter-spacing
  ampliado), metadados (SBB, datas, contadores), valores numéricos em
  destaque (métricas do dashboard). A voz de dado/registro — como um carimbo
  de cartório ou o rodapé de um documento oficial.

Escala: 6 degraus, razão ~1.2, base 14px (`--fs-caption` 10px →
`--fs-2xl` 30px). Títulos de página usam Manrope 32px/800; títulos de card,
Manrope 20-21px/700; corpo, DM Sans 12-14px.

## 4. Espaçamento, raio, sombra

- **Raio:** `--r-sm` 8px (botões, inputs, badges pequenos) · `--r-md` 16px
  (cards) · `--r-lg` 26px (containers grandes, modais). Nada com raio 0 —
  a Mimba não é o estilo "broadsheet"/jornal de hairlines retas.
- **Sombra:** três degraus (`--sh-sm/md/lg`), cor calibrada por tema (marrom
  translúcido no claro, preto puro no escuro — nunca cinza neutro). É o
  principal veículo de profundidade no tema claro.
- **Etiqueta de brinco** (`.etq-brinco`): chip com um lado reto e um
  arredondado, furo recortado via `mask-image` — a metáfora literal do brinco
  de identificação do animal. Usado pra badges de identificação (RP/SBB,
  situação, pelagem, ciclo).
- **Selo de registro** (`.selo-registro`): círculo com anel pontilhado e
  glyph central em Manrope — usado no lugar de badge/pill pra status
  crítico em pontos-chave (vacina vencida, alerta prioritário).

## 5. Movimento — a cerimônia

A maior parte do app usa transições utilitárias e discretas (hover
`translateY(-1/-2px)`, fade, shimmer de carregamento) — o registro do dia a
dia não precisa de espetáculo.

Mas alguns momentos **merecem peso**: uma decisão de cruzamento que vai virar
uma cria de verdade, um parecer que vira registro oficial. Pra esses, a Mimba
tem uma segunda linguagem de movimento — **a cerimônia** — introduzida na
jornada de acasalamento (2026-08-21) e reservada daqui pra frente pra
momentos equivalentes (aprovar um cruzamento, fechar um registro definitivo):

- **Baralho embaralhando** — cartas girando em looping enquanto o sistema
  calcula/ranqueia, antes de revelar o resultado em lista.
- **Arena + núcleo pulsante** — dois elementos se aproximando fisicamente
  (`translateX`) enquanto um núcleo dourado pulsa no centro, como um selo
  esquentando antes de bater.
- **Selo carimbando** — `scale`+`rotate` com overshoot (`cubic-bezier` com
  ricochete), simulando o impacto físico de um carimbo de cartório — nunca
  um fade simples para esse momento.
- **Linhagens em confluência** — dois traçados (`stroke-dashoffset`
  animado) correndo um contra o outro; onde se encontram (ancestral comum),
  o ponto acende e pulsa com um halo expansivo.

Regra: a cerimônia é **reservada** — usá-la em toda transição do app a
esvazia. Ela marca o momento em que um dado vira decisão registrada, não
qualquer carregamento.

`prefers-reduced-motion: reduce` desliga todas as animações (inclusive a
cerimônia) para quem pediu menos movimento no sistema operacional — sem
exceção.

## 6. Voz e copy

- **Nomeie pelo que a pessoa reconhece, nunca pela implementação.** "Escolha
  a égua" — não "selecione o registro egua_id".
- **Voz ativa, verbo específico.** "Salvar rascunho" produz o resultado que o
  nome promete — nunca "Enviar" ou "Confirmar" genéricos que escondem o que
  vai acontecer.
- **Rótulos de wayfinding descrevem sequência real, não decoram.** "Passo 1
  de 3 · Escolher a égua" é legítimo porque a jornada É uma sequência de 3
  passos reais. Nomes de exploração de design ("Direção C", "O Conselho")
  nunca vazam pra interface — são vocabulário interno, não copy de produto.
- **Erros e pendências não pedem desculpa.** "AIE do garanhão vence em 22
  dias" — direto, sem "ops!" nem rodeio.
- **Números grandes em Manrope, contexto em DM Mono.** Um dado importante
  (nota do Conselho, coeficiente de endogamia, métrica do dashboard) ganha
  peso editorial; a explicação ao lado fica discreta e monoespaçada.

## 7. Onde cada coisa vive no código

Tudo em `index.html` (sem framework/bundler — ver `CLAUDE.md`):

- **Tokens** (`:root` + `@media (prefers-color-scheme: dark)`) — topo do
  `<style>` único do arquivo, comentado inline como "Registro Vivo — paleta
  oficial".
- **Componentes de base** (`.card`, `.btn`, `.badge`, `.etq-brinco`,
  `.selo-registro`, `.modal`, tabelas, tabs, inputs) — mesmo bloco `<style>`,
  logo depois dos tokens.
- **Jornada de acasalamento** (`.jornada-ac` e classes `.ja-*`) — bloco
  próprio, comentado, com `--ja-*` como **aliases** dos tokens reais (nunca
  valores fixos — ver seção 2). Ver
  `docs/spec-acasalamento-jornada-tres-direcoes.md` pro fluxo completo.
- **Marca** (`.mimba-dot`) — a regra do MIV ("Mimba" na cor de texto do
  contexto, ponto sempre `--ouro`) é uma única classe, `.mimba-dot`,
  aplicada em toda ocorrência do wordmark/monograma:
  `.login-form-wordmark`, `.login-logo-title` (telas de
  restaurando/bloqueado/cancelado/definir-senha), `.powered-by` (rodapé do
  Dashboard) e `.logo-monogram` (avatar da sidebar — sempre "M.", nunca só
  "M"). Cuidado de especificidade: `.logo-monogram span` já tem uma regra
  de cor própria (`#fff`) mais específica que `.mimba-dot` sozinha — por
  isso existe também `.logo-monogram span.mimba-dot`, que precisa
  continuar junto se a estrutura desse componente mudar.
  **Formato do ponto (auditoria de marca, 2026-08-25):** o ponto **não** é
  mais o caractere "." em texto — o glifo real do "." na Manrope
  ExtraBold, medido pixel a pixel, é um **quadrado de cantos retos**, não
  um círculo; depender do glifo arrisca renderizar redondo se a fonte
  falhar/cair pro fallback. `.mimba-dot` agora é um `<span>` vazio
  estilizado como bloco quadrado explícito (`display:inline-block`,
  `width`/`height` em `em`, `background:currentColor`, `border-radius:0`)
  — nunca usar `<span class="mimba-dot">.</span>` (com o caractere "."
  dentro) em código novo, e nunca com `border-radius` diferente de `0`.
  Mesmo tratamento aplicado no MIV.

**Regra pra quem for adicionar UI nova:** nunca crie um token de cor/sombra/
fonte novo sem antes checar se um destes já serve. Se precisar de um
namespace próprio (como `.jornada-ac`), sempre **aliase** os tokens reais —
nunca copie valores fixos, ou o componente novo perde o dark mode de graça e
vira uma ilha visual (foi exatamente o bug corrigido em 2026-08-21).

## 8. Estado de adoção

A maior parte do app (Dashboard, Animais, Saúde, Reprodutivo, Financeiro,
Nutrição, Eventos, Estoque, Medidas, Sangues) já usa este sistema de forma
consistente — é o resultado do redesign "Registro Vivo" (2026-08-19). A
jornada de acasalamento (C→B→A) foi a extensão mais recente, e chegou a
divergir brevemente (tokens fixos em vez de aliases) antes de ser corrigida —
ver commit `c703369`.

Não identificamos hoje nenhuma outra área do app fora deste sistema. Se o
redesign visual mais amplo mencionado pelos sócios significa ir além do que
já está aplicado — um novo tema, uma segunda marca, um ajuste de paleta —,
isso é uma decisão de branding que precede este documento, não uma correção
de inconsistência técnica. Vale registrar como uma decisão separada,
explicitamente aprovada, antes de tocar em código.
