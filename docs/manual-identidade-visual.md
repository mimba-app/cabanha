# Mimba — Manual de Identidade Visual (MIV)

> Pedido do Luciano: um documento formal de identidade visual, no padrão que uma equipe de
> branding/design normalmente produz — marca, cor, tipografia, componentes, voz — a partir do
> que já foi decidido e implementado no redesign "Registro Vivo".

## Onde está

**Versão formatada (a referência principal):** publicada como página interativa —
peça o link de artifact mais recente desta conversa, ou veja `/artifacts` no Claude Code.
Cobre marca (wordmark + monograma), paleta com claro/escuro lado a lado, as três famílias
tipográficas, componentes (etiqueta de brinco, selo de registro), a linguagem de movimento, as
regras de voz/copy, exemplos de uso incorreto e o estado de adoção — a mesma craft visual que o
produto usa, aplicada ao próprio manual.

**Versão de referência técnica:** [`docs/design-system.md`](design-system.md) — o documento que
já existia, voltado para quem implementa (engenheiros trabalhando no `index.html`). O MIV é o
mesmo conteúdo de fundo, reformatado e com camadas adicionais (regras de uso incorreto,
lacunas de marca) para servir também conversas de branding, parceria e apresentação — não só
implementação.

Os dois devem ficar em sincronia. Se um token, cor ou regra mudar, atualizar os dois — ou, no
mínimo, atualizar `design-system.md` (fonte técnica) e revisar o MIV na sequência.

## O que o MIV documenta

1. **Essência da marca** — o princípio "livro de registro, não painel de SaaS genérico".
2. **Marca** — wordmark "Mimba." (Manrope 900, dourado reservado) e o monograma "M" (avatar
   funcional). Documenta explicitamente que **não existe hoje um símbolo pictórico de marca** —
   é uma lacuna real, não um esquecimento do manual.
3. **Cor** — os tokens semânticos completos, claro e escuro lado a lado, com as duas regras que
   não são óbvias por fórmula (contraste do verde no escuro; profundidade via borda vs. sombra
   por tema).
4. **Tipografia** — Manrope/DM Sans/DM Mono, cada uma com um papel único, mais a escala de
   tamanhos.
5. **Componentes** — etiqueta de brinco e selo de registro, os dois elementos que carregam a
   metáfora do registro de forma literal.
6. **Movimento** — a distinção entre transição utilitária (o dia a dia) e a cerimônia
   (reservada para decisões que viram registro oficial).
7. **Voz & copy** — as regras de escrita de interface, com exemplos certo/errado.
8. **Uso incorreto** — um catálogo dos desvios que já aconteceram no código real e foram
   corrigidos, como referência do que evitar.
9. **Estado de adoção** — o que está consistente hoje versus o que é decisão em aberto (símbolo
   de marca dedicado, grade de área de proteção).

## Sobre publicação

Este documento e a versão interativa foram gerados como uma peça formal, mas a decisão de
publicá-los publicamente, restringir a um espaço interno de staff, ou manter como referência
apenas dentro do repositório/artifact privado **fica com o Luciano e o Pedro** — não foi
especificado um destino, então nada foi tornado público por conta própria. A versão interativa
nasce privada por padrão; puxar link e decidir o escopo de compartilhamento é uma ação
deliberada, feita quando (e se) fizer sentido.
