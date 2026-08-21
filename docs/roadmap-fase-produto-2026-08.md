# Roadmap — próxima fase (negociado com o Luciano, 2026-08-22)

> Quatro frentes decididas entre Pedro e Luciano depois de revisar a jornada de
> acasalamento e a página `/design-system/`. Este documento é o ponto de
> referência pra sequenciar o trabalho — atualizar conforme decisões forem
> tomadas, marcando o que sai de "a definir" pra "decidido" ou "em andamento".

## Prioridade e status

| # | Frente | Prioridade | Status |
|---|---|---|---|
| 1 | Ajuste de tipografia do design system | Alta (destrava o resto) | A fazer — escopado abaixo |
| 2 | Cruzamentos com dois modos (rápido / imersivo) | **A mais importante** | A fazer — precisa de 2-3 decisões antes de implementar |
| 3 | Avaliar app mobile nativo + loja | Média | Não escopado — discovery |
| 4 | Agente de IA interno de apoio | Média | Não escopado — discovery |

---

## 1. Design system — trocar a fonte de título

**Feedback do Luciano:** gostou da página `/design-system/`, mas a Playfair
Display (a serifada usada em títulos, números grandes, selos) lê como
"antiga e romântica" — quer algo mais reto, minimalista, que combine com "um
sistema com tecnologia embarcada", sem perder a essência do rústico/campo,
só menos enfeitado.

**Escopo:** trocar só o token `--serif` (a família de display/título) — DM
Sans (corpo) e DM Mono (dado/metadado) já são retas e limpas, não precisam
mudar. A cerimônia de movimento (seção 6/7 do design system), a paleta e os
componentes ficam como estão — é uma troca de fonte, não um redesign.

**Onde entra:** `index.html` (`--serif` no `:root` + o `@font-face`/link do
Google Fonts), `design-system/index.html`, `docs/design-system.md`, e
republicar o artifact.

**Próximo passo:** eu levanto 2-3 candidatas (sans geométrica/humanista
moderna, com peso suficiente pra número grande e título — não uma "Inter
genérica" que perderia toda personalidade) e mostro lado a lado com a
Playfair antes de aplicar em qualquer lugar.

---

## 2. Cruzamentos — dois modos, escolha do usuário

**A frente mais importante**, segundo o Luciano. Ele gostou muito da jornada
nova (C → B → A, com a cerimônia), mas quer que ela seja **um modo entre
dois**, não a única opção:

- **Modo Rápido** — o mais parecido possível com a tela antiga (duas
  colunas, clique-clique, sem animação), pra quem precisa despachar volume
  alto de cruzas.
- **Modo Inteligência** — a jornada completa que já construímos (Conselho →
  Confluência de Sangues → Dossiê Selado).

Um seletor na entrada da tela "Cruzamentos" deixa a pessoa escolher qual
modo quer usar naquele momento.

**Decisões que preciso fechar com vocês antes de implementar:**

1. **O que exatamente é o "Rápido"?** Recriar a tela antiga de duas colunas
   tal como era (garanhão × égua, clique-clique, sem o Conselho ranqueando)?
   Ou uma versão enxuta que já usa o ranking do Conselho mas pula B e A (ex.:
   escolhe a égua → já cai direto no ranking, sem baralho animado, sem
   cerimônia — clica "Acasalar" e confirma na hora, sem passar por
   Confluência/Dossiê)? A primeira é mais fiel ao "como era antes"; a segunda
   reaproveita o trabalho de ranking sem duplicar lógica.
2. **A escolha é lembrada?** Uma vez que a pessoa escolhe um modo, ele vira o
   padrão dela (salvo tipo o tema — por usuário, `localStorage`) até trocar
   de novo, ou pergunta toda vez que abre a tela?
3. **O seletor é por pessoa ou por cabanha?** Um veterinário que testa a
   fundo pode preferir o Inimersivo; o cabanheiro que só bate muitos cruzamentos
   no fim do dia pode preferir o Rápido — faz sentido a preferência ser por
   usuário, não uma configuração única da cabanha.

**Depende de:** a jornada em si (PR #19) ainda está em `staging`, não
mergeada — esse trabalho de dois modos pode entrar antes do merge (mais
simples, um branch só) ou depois (mais limpo pra revisar em separado). Minha
sugestão: fazer o seletor de modos como parte da mesma leva, já que vocês
confirmaram a direção — evita reabrir a tela duas vezes.

---

## 3. Avaliar app mobile nativo + publicação em loja

**Ainda não escopado.** Perguntas que precisam de resposta antes de eu
conseguir dar uma recomendação séria:

- Pra quem é o app — cliente final (dono de cabanha no campo, uso offline
  importa?) ou também staff/veterinário?
- O que muda tecnicamente: hoje o Mimba é um `index.html` único, sem
  framework/bundler (decisão deliberada, ver `CLAUDE.md`) — publicar em loja
  normalmente significa ou (a) empacotar esse mesmo HTML num wrapper nativo
  (Capacitor/Cordova — menor esforço, mas experiência ainda é "web dentro de
  um app"), ou (b) reescrever telas-chave em nativo/React Native (esforço
  bem maior, mas melhor UX/performance/notificações push).
- Prazo e orçamento — publicar na App Store/Play Store tem custo recorrente
  (contas de desenvolvedor) e processo de revisão que precisa entrar no
  planejamento.

**Próximo passo:** uma sessão de discovery dedicada (posso conduzir) pra
sair com uma recomendação real de abordagem — não vale eu chutar arquitetura
sem entender pra quem é e o que o app precisa fazer offline vs. online.

---

## 4. Agente de IA interno de apoio

**Ainda não escopado.** Mesma situação — "vai vender muito" é a tese, mas
faltam as perguntas de produto:

- Apoio a quem, fazendo o quê? Exemplos de uso real ajudam muito aqui:
  "pergunta em português sobre a genealogia de um animal", "sugestão de
  manejo nutricional baseada no histórico", "dúvida sobre como usar uma tela
  do sistema", "resumo do que aconteceu na cabanha na semana"?
- Onde ele mora na interface — um chat flutuante, uma aba própria, dentro de
  cada tela específica (contextual)?
- Que dado ele enxerga — só o da cabanha logada (isolamento entre tenants
  continua valendo, e com força redobrada se o agente tiver acesso amplo ao
  banco) ou também dado agregado da ABCCC?
- Custo por chamada de modelo e como isso entra no preço do plano.

**Próximo passo:** também discovery — vale conversar sobre 2-3 casos de uso
concretos que vocês já imaginam, pra eu conseguir desenhar a primeira versão
em vez de um agente genérico "pergunte qualquer coisa".

---

## Sugestão de sequência

1. **Fonte** (item 1) — rápido, baixo risco, destrava visualmente o resto.
2. **Cruzamentos dois modos** (item 2) — depois de fechar as 3 decisões
   acima, é a próxima leva de código; entra na mesma onda de PRs da jornada.
3. **App mobile** e **Agente de IA** (itens 3 e 4) — cada um começa com uma
   sessão de discovery antes de qualquer linha de código.
