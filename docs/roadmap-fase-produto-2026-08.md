# Roadmap — próxima fase (negociado com o Luciano, 2026-08-22)

> Quatro frentes decididas entre Pedro e Luciano depois de revisar a jornada de
> acasalamento e a página `/design-system/`. Este documento é o ponto de
> referência pra sequenciar o trabalho — atualizar conforme decisões forem
> tomadas, marcando o que sai de "a definir" pra "decidido" ou "em andamento".

## Prioridade e status

| # | Frente | Prioridade | Status |
|---|---|---|---|
| 1 | Ajuste de tipografia do design system | Alta (destrava o resto) | ✅ Feito — Manrope aplicada em tudo, mergeado na `main` |
| 2 | Cruzamentos com dois modos (rápido / imersivo) | **A mais importante** | ✅ Implementado, em `staging` — aguardando validação do Luciano antes de mergear |
| 3 | Avaliar app mobile nativo + loja | Média | ✅ Decidido (2026-08-22) — ver seção 3 |
| 4 | Agente de IA interno de apoio | Média | Escopo de produto fechado — falta ADR de arquitetura |

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

## 3. App mobile — decisão em 3 fases (2026-08-22)

**Público:** dono/cabanheiro no campo + veterinário. **Offline:** desejável,
não bloqueante — o app já entrega valor exigindo conexão a maior parte do
tempo, offline de verdade não é o que trava o lançamento.

**Estratégia decidida com o Pedro** (prazo/impacto pesaram mais que a forma
"ideal" agora):

1. **Agora — empacotar o `index.html` com Capacitor.** Menor esforço, publica
   rápido nas lojas. Continua sendo "o site dentro de um app" (sem push
   nativo de verdade, sem offline real) — aceito conscientemente como troca
   pelo prazo.
2. **Depois — offline leve.** O próprio app percebe quando está sem conexão
   (o Pedro já viu esse padrão funcionar bem em outro contexto) — sem
   sincronização complexa, só detectar e avisar/segurar ações que precisam
   de rede.
3. **Futuro — projeto nativo de verdade**, "como manda o figurino", pensando
   no agente de IA (item 4) rodando dentro do app.

**Isso muda a convenção do projeto:** Capacitor introduz `npm`/build step
num repo que hoje é deliberadamente `index.html` puro sem framework (ver
`CLAUDE.md`, "Frontend sem framework/bundler"). Por ser uma decisão
estrutural, o `arquiteto` está registrando isso como ADR antes de eu tocar
em estrutura de projeto — ver `docs/adr/`.

**Próximo passo real:** depois do ADR, um branch/worktree separado pra não
misturar o setup do Capacitor com o `index.html` de produção — plano de
implementação vem numa sessão dedicada a isso.

---

## 4. Agente de IA interno de apoio

**Escopo inicial fechado (2026-08-22)** — mais amplo do que "chatbot de
dúvida":

- **Casos de uso** (todos confirmados, não é só um):
  1. Perguntas sobre o dado da própria cabanha ("quantas éguas prenhas esse
     ciclo?", "resumo da semana").
  2. Sugestão/análise de manejo e cruzamento — vai além de responder, dá uma
     opinião (ex.: reaproveitando o ranking do Conselho — seção "A jornada"
     do design system — como uma das fontes de raciocínio).
  3. **Especialista ABCCC** — genealogia, campeões, ancestralidade,
     reaproveitando diretamente o trabalho já feito no Mimba Lab
     (`mimba-analytics`, RPCs `analisar_cruzamento`/`genealogia_resumo`) em
     vez de começar do zero.
  4. Ajuda de uso do sistema (onboarding/suporte embutido).
- **Superfície:** chat flutuante, acessível de qualquer tela do app.
- **Escopo de dado:** cabanha logada (isolamento multi-tenant intacto) +
  dado agregado/público da ABCCC (`mimba-analytics` — não é dado de outra
  cabanha, então não fere isolamento).

**Ainda em aberto** (perguntas de arquitetura, não de produto):

- Modelo/orquestração — qual LLM, tool-calling pra consultar o banco com
  segurança (nunca deixar o agente montar SQL livre contra schemas de
  cabanha — precisa de RPCs/ferramentas restritas, no mesmo espírito de
  `tem_acesso_tenant`), custo por chamada e como isso entra no preço do
  plano.
- Como o agente combina os 3 domínios de dado (schema da cabanha, Mimba Lab,
  conhecimento geral do sistema) sem confundir contexto.
- Dado o tamanho, esse é candidato a **outro ADR** antes de qualquer linha de
  código — decisão estrutural (novo serviço/edge function, acesso a dado
  sensível, custo recorrente por chamada de modelo).

**Próximo passo:** sessão de arquitetura dedicada (o `arquiteto` conduz) pra
desenhar como o agente acessa dado com segurança e qual o modelo de custo,
antes de qualquer protótipo.

---

## Sugestão de sequência

1. **Fonte** (item 1) — rápido, baixo risco, destrava visualmente o resto.
2. **Cruzamentos dois modos** (item 2) — depois de fechar as 3 decisões
   acima, é a próxima leva de código; entra na mesma onda de PRs da jornada.
3. **App mobile** e **Agente de IA** (itens 3 e 4) — cada um começa com uma
   sessão de discovery antes de qualquer linha de código.
