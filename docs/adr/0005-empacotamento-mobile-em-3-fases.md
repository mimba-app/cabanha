# 0005 — Empacotamento mobile em 3 fases (Capacitor primeiro, nativo depois)

**Status:** Aceito (2026-08-21). Decidido por Pedro e o sócio Luciano.

## Contexto
Demanda de negócio: publicar o Mimba nas lojas (App Store / Play Store) para dois públicos — dono/cabanheiro em campo, muitas vezes com conexão ruim/instável, e veterinário, com uso pontual em visita à propriedade. Offline de verdade foi avaliado como **desejável, não bloqueante**: não é o que travaria um lançamento, o app já entrega valor mesmo exigindo conexão a maior parte do tempo.

Hoje o frontend é um `index.html` único, sem framework/bundler/`package.json`, hospedado no GitHub Pages — decisão deliberada pra manter o deploy leve (ver CLAUDE.md: "não sugerir React, build step ou package manager sem confirmar antes"). Qualquer caminho de empacotamento mobile esbarra nessa invariante.

A escolha foi entre lançar rápido nas lojas com o que já existe, ou investir num rewrite nativo antes de validar o canal mobile — com prazo/impacto imediato pesando mais que a abordagem "ideal" de longo prazo.

## Decisão
Estratégia em 3 fases:

1. **Fase 1 (agora):** empacotar o `index.html` atual com Capacitor (ou Cordova — Capacitor é a opção mais moderna/mantida hoje; a escolha exata da ferramenta de empacotamento fica pra sessão de implementação dedicada). Publica rápido nas lojas, menor esforço. Sem offline real, sem push nativo de verdade nessa fase — é conscientemente "o site dentro de um app", aceito como troca pelo prazo. Essa fase **introduz pela primeira vez um build step / `npm` / `package.json`** no projeto — é a mudança estrutural real que este ADR registra.
2. **Fase 2 (depois):** modo offline leve — o app detecta sozinho quando está sem conexão (sem sincronização bidirecional complexa; só detectar e avisar/bloquear ações que precisam de rede quando offline).
3. **Fase 3 (futuro):** projeto nativo "de verdade" (React Native ou nativo puro — ferramenta não decidida ainda), pensando em rodar um agente de IA embarcado no app. Essa é outra frente de roadmap, ainda em discovery (`docs/roadmap-fase-produto-2026-08.md`, item 4).

**Isolamento do build step:** o setup do Capacitor (e tudo que ele trouxer — `package.json`, `node_modules`, config nativa) deve ficar **isolado numa pasta própria** (ex.: `mobile/`) ou em branch/worktree separado, e **não pode contaminar** o fluxo de deploy atual do `index.html` via GitHub Pages. O app web continua existindo exatamente como hoje — mono-arquivo, sem bundler, deploy leve.

Este ADR registra a **direção**, não a implementação. A implementação real do empacotamento (escolha final da ferramenta, estrutura de pastas, config de build) fica para uma sessão dedicada futura.

## Consequências
- (+) Presença nas lojas com esforço mínimo, sem esperar um rewrite nativo — captura a oportunidade de negócio agora.
- (+) A invariante "zero framework/bundler" do app web (CLAUDE.md) é preservada — ela passa a valer só para o `index.html`/GitHub Pages, não para o projeto inteiro.
- (−) O projeto passa a ter, pela primeira vez, uma superfície com `npm`/`package.json`/build step (dentro de `mobile/` ou equivalente) — CLAUDE.md precisa ser atualizado para deixar claro que a regra "sem framework/bundler sem confirmar antes" vale para o frontend web, e que a pasta mobile é uma exceção deliberada e isolada.
- (−) Fase 1 entrega "site empacotado", não um app nativo — sem offline real, sem push nativo. Aceito como dívida consciente até a Fase 2/3.
- (−) Duas superfícies de frontend a partir daqui (web mono-arquivo + wrapper mobile) — exige disciplina pra não deixar a pasta mobile vazar convenções (build, dependências) pro `index.html`, nem o contrário.
- (?) Fase 3 (nativo/React Native + agente de IA embarcado) ainda não tem ferramenta decidida — é intenção de longo prazo, não compromisso.

## Alternativas consideradas
- **Reescrever direto em React Native/nativo:** rejeitada por esforço e prazo — atrasaria a presença nas lojas sem ganho imediato para o público-alvo (uso majoritariamente conectado).
- **Não fazer nada mobile agora:** rejeitada por oportunidade de negócio — dono/cabanheiro e veterinário se beneficiam de um app nas lojas mesmo sem offline completo.
- **Offline-first já na Fase 1:** descartado por ora — sincronização bidirecional complexa não é bloqueante pro lançamento; fica pra Fase 2 como detecção simples de conectividade.
