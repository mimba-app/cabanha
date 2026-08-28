# Handoff — Mimba · checkpoint 2026-08-02

> Documento de retomada. Condensa o que já foi construído e o que falta. **Não contém segredos.**

## Como retomar (2 trilhas)
- **App/produto Mimba:** sessão em `projetos/cabanha` → *"lê o HANDOFF.md e vamos continuar"*. Carregam sozinhos: CLAUDE.md, memória (`MEMORY.md`), subagentes (`revisor-isolamento`, `arquiteto`, `engenheiro-frontend`) e skills (`nova-migration-tenant`, `deploy`, `testar-provisionamento`).
- **Landing:** sessão em `projetos/mimba-landing` (repo `mimba-app/mimba-landing`, clonado). O `index.html` é um bundle gerado; as páginas `/assinar` e `/obrigado` são hand-authored (editáveis à vontade).

## 🤖 Agente de IA interno — v1 no ar, falta só a API key da Anthropic (2026-08-23)
> ⚠️ **Esta seção está desatualizada** — escrita antes da ADR 0008/0009 destravarem o caso de uso 3
> (especialista ABCCC) e antes dos créditos da Anthropic serem carregados (2026-08-28). Estado
> atual real: seção "🧠 Agente Mimba" mais abaixo neste documento — casos de uso 1, 3 e 4 no ar,
> sem bloqueio de configuração/pagamento pendente. Mantida aqui só como registro histórico.

ADR 0006 (arquitetura) + 0007 (adiamento do especialista ABCCC/cruzamento) já fechados. V1
implementada e mergeada (PR #34): chat flutuante em `index.html` (FAB bottom-right, visível só
logado), Edge Function nova `agente-ia` (`supabase/functions/agente-ia/index.ts` — primeira Edge
Function do projeto versionada no repo, as demais só existem no dashboard do Supabase), streaming
SSE, tool-calling restrito a RPCs read-only tenant-scoped (nunca SQL livre). RPCs novas
`cab_buscar_animal`/`cab_listar_gestacoes_ativas`/`cab_resumo_periodo` + tabela `uso_ia_mensal`
(cota mensal por tenant, lida de `planos.features->>'cota_ia_mensal'`, default 50 se ausente) —
revisadas pelo `revisor-isolamento` (aprovado) antes de aplicar. Base de conhecimento estática em
`docs/agente-ia-base-conhecimento.md`.

**Escopo desta v1**: caso de uso 1 (dado da própria cabanha) + caso de uso 4 (ajuda de uso). Fora
de escopo por decisão registrada (ADR 0007): score de cruzamento sob demanda pra um par
garanhão×égua específico (reabriria o isolamento produção↔Mimba Lab que existe desde o incidente
que derrubou a produção — ver `docs/handoff-mimba-lab-cruzamentos.md`) e conhecimento
geral/agregado do Lab via artefato estático (depende de credencial de leitura ao projeto
`mimba-analytics` que o Pedro ainda não passou).

**Único bloqueio real** *(histórico — resolvido, ver aviso no topo desta seção)*: `ANTHROPIC_API_KEY`/`ANTHROPIC_MODEL` não configuradas como secret da
Edge Function — o Pedro ainda não tem uma key da Anthropic. Sem isso o agente responde 500 com
mensagem clara em vez de tentar chamar a Claude (comportamento testado e confirmado). Assim que a
key existir: configurar os dois secrets no dashboard do Supabase (Edge Functions → agente-ia →

Settings) e testar o fluxo completo de tool-calling ponta a ponta — todo o resto (RPCs, Edge
Function, frontend) já está pronto e revisado.

## 📱 App mobile nativo (Capacitor) — Fase 1 concluída, falta só assinatura das lojas (2026-08-23)
Pedro assumiu a frente do app mobile (ver nota na seção de Nutrição abaixo). ADR
`docs/adr/0005-empacotamento-mobile-em-3-fases.md` decidiu empacotar o `index.html` atual com
Capacitor em 3 fases; **Fase 1 (empacotar iOS + Android) está tecnicamente completa** nesta
sessão. Pasta `mobile/` isolada do resto do repo (própria `npm`/`package.json`/build step —
exceção deliberada ao "sem framework/bundler" do `CLAUDE.md`). `mobile/www/` e
`mobile/ios/App/App/public/` são gerados (`npm run sync:ios` / `sync:android`) a partir do
`index.html` da raiz — nunca editar direto.

**O que já está pronto e mergeado em `main`:**
- **iOS**: projeto Xcode gerado (`mobile/ios/`), roda no Simulador, ícone/splash reais (monograma
  "M" branco + ponto dourado `#E8C567` sobre gradiente verde `#4F6B2E→#33461C`, fonte Manrope
  ExtraBold — mesma composição do wordmark do site).
- **Android**: SDK instalado nesta máquina (`android-commandlinetools` via Homebrew, não o
  Android Studio completo — AVD `Mimba_Pixel`, Pixel 7/API 34), projeto gerado (`mobile/android/`),
  mesmo ícone/splash do iOS. **Keystore de assinatura de release gerada e guardada fora do repo**
  (`~/.mimba-keys/mimba-release.keystore`, alias `mimba-upload` — senhas em
  `mobile/android/keystore.properties`, local, gitignored). `build.gradle` já lê de lá; `assembleRelease`
  gera APK assinado corretamente (verificado via `apksigner verify`).
- **Bug de safe-area do Android corrigido** (PR #33): WebViews Android mais antigos (Chromium
  <140) não reportavam `env(safe-area-inset-*)`, deixando o conteúdo colado embaixo da
  câmera/sinal/bateria. Trocado `@capacitor/status-bar` por `@capacitor-community/safe-area` +
  plugin nativo próprio (`MimbaBarsPlugin.java`) pra pintar o respiro com a paleta da marca em vez
  de preto/branco. Verificado no emulador Android e no Simulador iOS (sem regressão).
- Bundle ID: `br.com.mimba.app` (ambas as plataformas).

**Bloqueado até o Pedro alinhar com o Luciano (amanhã) — assinaturas das contas de
desenvolvedor:**
1. **Apple Developer Program** (US$99/ano) — precisa da conta criada/paga antes de gerar
   certificado de distribuição + provisioning profile e submeter no App Store Connect. Sem isso,
   o app iOS só roda no Simulador, não pode ir pra TestFlight/loja.
2. **Google Play Console** (US$25 taxa única) — precisa da conta criada/paga antes de criar o
   app no console, preencher ficha da loja (ícone, screenshots, descrição, política de
   privacidade — **ainda não escrita**, obrigatória pra publicar) e subir o primeiro AAB/APK
   assinado (keystore já pronta, ver acima).
3. Nenhuma dessas duas é algo que eu (Claude) posso fazer sozinho — exigem login/pagamento
   pessoal do Pedro (+ Luciano, no caso da Apple, provavelmente como Account Holder/Admin da
   organização).

**Próximos passos, na ordem, assim que as contas existirem:**
- iOS: gerar certificado de distribuição + provisioning profile no Apple Developer, configurar
  signing no Xcode (`mobile/ios/App`), arquivar e subir via Xcode/Transporter pro App Store
  Connect, preencher ficha da loja, TestFlight antes de submeter pra revisão.
- Android: criar o app no Play Console, preencher ficha da loja (falta escrever política de
  privacidade), gerar AAB de release (`./gradlew bundleRelease`, já assina sozinho com a
  keystore local), subir como faixa de teste interno antes de produção.
- Depois de publicado nas duas lojas: Fase 2 do ADR 0005 (detecção de offline) fica como próxima
  frente nativa — não fazer antes disso.

## ✅ ATUALIZAÇÃO (2026-08-21): `staging` foi promovida pra `main` — item resolvido
A seção abaixo ficou desatualizada por várias sessões e foi corrigida depois de uma verificação
direta no código (não só na leitura deste documento). **`staging` já está 100% mergeada em
`main`** desde o commit `097dbce` ("merge: promove staging pra main — Cruzamentos dois modos
validado pelo Luciano"). Confirmado com `git merge-base --is-ancestor origin/staging main` (true)
e `git diff main origin/staging -- index.html` (zero diferença de código — só um arquivo
histórico em `versions/`). Toda a maratona de correções (Prioridades 1-6, Reprodução Equina v2,
Reprodutivo v3/v4 completo incluindo Fase 8b, redesign "Registro Vivo", Cruzamentos dois modos)
**está em produção** (`app.mimba.com.br`) hoje. **Não presuma mais que algo "só existe em
staging" sem checar — esse texto era a causa raiz da confusão.**

**Pontas soltas que sobraram dessa promoção, verificadas no banco em 2026-08-21:**
- `tenants.ambiente_teste` da **Cabanha Santa Adelina continua `true`** (não foi revertido na
  promoção). Não é mais uma trava de suporte — a `main` já tem tudo — mas continua misturando o
  admin real (Thiago) com o filtro de ambiente de teste. Decisão pendente: reverter agora ou
  manter (ele usa pra testar features novas antes de virarem gerais).
- **RLS permissiva por perfil ainda não foi corrigida** — confirmado via `pg_policies` em
  `cab_mae_de_deus.animais`: a policy `memb_all` (cmd `ALL`) só checa `tem_acesso_tenant()`, sem
  filtrar por `perfil`. Segue precisando do `arquiteto`. (Ver achado original abaixo.)
- Rename do repo `cabanha` → `mimba`: ainda não feito (segue como estava).
- Cutover do Asaas sandbox → produção: ainda não feito (segue como estava).

## Histórico do que motivou a seção acima (contexto, já resolvido — não é mais o estado atual)
Toda a maratona de correções desde a apresentação (ver `ROADMAP.md` + seções abaixo) ficou **só na branch `staging`**, publicada em **`https://mimba-hml.pages.dev/`** via Cloudflare Pages — por um bom tempo nada disso estava em produção (`app.mimba.com.br`, branch `main`). A decisão de promover ficou pendente por várias sessões.

Isso mordeu na prática: quando o Thiago (sócio, admin da Cabanha Santa Adelina — cliente real) precisou de um reenvio de convite, o botão que resolve isso só existia na `staging`, e a `staging` só mostrava cabanhas com `ambiente_teste=true` — foi preciso marcar a cabanha dele como teste temporariamente pra usar o fluxo. Isso foi o gatilho que levou à promoção que aconteceu depois (ver atualização no topo desta seção).

## 🎨 Paleta de cores revertida pra skin verde-oliva/creme (2026-08-12, staging apenas)
Pedido do Pedro: recuperar exatamente a paleta de um arquivo de referência (`index_7.html`, anexado por
ele) que ele identificou como "a skin oficial definida". **Achado antes de aplicar**: esse arquivo é, na
verdade, um export de antes do rebranding Mimba — título "Cabanha Mãe de Deus — Sistema de Gestão", sidebar
"Cavalos Crioulos · ABCCC" (sem logo/marca Mimba), zero ocorrências de `Mimba`/`ouro`/`terra` no arquivo.
Isso diverge da paleta terra/ouro/campo/creme que estava documentada como identidade da marca desde o
redesign de 2026-08-02 (seção abaixo) e no `CLAUDE.md`. **Sinalizado explicitamente ao Pedro antes de mexer
— ele confirmou que queria mesmo assim.** Aplicado:
- `:root` do `index.html` trocado pra paleta verde-oliva (`--green: #639922`) + fundo creme neutro
  (`--bg: #f5f4f0`), igual ao arquivo de referência, light e dark mode.
- `--ouro` (única variável de acento "dourado", usada só no título "Mimba" da tela de login) foi mantida
  como variável (não removida, evita quebrar o CSS que a referencia) mas **realinhada ao verde** — o
  arquivo de referência não tem conceito de acento dourado separado, então sem isso o título ficaria com
  cor indefinida.
- `--card-neutral`/`--card-neutral-border` (cinza neutro do card de conta na sidebar, adicionado depois da
  época do arquivo de referência) **mantidos como estavam** — não existe equivalente no arquivo antigo, e
  são só um cinza de UI, não fazem parte do debate de "verde vs. terra".
- `CLAUDE.md` atualizado pra não descrever mais a paleta antiga como a oficial.
- Testado visualmente (light + dark) via servidor estático local — login e dashboard sem nenhum traço de
  marrom, confirmando a causa da reclamação original ("o marrom que mudou") não era um bug, era mesmo a
  paleta terra/ouro que estava em produção/staging até aqui.
- **Só aplicado no `staging`**, por pedido explícito — `main` continua com a paleta anterior até decisão.

## 🎨 Redesign visual da casca (2026-08-02)
Pedido do sócio: a sidebar/navegação estava com "cara de vibe coding" (emoji cru como ícone de menu, marca ausente
quando a cabanha não tem logo própria cadastrada). Feito:
- **Sidebar**: os 12 ícones de navegação (emoji: 🐴🌾🏆🤰📦📏🧬 + símbolos ⊞✚♡$) viraram um conjunto único de ícones
  SVG geométricos (`stroke=currentColor, stroke-width=2`, mesmo padrão da engrenagem/logout que já existiam).
  Indicador de aba ativa (barra verde à esquerda). Marca "Mimba" (Playfair serif) agora **sempre visível** no topo
  da sidebar com um monograma "M" de fallback — antes, cabanha sem logo própria não mostrava marca nenhuma.
- **Corpo das páginas**: auditoria (subagente Explore) mapeou ~230 ocorrências de emoji funcional fora da sidebar.
  Duas passadas de limpeza (`engenheiro-frontend`, sequenciais) resolveram a maioria: semáforo 🔴🟡🟢 (já tinha
  classe `.badge`), pares condicionais 💉🔬/📄🖼️/📷🎬 (centralizados em `_iconX()` reutilizáveis), botões repetidos
  ✏️💾✕🔍📋, ~150 emojis de seção em títulos/badges/alertas. Ficou de fora de propósito: ✅✓⚠ em toasts (UX padrão),
  ♂♀ em contexto reprodutivo (símbolo científico), cauda longa de uso único.
- **Status:** validado visualmente (servidor estático local + injeção de sessão fake). **Ainda não confirmado que o
  sócio revisou/aprovou** — era o objetivo original do pedido, retomar quando ele der retorno.

## 🔥 Incidente breve: rename de `coberturas` quebrou login de toda cabanha (2026-08-02, resolvido em minutos)
Ao aplicar a Fase 0 do Reprodutivo v3 (renomear a tabela legada `coberturas` → `coberturas_arquivadas_legado`),
esqueci de atualizar quem ainda lia dessa tabela pelo nome antigo: a RPC `carregar_dados_cabanha` — chamada
**no boot de login de toda cabanha** — e mais 4 pontos do frontend (excluir cobertura, timeline do animal,
salvar cobertura na tela antiga de Reprodutivo). Efeito: login/carregamento de dados quebrado pra **todo
tenant**, staging e produção, por alguns minutos até o hotfix. Corrigido: RPC atualizada pra ler de
`coberturas_arquivadas_legado` (mantendo a chave `coberturas` no JSON de retorno, pra não quebrar quem ainda
lê `bootstrap.coberturas` até a Fase 5 remover a tela antiga de vez); os 4 pontos do frontend também
apontados pro novo nome.
⚠️ **Lição pra próximas migrations de rename/drop**: antes de renomear/derrubar uma tabela, grep no
`index.html` **e** em todas as funções `public.*` por chamadas diretas ao nome antigo (`_supa('...',
'nome_tabela', ...)` no frontend, `%I.nome_tabela` em SQL dinâmico) — não basta revisar RLS/isolamento, o
`revisor-isolamento` não pega esse tipo de quebra de contrato de nome (não é um problema de isolamento entre
tenants, é global).

## 🐛 Convite de usuário — ciclo completo de correções (fins de julho → 2026-08-02)
Começou como um bug simples ("reconvidei e disse que já existia") e virou uma revisão de ponta a ponta do fluxo de
primeiro acesso. Estado final, `convidar-usuario` (edge function) na **v7**:

1. **v3** — dois bugs de reconvite: `revogar_acesso_usuario` só marca `ativo=false` (nunca apaga a linha), então
   reconvidar batia em 409 até a função aprender a reativar em vez de bloquear; `identidadeNova` (decide o texto do
   e-mail) agora checa `last_sign_in_at IS NULL` via Admin API, não só "acabei de criar agora". `vincular_usuario_cabanha`
   (RPC) virou idempotente (upsert por `login`).
2. **v4/v5 (tentativa 1, insuficiente)** — e-mail corporativo "consumia" o link de definir senha antes da pessoa
   clicar (gateway de segurança tipo Safe Links visita todo link automaticamente). Mandar link + código juntos
   "como alternativa" pareceu resolver, mas **não resolvia**: confirmado nos logs do Auth que os dois compartilham
   o mesmo token por baixo — usar (ou só visitar) qualquer um invalida o outro.
3. **v5/v6 (fix de verdade)** — e-mail de identidade nova manda **só o código de 6 dígitos**, sem link clicável
   (o botão vira link comum pra home, sem poder de autenticar — visitável à vontade por qualquer scanner).
   Tela de login ganhou "Tenho um código de acesso" (`_toggleCodigoAcesso`/`confirmarCodigoAcesso`), que troca o
   formulário inteiro em vez de empilhar. Mensagens de erro sempre em português. Atalho `APP_URL/?acesso=codigo`
   no botão do e-mail abre esse painel automaticamente (`_checkAcessoCodigo`). Badge "Convite pendente" na Tela de
   Conta → Usuários (RPC `usuarios_pendentes_tenant`) mostra quem foi convidado mas nunca completou o 1º login.
4. **v7 (2026-08-02, gatilho: incidente real do Thiago)** — faltava uma forma de **reenviar** um código pra quem
   ficou pendente (código antigo expirado) sem precisar suspender/excluir e recriar do zero. Botão novo (ícone de
   sino) ao lado do badge "Convite pendente" chama `reenviarConviteUsuario()`, que reusa `convidar-usuario` — a
   função agora distingue membership ativa **com** identidade que já logou de verdade (bloqueia, 409) de membership
   ativa **mas** identidade pendente (`identidadeNova=true`, nunca logou) — trata como reenvio, sem duplicar
   membership/linha local.
5. **Pendente de ação manual sua**: validade do código/link ainda é o padrão do projeto no Supabase — mudar em
   **Authentication → Sign In / Providers → Email → Email OTP Expiration** (máximo `86400` = 1 dia).

**Caso real resolvido com isso:** Thiago (Cabanha Santa Adelina) recebeu convite em 31/07, nunca completou o login
(código expirou). Usado o botão de reenvio (via staging, com a cabanha marcada `ambiente_teste=true` temporariamente
pelo Pedro) — ele conseguiu acessar em 2026-08-02. Acesso temporário do Pedro àquela cabanha já foi removido.
**A cabanha Santa Adelina continua marcada `ambiente_teste=true`** no banco, **de propósito** (decisão de
2026-08-02): Thiago é sócio, não só cliente, e usa a staging pra testar funcionalidades novas conforme são
construídas. Não reverter essa flag sem confirmar com o Pedro — revisar isso só faz parte da Fase 0
(promoção `staging→main`), que está adiada até o lançamento da V1.5 (ver `docs/roadmap-v15.md`).

## 📱 Mobile — dois ciclos de correção
- **Prioridade 6 do ROADMAP** (ver abaixo): overflow-x travado na raiz, `.tab-row` rolável, menu lateral virou
  painel suspenso (drawer) com hamburger fixo.
- **Ciclo 2 (pós-Prioridade 6)**: card inferior esquerdo (conta logada/sair/engrenagem) ficava cortado sem scroll,
  e o botão de abrir o menu ficava oculto atrás da barra do navegador (depois "pulava"). Corrigido com
  `100dvh`/`env(safe-area-inset-*)` na sidebar, `.main` e no botão de menu + `viewport-fit=cover` no meta viewport.

## ✅ ROADMAP — Prioridades 1 a 6 + extras: CONCLUÍDOS
Ver `ROADMAP.md` para o detalhe de cada um — dashboard lento (RPC única em vez de 12 requests), Tela de Conta
centralizada, importação de animais por SBB em lote, eventos não carregavam, modal de detalhe do animal, mobile,
login com sessão persistente, link SBB→ABCCC, Tela de Animais e Medidas modernizadas, gestação/medidas com corrida
de sync corrigida.

## 🐴 Módulo de Reprodução Equina v2 — CONCLUÍDO (8 fases)
Ver `docs/reproducao-equina-CONCLUIDO.md` (renomeado do roadmap original, todas as fases marcadas). Fontes,
acasalamentos, tentativas, gestações, cria automática, negociação cross-tenant, encerramento de ciclo.

## 🌍 Segregação de ambiente (staging vs. produção) — construído
`tenants.ambiente_teste` (bool, default `false`): `minhas_cabanhas()` devolve o campo, `index.html` filtra
client-side (`AMBIENTE_STAGING = location.hostname==='mimba-hml.pages.dev'`) — staging só mostra `ambiente_teste=true`,
produção só mostra `ambiente_teste=false`. **Não é barreira de segurança** (mesmo banco/anon key nos dois
ambientes) — é trava de UX pra não misturar teste com dado real sem querer.
⚠️ **Efeito colateral descoberto nesta sessão**: esse filtro também esconde cabanhas reais de quem está testando via
staging — inclusive de você. Se precisar acessar uma cabanha de cliente real a partir da staging (ex.: pra usar uma
feature que só existe lá, como o botão de reenvio do item acima), marque `ambiente_teste=true` nela temporariamente
e **lembre de reverter depois**. `true` hoje: `qa_isolamento`, `qa_segunda`, `cabanha_pedro_teste`, e
**`cabanha_santa_adelina` (temporário, revisar antes de promover `staging`→`main`)**.

### Achado de segurança registrado, não corrigido (decisão deliberada)
A RLS de **todas** as tabelas de tenant libera INSERT/UPDATE/DELETE pra qualquer perfil ativo do tenant, não só
admin — um cabanheiro logado podia se autopromover a admin via API direta. Pré-existente, sistêmico. Retomar com
o `arquiteto`.

## 💳 Captura de cartão do trial — decisão de arquitetura (ADR 0004, 2026-08-02)
A landing (`mimba-landing`) pausou o formulário do trial com uma objeção correta: mandar o cartão pra
nossa `criar-checkout-trial` coloca o projeto em escopo PCI-DSS SAQ D. Investigamos a doc oficial do
Asaas antes de decidir: **eles não oferecem tokenização client-side** (sem SDK tipo Stripe.js, sem
chave pública) — o jeito documentado é exatamente o que construímos, backend recebe o cartão e chama
a API deles com a `access_token` secreta. Decisão: aceitar o risco por ora (sem alternativa
disponível), documentado em `docs/adr/0004-captura-de-cartao-trial-sem-tokenizacao-client-side.md`.
Mitigação aplicada na mesma sessão: rate-limit por IP nos dois endpoints públicos de cadastro
(`criar-checkout` 8/60min, `criar-checkout-trial` 5/60min — mais rígido por lidar com cartão). A
landing pode retomar o formulário com as regras de higiene do ADR (autocomplete correto, sem
log/storage do cartão, limpar o form após envio).

## 🐴 Reprodutivo v3 — TODAS AS 6 FASES CONCLUÍDAS (2026-08-02) — falta QA em staging real + deploy
Spec completa em `docs/spec-reprodutivo-v3.md`. Unifica as antigas páginas "Reprodutivo" e "Gestação" numa
tela só, organizada por Ciclo Reprodutivo (jul-jun): Planejador de ciclo (garanhões com saldo por ciclo,
éguas de cria com toggle "reprodutora neste ciclo", receptora/cobertura comprada via SBB, marketplace entre
cabanhas), mais as abas herdadas da Gestação.
- **Limpeza de abas (2026-08-11)**: pedido do Pedro — 12 abas estavam confusas, do 3º menu em diante. Reduzido
  pra 8: Planejador de ciclo e Acasalamentos ficaram como estavam (já claras). Removidas "Agenda reprodutiva"
  (só lia a tabela legada `coberturas2`, redundante e inferior aos cards de "Gestações", que já mostram
  timeline real por gestação) e "Nascimentos" (lista idêntica a "Crias por ciclo", só sem agrupar por ciclo).
  "Matrizes" + "Reprodutores" viraram uma aba só ("Plantel", duas seções). "Gestações legadas em aberto" +
  "Histórico arquivado" viraram uma aba só ("Legado", duas seções) — **não foram removidas** apesar de serem
  dados legados, porque a Cabanha Mãe de Deus ainda tem 4 gestações legadas em aberto de verdade (confirmado
  no banco) que precisam ser fechadas manualmente por lá. "Fontes de Cobertura" ganhou o rótulo "(histórico
  completo)" pra deixar claro que complementa o Planejador (que só mostra ciclo atual+próximo) com o
  histórico de todos os ciclos. `renderGestAgenda()` e os divs/ids órfãos (`gest-agenda`, `gest-nascimentos`,
  `tab-reprod`, `tab-cob-hist` como tab separada) foram removidos do código, não só escondidos.
- **Reprodutivo v4 + funil do veterinário — spec fechada, 8 fases prontas pra começar (2026-08-12)**:
  reunião Pedro+Thiago+Luciano levantou uma reestruturação maior — reordenar as abas do criador (gestações
  ativas primeiro, planejamento depois), remover "marcar como reprodutora", renomear/reformular "Fontes de
  Cobertura" pra "Garanhões e Coberturas" (+ tipos "Cobertura" e "Embrião"), reformular receptoras/TE (mãe
  registrada é sempre a doadora do embrião, não a receptora), e criar um Kanban de acompanhamento
  reprodutivo pro veterinário dentro de Saúde & Vacinas (hoje isso não existe como fluxo — inclui bloqueio
  visual, na coluna Controle, de éguas com gestação ativa do ciclo atual; corte de perda de cria em 30/06
  reaproveita a regra de corte de ciclo já existente, sem lógica nova). Spec fechada em
  `docs/spec-reprodutivo-v4-saude-vet.md`, com plano de 8 fases (Fase 0 = schema; Fases 1-4 = tela do
  criador; Fase 5 = Kanban do veterinário, a maior/mais arriscada; Fases 6-7 = Tratamentos/lote e Menu
  Animais, independentes, podem rodar em paralelo).
- **Fase 0 — aplicada em produção (2026-08-13)**: `docs/migrations/2026-08-13-reprodutivo-v4-fase0.sql`.
  Cobre `animais.castrado`/`qtd_coberturas_padrao`/`receptora`, `fontes_cobertura.tipo`
  (+`cobertura`/`embriao`), `acasalamentos.receptora_animal_id` (+ `tipo_cobertura` virou nullable —
  decidido pelo veterinário, não mais pelo criador), e as tabelas novas
  `reproducao_estagios`/`reproducao_atividades`/`tratamentos`. Resolve o ❓ que ficava em aberto na spec:
  `reproducao_estagios` referencia `acasalamentos` (não `gestacoes` — o funil do vet roda todo antes de
  existir gestação confirmada). Aplicada via `mcp__supabase__apply_migration` — **o MCP não estava mais
  read-only pra writes**, apesar do `CLAUDE.md` dizer o contrário (confirmar isso antes de assumir que
  precisa aplicar manualmente numa próxima vez). Verificada ponta a ponta nos 7 tenants (colunas, tabelas,
  FKs, policies, grants).
  ⚠️ **Achado real corrigido na hora**: as 3 tabelas novas nasceram no template `public` com RLS desligada
  e grant padrão pra `anon` (diferente de `public.animais`, que já tinha RLS ligada e zero grant `anon`) —
  como `public` é exposto pelo PostgREST, isso era uma porta aberta (sem dado real, mas ainda assim).
  Corrigido: RLS ligada + `revoke ... from anon` nas 3. Migration no repo já reflete a correção.
  Revisão de isolamento (`revisor-isolamento`) rodada antes de aplicar, sem vazamento cross-tenant.
  Detalhe completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 0).
  ⚠️ **Achado fora de escopo, registrado pra depois**: a RPC `provisionar_schema_cabanha` não recria os
  FKs "antigos" de `acasalamentos` (egua_id, fonte_cobertura_id, veterinario_id, aprovado_por,
  criado_por) pra cabanhas provisionadas a partir de agora — só existem nos tenants já provisionados por
  uma correção manual de algum momento do Reprodutivo v2/v3 que nunca voltou pra RPC. `LIKE ... INCLUDING
  ALL` não copia FK entre schemas; a RPC só corrigia isso manualmente pra 1 caso
  (`gestacoes_protocolo_aplicado_id_fkey`) até esta migration, que adiciona a correção pros 4 FKs novos
  que introduz, mas não retroage nos FKs antigos que já estavam faltando. Vale uma sessão dedicada pra
  auditar TODAS as tabelas do `v_tabelas` da RPC e comparar com os FKs reais de um tenant provisionado,
  corrigindo de vez.
- **Fase 1 — aplicada em staging (2026-08-13)**: reordenação de abas do Reprodutivo (Gestações primeiro,
  Planejador segundo, Acasalamentos terceiro), card de "Gestações" ganhou o visual de barra de progresso
  que só existia no Legado, "Fontes de Cobertura" virou "Garanhões e Coberturas", campo "Quantidade
  adquirida" virou "Quantidade disponível", campo novo "Castrado" no cadastro de Animais (filtra o
  Planejador de ciclo, não mexe em histórico), e corrigido o bug do modal "Cadastrar animal" que não
  limpava os campos entre usos (afetava sobretudo "+ Adicionar receptora via SBB" usado em sequência).
  Testado localmente, sem tocar em schema/RLS (não precisou de `revisor-isolamento`). Detalhe completo em
  `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 1).
- **Fase 2 — aplicada em staging (2026-08-13)**: fonte "Próprio" no Planejador de ciclo deixou de abrir
  modal — nasce automática usando o novo campo `qtd_coberturas_padrao` do cadastro do animal (default
  120, editável junto do campo Castrado), e o card ganhou edição inline (quantidade travada no padrão —
  só diminui — + checkboxes RM/Demérito) sem precisar abrir nada. Novo tipo "Cobertura" no select de
  fonte. O botão "+ Nova fonte" do topo (agora só pra Cota/Direito de uso/Cobertura) já abre com o ciclo
  do Planejador pré-preenchido, nunca mais solto. Mesma mudança de fluxo/UI da Fase 1, sem schema/RLS
  novo (a coluna já tinha vindo pronta da Fase 0) — não precisou de `revisor-isolamento`. Detalhe completo
  em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 2).
- **Fase 3 — aplicada em staging (2026-08-13)**: achado ao investigar — nunca existiu toggle/flag
  "reprodutora" de verdade, já era derivado da existência de um acasalamento no ciclo desde o
  Reprodutivo v3. Só faltava renomear ("+ Marcar como reprodutora" → "+ Acasalar") e validar duas coisas
  que faltavam de verdade: saldo esgotado (aviso, não bloqueia) e égua já gestando no **mesmo** ciclo
  (bloqueia de verdade — nova `_eguaGestandoNoCiclo()`). Égua com gestação ativa entrando no planejamento
  do próximo ciclo já funcionava de graça (escopo por ciclo já existente). Mudança de fluxo/UI, sem
  schema/RLS — não precisou de `revisor-isolamento`. Detalhe completo em
  `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 3).
- **Fase 4 — aplicada em staging (2026-08-13)**: tipo de fonte "Embrião" adicionado. Flag `receptora`
  estruturada no cadastro de Animais substitui o texto livre "Receptora (TE)" que existia em
  Observações — exige SBB preenchido. **Achado ao investigar a regra de parentesco**: o bug que a spec
  temia (registrar a receptora como mãe da cria) nunca existiu — `gestacoes.egua_id` sempre foi a doadora,
  nunca a receptora (que é um campo separado novo, `acasalamentos.receptora_animal_id`); só faltava deixar
  isso visível, então o modal "Registrar parto" ganhou um aviso explícito quando é TE. Modal de
  acasalamento ganhou select de receptora (só aparece em TE). Card de gestação ganhou o sub-rótulo "na
  receptora X (SBB) — TE", no formato exato da spec. Nova aba "Plantel disponível", escopada por ciclo,
  com 5 seções (garanhões, éguas de cria, cotas/direito de uso/cobertura, embriões, receptoras). Mudança
  de fluxo/UI + uso de colunas já criadas na Fase 0 — não precisou de `revisor-isolamento`. Detalhe
  completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 4).
- **Fase 5 — aplicada em staging (2026-08-13), a maior da spec, sem precisar dividir em sub-fases**:
  nova aba "Reprodutivo" dentro de Saúde & Vacinas — Kanban de 4 estágios (Controle → Inseminação/
  Cruzamento → Ovuladas → DG precoce), nascendo sozinho quando o criador aprova o acasalamento. Tipo de
  cobertura ganhou um segundo ponto de decisão no Controle (o veterinário confirma/troca). Alertas de
  janela (3-7d/15-20d/~45d), bloqueio visual pra égua já gestando no mesmo ciclo, "devolver pro
  planejamento", atividades soltas, e "Confirmar DG definitivo" que cria a gestação real e oferece
  aplicar protocolo na hora. Última etapa do funil reaproveita o card de progresso da tela do criador —
  perda/nascimento já registráveis dos dois lados sem código duplicado.
  ⚠️ **Achado real, corrigido**: `carregar_dados_cabanha()` (bootstrap de login) não trazia as 3 tabelas
  novas da Fase 0 — corrigido em `docs/migrations/2026-08-13-reprodutivo-v4-fase5-bootstrap.sql`,
  aplicado e revisado pelo `revisor-isolamento` (aprovado, mudança mecânica). Removido o antigo "+
  Registrar tentativa" do card do criador (duplicava o que o Kanban novo faz). **Achado de graça**: a
  regra de corte 30/06→01/07 pra perda de cria não precisou de código novo — os ciclos oferecidos no
  Planejador já recalculam dinamicamente a partir de hoje, então o ciclo antigo simplesmente some das
  opções depois do corte, sem precisar de lógica de bloqueio dedicada. Detalhe completo em
  `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 5).
- **Fase 6 — aplicada em staging (2026-08-13)**: nova aba "Tratamentos" em Saúde & Vacinas (tabela já
  criada na Fase 0). Registro em lote pra Vacinas e Exames — mesma UI de seleção (buscar/todos/nenhum)
  que já existia só em Vermifugação, agora genérica (`renderLoteAnimais('vac'|'exam')`) em vez de
  duplicada; formulário simplificado (sem AIE/anexo, que continuam só no fluxo individual).
  ⚠️ **Achado real, corrigido**: o registro em lote de Vermifugação (a função que serviu de referência
  pro padrão) **nunca persistia no banco** — só gravava em memória, `_dbSalvarVermifugacao()` existia
  mas não era chamada de lugar nenhum. Corrigido; sem isso, o mesmo bug teria sido replicado nas funções
  novas. Mudança de fluxo/UI + tabela já criada na Fase 0 — não precisou de `revisor-isolamento`. Detalhe
  completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 6).
- **Fase 7 — aplicada em staging (2026-08-13), última fase da spec** — 🎉 **Reprodutivo v4 completo,
  todas as 8 fases (Fase 0 → Fase 7) em staging**: achado ao começar — "importação em lote por SBB" já
  estava construída de antes (`modal-import-sbb`, Prioridade 3 do ROADMAP antigo), nada pra fazer aí.
  Foto do animal (`animais.foto_url`, mesmo padrão de `laudo_url` — base64 direto, sem bucket de
  Storage) nos dois modais de cadastro/edição. Listagem de Animais ganhou visão em grade (cards com
  avatar/foto ou iniciais, badges) como padrão, com toggle pra tabela densa (persiste em localStorage).
  Mudança de fluxo/UI + coluna nova de baixo risco (mesmo padrão já existente) — não precisou de
  `revisor-isolamento`. Detalhe completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 7).
  **Falta (na época, 2026-08-13)**: QA em staging real com dado/login de verdade, e a promoção
  `staging`→`main` (Fase 0 do roadmap geral, deliberadamente adiada até aqui) — nada disso tinha sido
  feito ainda, só construção + teste local em todas as 8 fases. *(Ambos resolvidos depois — ver
  "✅ ATUALIZAÇÃO (2026-08-21)" no topo deste documento.)*
- **Fase 8 — revisão pós-feedback (2026-08-13)**, construída em staging depois que o dono do produto
  usou o fluxo: (3a) `tipo_cobertura` saiu do modal do criador — nasce `null`, só o veterinário
  decide no Controle do Kanban; o gatilho do campo Receptora virou "fonte é Embrião" em vez de "tipo
  é TE". (3b) aba Acasalamentos virou uma tela "Tinder" — duas colunas (fontes × éguas do ciclo),
  clique-clique liga e abre o modal antigo só como confirmação (ciclo/obs/receptora); "+ Novo
  acasalamento" agora leva pra essa aba em vez de abrir modal direto. (4a) "Plantel disponível" foi
  fundida em "Garanhões e Coberturas" — uma aba só, leitura rápida no topo + edição num bloco
  colapsável. (4b) fonte "Cota" exige selecionar um animal cadastrado (não mais nome livre) e o
  percentual sugere a quantidade automaticamente (`120 × %`). (4c) "Direito de uso" ganhou checkbox
  "Recorrente" que persiste a fonte sozinha pro próximo ciclo — precisa da coluna nova
  `fontes_cobertura.recorrente`. (4d) confirmado que Animais nunca linkou Direito de uso/Cobertura,
  nada mudou aí. Detalhe completo em `docs/spec-reprodutivo-v4-saude-vet.md` (Fase 8).
  **✅ Migration aplicada e QA visual feita** logo em seguida (mesma sessão, com acesso ao MCP do
  Supabase e ao browser tooling): coluna `recorrente` confirmada nos 7 tenants + `public`; fluxo de
  match testado ponta a ponta (seleção fonte→égua, modal de confirmação sem `tipo_cobertura`, campo
  Receptora aparecendo só para fonte tipo Embrião, sugestão de quantidade por % de cota, checkbox
  Recorrente visível só para Direito de uso). **`staging` promovida pra `main`** no mesmo dia (PR #2,
  merge `fb578da`) — no caminho, um hotfix isolado de `main` (tabela `coberturas` renomeada, nunca
  chegou na staging) foi incorporado no merge sem perda de nada.
- **Fase 8b — correção de layout + remoção do flag "Receptora" do cadastro (2026-08-13)**: dono do
  produto reportou dois problemas no modal de novo/editar animal: (1) os campos "Castrado" e
  "Coberturas por ciclo (padrão)" ficavam desalinhados verticalmente (grid de 2 colunas — a célula
  do checkbox "Castrado" era mais curta que a do label+input ao lado, então o checkbox ficava
  "flutuando" no topo da linha); corrigido com `justify-content:flex-end` na célula do checkbox, pra
  alinhar pela base com o input vizinho. (2) Reavaliado (e removido) o checkbox "Receptora
  (transferência de embrião)" do cadastro do animal — decisão original da Fase 4 tratava receptora
  como atributo permanente do animal, mas na prática uma égua pode ser receptora só num ciclo
  específico e reprodutora normal (ou nada) nos demais; não faz sentido gravar isso como flag fixo.
  Removido `animais.receptora` de ambos os modais (novo/editar) e de toda validação de SBB associada;
  os pontos que antes filtravam candidatas a receptora por esse flag (`renderPlantelDisponivel`,
  select "Receptora" do modal de acasalamento) passaram a usar a regra real: qualquer fêmea "Na
  Cabanha" com SBB preenchido é candidata naquele ciclo, sem pré-marcação. Coluna `animais.receptora`
  no banco não foi removida (sem migration — ficou como campo morto, sempre `false` daqui pra frente,
  sem risco). Testado via servidor estático local + browser: checkbox some dos dois modais, layout do
  Castrado alinha com o input ao lado, Plantel/modal de acasalamento listam corretamente só fêmeas com
  SBB como candidatas a receptora (égua sem SBB fica de fora).

## 🗑️ Remoção completa da aba "Legado" do Reprodutivo (2026-08-19)
Fecha de vez o que o incidente de 2026-08-12 (abaixo) tinha deixado pendurado: a aba "Legado" existia só
porque a Cabanha Mãe de Deus (Luciano) tinha 4 gestações abertas presas no fluxo antigo (pré-Reprodutivo
v3), tabela `coberturas_arquivadas_legado`. Pedro pediu pra migrar essas 4 pro sistema vigente e remover a
funcionalidade inteira (frontend + banco).

- **Dados migrados** (query direta, não pela UI): as 4 gestações (NECAJÔ DONANA, INDIANA DO BUTIAZEIRO,
  TURUMBAMBA CHARRUA, ULTRA II CHARRUA × respectivos garanhões, datas de cobertura/diagnóstico
  preservadas, ciclo `25/26` real) viraram registros de verdade em `fontes_cobertura` (tipo `cobertura`,
  já esgotada) + `acasalamentos` (status `confirmado`) + `gestacoes` (status `gestando`) no schema
  `cab_mae_de_deus` — únicas linhas dessas 3 tabelas nesse tenant até então (schema "limpo", zero risco
  de colisão). Os 2 registros de fixture na cabanha de teste do Pedro (`cab_cabanha_pedro_teste`) foram
  descartados — dado de teste, não real.
- **Frontend**: removida a aba "Legado" (`gest-ativas`), os arrays `coberturas`/`coberturas2`, o modal
  `modal-cobertura-gest` e toda a cadeia de funções que só existia pra alimentá-lo (`renderGestacao()`,
  `salvarCoberturaGest()`, `editCobGest()`, `excluirCobertura()`, `_dbSalvarCobertura()`,
  `_dbExcluirCobertura()`, busca de padrillo via ABCCC duplicada). Pontos que **dependiam
  funcionalmente** do legado (não só exibiam) foram migrados pra ler da tabela `gestacoes` real em vez
  de simplesmente apagados: alerta de "parto próximo/atrasado" no dashboard, marcador de parto previsto
  no calendário de eventos (dia e detalhe do dia), contagem de éguas prenhas pra vacina obrigatória,
  histórico de "cruzamentos anteriores" no simulador de acasalamento, e a linha do tempo do animal
  (`_carregarLinhaTempo`, que buscava direto de `coberturas_arquivadas_legado` via REST).
- **Banco**: migration `docs/migrations/2026-08-19-remove-legado-coberturas.sql` — recria
  `carregar_dados_cabanha()` (RPC de bootstrap) sem a leitura da tabela legada, dropa
  `coberturas_arquivadas_legado` do template `public` e de todos os 7 schemas `cab_*` provisionados.
  **Achado no caminho**: `provisionar_schema_cabanha()` já não incluía essa tabela no array
  `v_tabelas` — cabanhas provisionadas recentemente já nasciam sem ela, então a RPC de provisionamento
  não precisou de mudança nenhuma. Confirmado via `pg_constraint` que nenhuma outra tabela tinha FK
  apontando pra ela — DROP direto, sem risco de cascade em dado de terceiros.
- Revisão de isolamento (`revisor-isolamento`) rodada — **aprovada**. Confirmou que o gate
  `tem_acesso_tenant()` continua intacto no início da RPC recriada, e que não sobrou nenhuma referência
  a `coberturas2`/`coberturas_arquivadas_legado` no `index.html`. Dois pontos que o subagente não
  conseguiu checar por falta de acesso a ferramentas de banco (policies/triggers referenciando a tabela
  em texto, e consistência dos 7 schemas pós-DROP) foram conferidos manualmente depois, via MCP — nada
  encontrado, os 7 schemas ficaram consistentes.
- Testado via servidor estático local + browser: gestação migrada aparece normalmente em "Gestações
  ativas" com progresso/trimestre calculados certos; Dashboard, ficha de detalhe do animal, calendário e
  Planejador renderizam sem erro; sem nenhum resquício textual ou funcional de "Legado" em lugar nenhum
  do app.

## 🐛 Garanhões "fantasma" em Acasalamentos + bug de seleção múltipla (2026-08-19)
Pedro reportou dois problemas na Cabanha Mãe de Deus, ciclo 26/27: (1) a aba Acasalamentos listava 3
garanhões que nunca foram cadastrados como animal da cabanha (LEOPARDO DA GAP SÃO PEDRO-TE, LAS GURIZAS
FOGONERO, ÍNDIO DO BOEIRO — padrillos externos usados via IA antes do Reprodutivo v3) como fonte "Próprio"
com 120 coberturas disponíveis; (2) na tela de match (duas colunas), clicar num garanhão específico
selecionava ele **e mais três outros ao mesmo tempo**.

- **Causa raiz do garanhão fantasma**: um `pg_cron` esquecido (`encerramento-ciclo-reproducao`, roda 1x/ano
  em 01/08) chamava `public.encerrar_ciclo_reproducao()`, que tinha um passo clonando QUALQUER fonte
  `proprio` do ciclo anterior pro novo só por nome/SBB baterem — sem checar se o garanhão continua
  cadastrado como animal. Redundante desde a Fase 2 do Reprodutivo v4 (2026-08-13), que já faz isso no
  client (`renderPlanejadorReprodutivo()`), validado contra o cadastro real de Animais — o passo do cron
  nunca foi desligado depois disso e ficou clonando fantasmas, ano após ano, silenciosamente. Verificado
  que só a Mãe de Deus tinha esse problema (as outras 6 cabanhas provisionadas estavam limpas).
- **Corrigido**: removido o passo de clonagem da função (migration
  `docs/migrations/2026-08-19-fix-cron-fontes-fantasma.sql`), mantendo os outros 3 passos legítimos
  (vencer fontes com saldo, cancelar acasalamentos travados, vencer cota/direito de uso expirados).
  Limpas as 7 linhas fantasma já existentes na Mãe de Deus (3 do ciclo 26/27 + 4 duplicatas antigas) —
  sem nenhum acasalamento vinculado a elas, DELETE direto e seguro.
- **Causa raiz da seleção múltipla**: `_acMatchSelecionarFonte()` comparava fontes por `db_id` — mas uma
  fonte "Próprio" recém-criada automaticamente ainda não tem `db_id` até o POST assíncrono terminar. Se
  várias fontes novas estivessem nesse limbo ao mesmo tempo (achado: o POST pra 4 garanhões reais da Mãe
  de Deus estava falhando silenciosamente — `_supa()` engole erro e retorna `null` sem avisar ninguém —
  então elas nunca conseguiam persistir e ficavam com `db_id` undefined pra sempre), clicar em qualquer
  uma delas selecionava TODAS ao mesmo tempo (`String(undefined) === String(undefined)`).
- **Corrigido**: nova função `_fonteKey(f)` dá uma identidade estável a cada fonte mesmo antes dela ter
  `db_id` (usa um id local gerado na hora, cacheado no próprio objeto). Além disso, `_acMatchSelecionarFonte()`
  agora **tenta persistir de novo** a fonte na hora do clique se ela ainda não tem `db_id` — e
  `renderPlanejadorReprodutivo()` também tenta de novo a cada render, em vez de desistir depois de uma
  falha. `abrirModalAcasalamentoMatch()` bloqueia com aviso claro se a fonte ainda não conseguiu persistir,
  em vez de deixar criar um acasalamento com id inválido.
- **Bônus**: a aba "Garanhões e Coberturas" não tinha filtro padrão nenhum — pra uma cabanha com anos de
  fontes acumuladas (vencidas, esgotadas, ciclos antigos), isso virava uma lista longa e confusa. Agora a
  primeira abertura da tela já entra filtrada no ciclo atual do Planejador + status "Ativa" (histórico
  continua um clique de distância, limpando os filtros).
- Revisão de isolamento (`revisor-isolamento`) rodada nessa mudança (toca uma função cross-tenant chamada
  por cron) — ver resultado abaixo se já tiver voltado quando você ler isto.
- Testado via servidor estático local + browser: reproduzido o bug de verdade (rede falhando de propósito
  nos 4 POSTs), confirmado que só 1 card fica marcado "Selecionado" por vez mesmo sem `db_id`; restaurada
  a rede, clicar de novo persiste e o `db_id` real assume; filtro padrão da aba Garanhões e Coberturas
  testado escondendo fonte de ciclo antigo e mostrando ao limpar os filtros.

## 🚨 Incidente: gestações "sumidas" em produção — Luciano/Mãe de Deus (2026-08-12)
Sócio reportou que as gestações da Cabanha Mãe de Deus não carregavam nem em `main` nem em `staging`.
Investigado a fundo — **dados nunca foram perdidos** (confirmado no banco: 4 gestações abertas intactas
na tabela `coberturas_arquivadas_legado`). Dois problemas distintos, corrigidos:
- **`main` (produção) — bug real, isolado do trabalho desta sessão**: o incidente de 02/08 (rename
  `coberturas` → `coberturas_arquivadas_legado`) só teve o fix aplicado no código que virou o `staging`.
  O `main` nunca foi corrigido e ficou consultando o nome antigo em 5 pontos (bootstrap de login,
  exclusão, timeline do animal, salvar cobertura) — a seção "Gestações ativas" ficava sempre vazia em
  produção, pra **todas as cabanhas**, desde então. Corrigido e deployado via
  [PR #1](https://github.com/mimba-app/cabanha/pull/1) (hotfix direto, sem passar pelo `staging`, por
  ser uma correção isolada de nome de tabela já validada lá).
- **`staging` — problema de visibilidade, não de dado**: a aba nova "Gestações" (Fase 5) é a mais
  visível e fica vazia pra quem ainda não migrou pro fluxo de Acasalamentos (caso do Luciano) — os
  dados reais dele ficam só na aba "Legado", que soava como histórico morto. Melhorado: o texto do
  aviso agora deixa claro que são gestações reais em aberto (não histórico), e a aba "Legado" ganhou um
  badge com a contagem de gestações abertas (`tab-btn-legado`, atualizado em `renderGestacao()`) pra não
  parecer vazia/descontinuada quando há dados reais pendentes de fechamento.
- **Fase 0** (banco): `animais.confirmado`, `fontes_cobertura.demerito`, corte de ciclo em julho, bônus
  `tem_rm`+`demerito` empilhado, `coberturas` arquivada (`coberturas_arquivadas_legado`), provisionamento
  corrigido. Aplicada em produção (banco compartilhado). Migration: `docs/migrations/2026-08-02-reprodutivo-fase0.sql`.
- **Fase 1**: campo "Confirmado" na aba Animais (aviso, não bloqueia).
- **Fase 2**: Planejador de ciclo — núcleo da tela nova, saldo por garanhão com aviso incisivo ao estourar.
- **Fase 3**: éguas de cria, receptora via SBB, cobertura comprada via SBB — remove o registro antigo de
  cobertura (achado: nem persistia no banco).
- **Fase 4**: marketplace entre cabanhas exposto no Planejador (já existia pronto no backend desde antes,
  só sem UI acessível — estava "escondido" em Saúde → Pendências).
- **Fase 5** (corte final): as duas páginas viraram uma só (menu "Gestação" removido). Achados corrigidos no
  caminho: alerta do Dashboard e card de "Reprodução" na ficha do animal só liam a tabela legada — ganharam
  versão paralela lendo a tabela `gestacoes` real; permissões de vet/cabanheiro atualizadas pra apontar pra
  `reprodutivo` em vez de `gestacao` (página que deixou de existir).
- Revisão de isolamento (`revisor-isolamento`) rodada cobrindo Fases 0-4 antes do corte final — achou e
  corrigiu 1 problema real: `_limparEstadoLocal()` não zerava os arrays de Reprodução/Marketplace, deixando
  uma janela de vazamento visual entre cabanhas ao trocar de tenant (não era bypass de RLS, era estado em
  memória). Corrigido.
- **Tudo testado só localmente** (servidor estático + sessão injetada), como em todas as fases anteriores —
  **falta QA de ponta a ponta em `mimba-hml.pages.dev` com login/dado reais** (planejar ciclo do zero,
  negociar cobertura entre duas cabanhas de teste de verdade) **antes de considerar pronto pra produção**.

## 🔑 `sangues_linhagem` lido no schema errado — cache nunca funcionava (2026-08-26)
Depois do fix do parser acima, Luciano reparou que a Análise de Sangues sempre buscava tudo de
novo na ABCCC ("22 buscados · 0 do banco" toda vez), mesmo já tendo salvo tudo antes. **Não era
bug de escrita** — a Edge Function grava certinho em `public.sangues_linhagem` (confirmado direto
no banco: 22 linhas, pai/mãe preenchidos, timestamp batendo). O bug era de **leitura**: os 3
lugares do app que consultam essa tabela usavam `_supa()` (helper genérico, sempre manda
`Accept-Profile`/`Content-Profile` = schema da cabanha, tipo `cab_mae_de_deus`) em vez de
`_supaPub()` (helper que já existe no código, feito exatamente pra apontar pro `public`). Como
`sangues_linhagem` também está provisionada (vazia) em cada schema de tenant, toda leitura via
`_supa()` batia numa tabela vazia e sempre achava "nada em cache".

**Achado mais sério que a tela de Sangues em si**: o mesmo bug estava em mais 2 lugares —
`_renderSimulacaoAcasalamento` (checagem de meio-irmãos/IC estimado na tela de acasalamento) e
`_jaConsanguinidade` (alimenta o ranking do Conselho de cruzamento). Os dois caíam sempre no
texto padrão "Sem dados suficientes para verificar consanguinidade" mesmo quando o dado da
ABCCC já estava salvo — a checagem de parentesco de 2º/3º grau **nunca rodava de verdade em
produção**, silenciosamente. Corrigido nos 3 pontos (troca `_supa`→`_supaPub`), commit a seguir.

**Parte 2 — decisão estratégica, ainda pro Pedro avaliar** (não fiz nada aqui, só documentando):
- A lógica de IC estimado que já existe em `_jaConsanguinidade`/`_renderSimulacaoAcasalamento`
  (ancestrais comuns por geração, peso `0.5^(gen_egua+gen_gar+1)`) é essencialmente um protótipo
  funcional do que a spec de Inteligência de Cruzamentos (`analisar_cruzamento` no Mimba Lab) quer
  formalizar. Vale decidir se isso converge pra um lugar só (Lab) ou continua duplicado
  (versão rápida local aqui + versão rica no Lab).
- O parser da `analise-sangues` (agora v15, testado contra HTML real) pode ser reaproveitado pela
  Fase C do backfill de genealogia do Lab (animais que a resolução por nome não alcançou), em vez
  de escrever um scraper novo do zero — ver ADR 0009.

## 🩸 Análise de Sangues — parser da ABCCC estava sistematicamente errado (2026-08-26)
Luciano reportou "Principais Pais"/"Avós Maternos" sempre vazios e "undefined" em Prefixos.
Investigação achou 4 bugs reais na Edge Function `analise-sangues` (agora v15), todos
confirmados contra HTML real da árvore de 5 gerações (usuário conseguiu extrair via
"Inspecionar elemento" → Copy outerHTML, já que a página é carregada num popup/fancybox, então
Ctrl+U não funciona — reenvia o formulário de busca em vez de mostrar o HTML da árvore):

1. **Regressão de nome de campo no frontend** (`index.html`) — backend retorna `topPais`/
   `topAvosPat`/`topAvosMat` (plural), frontend lia `topPai`/`topAvoPat`/`topAvoMat` (singular).
   Corrigido, commit `5b80119`.
2. **"undefined" nos Prefixos** — `topPrefixo` não tinha o alias `prefixo` que `topAfixo` recebe;
   frontend lia campo inexistente. Corrigido no mesmo commit.
3. **Geração sempre errada** (achado maior, só apareceu depois que os 2 acima já tinham sido
   corrigidos e o usuário reparou que "avô paterno" mostrava o avô *do* avô, não o avô certo) —
   o parser decidia a geração pela PRIMEIRA largura de coluna >10px da linha, mas a estrutura
   real da tabela ABCCC tem várias células de indentação por linha, e a primeira isolada não
   identifica geração de forma confiável (duas gerações diferentes podem compartilhar a mesma
   primeira largura). Corrigido pra somar TODAS as larguras da linha — calibrado e validado
   contra uma árvore real confirmada manualmente pelo usuário (50→ger.1, 100→ger.2, 200→ger.3,
   300→ger.4), consistente em 2 subárvores independentes (paterna e materna).
4. **Metade dos ancestrais descartada silenciosamente** — a tabela real usa
   `bgcolor="#CCCCCC"` pra ancestral MACHO e `bgcolor="#FFFFCC"` pra ancestral FÊMEA; o regex de
   extração só reconhecia CCCCCC, jogando fora toda ancestral fêmea da árvore — incluindo a
   própria mãe do animal. Isso explica por que `mae`/`avo_materno` vinham sempre nulos mesmo
   depois do fix de geração. Corrigido pra aceitar os dois. Também corrigido o regex que separa
   lado paterno/materno (procurava a marca da linha do próprio animal, mas o padrão nunca batia
   contra a estrutura real — caía sempre no fallback ingênuo de cortar a página na metade dos
   caracteres, o que não corresponde à divisão real da árvore).
- **Validado**: testado em Node contra o HTML real (não simulado) do animal Barulho da Mãe de
  Deus (B672331) — os 4 campos (pai, avô paterno, mãe, avô materno) batem exatamente com o que
  o usuário confirmou manualmente pelo print da árvore. Antes do fix: só 15/30 ancestrais reais
  capturados (só os machos); depois: 30/30.
- **Cache limpo**: as 41 linhas em `public.sangues_linhagem` (cache de 30 dias) tinham sido
  salvas pela versão quebrada — deletadas as que tinham `pai is null and mae is null and erro is
  null`, forçando rebusca automática com o parser corrigido no próximo "Analisar manada" de cada
  cabanha (sem precisar ninguém lembrar de clicar "Rebuscar todos"). Schemas de tenant não
  tinham cópia (frontend nunca passa `tenant_schema` pra função hoje).
- **Edge Function `analise-sangues` está em v15** agora (era v14) — se for tocar nela de novo,
  puxar a versão atual antes de editar, mesma disciplina do `index.html`.

## 🧠 Agente Mimba — caso de uso 3 (ABCCC) destravado pro lançamento (2026-08-25)

### ⚠️ Achado ao testar com créditos carregados (2026-08-28): primeiro teste bateu "limite atingido (0)"
Não era bug — é o novo modelo de preço (Potro/Arreio com e sem IA, Manada) funcionando como
configurado. A Cabanha Mãe de Deus (usada pros testes) estava no plano **Arreio** simples, que
tem `agente_ia:false` e `cota_ia_mensal:0` de propósito nos `features`. Confirmado os 5 planos:

| Plano | Tem IA | Cota mensal |
|---|---|---|
| Arreio | não | 0 |
| Potro | não | 0 |
| Arreio + Agente Mimba | sim | 900 |
| Potro + Agente Mimba | sim | 600 |
| Manada | sim | 1500 |

Trocado `tenants.plano_id` da Cabanha Mãe de Deus pra **Manada** (decisão do Luciano) — direto no
banco, sem passar pelo fluxo de checkout/Asaas (é troca de teste, não assinatura real).

**Achado secundário, não bloqueante**: `uso_ia_mensal.contagem` já estava em 4 pra essa cabanha
mesmo com as tentativas anteriores tendo sido *bloqueadas* pela cota zerada — sugere que o
contador incrementa antes (ou independente) da checagem de cota, não só em mensagens que de fato
chegam a chamar o modelo. Não trava nada agora (cota nova é 1500), mas vale o Pedro conferir a
ordem de operações na Edge Function se algum dia isso importar (ex.: cobrança por uso).

Founder redefiniu o escopo: o Agente Mimba deve ter, desde o lançamento, "dois cérebros" —
contexto completo da cabanha + inteligência estatística da raça (Mimba Lab), casando os dois no
mesmo raciocínio. Isso tira o caso de uso 3 do "adiado" que a ADR 0007 tinha decidido.

- **`docs/adr/0009-especialista-abccc-destravado-sincronizacao-periodica.md`** (renumerada de 0008
  em 2026-08-26 — colidia com `0008-perfil-pessoal-do-usuario-em-tabela-global.md`) — decisão + a
  arquitetura que preserva a invariante da ADR 0010 (nenhuma requisição de cabanha toca o Lab —
  ADR trazida da branch `recuperacao/area-dados-fora-de-producao` pra `main` na mesma ocasião,
  renumerada de 0005 pra não colidir com `0005-empacotamento-mobile-em-3-fases.md`):
  em vez de proxy ao vivo, um job periódico materializa um resumo estatístico do Lab **pra dentro
  do banco de produção** (tabela nova `abccc_estatisticas_animal`, ainda a criar); o agente
  consulta essa tabela como dado normal, cruzando com o SBB dos animais da própria cabanha. O
  cruzamento hipotético ao vivo (par nunca testado) continua fora de escopo.
- **`docs/agente-ia-base-conhecimento-abccc.md`** — terminologia de mercado (linha alta/baixa,
  "vem a ser", irmão inteiro) e regras de narrativa (silêncio na ausência de referência, ponte pra
  ancestral distante, linhagens em alta como dado derivado, não lista fixa) — pronto pra virar
  system prompt do agente e insumo pro que a tabela sincronizada precisa carregar.
- **Achado que destravou a decisão**: cobertura de genealogia no Lab subiu de 836/26.000 SBBs
  (3%, número que embasava o adiamento da ADR 0007) pra **18.391/26.593 (69%) de pai** e
  **7.286/26.593 (27%) de mãe**, via backfill por casamento de nome dentro da própria base do Lab
  (função `public.backfill_genealogia_por_nome()`, projeto `njynlsugmvtuvcczmuld`) — sem nenhuma
  chamada externa à ABCCC.
- **Correção (2026-08-26)**: achado anterior dizia que "Doma de Ouro" não existia na base — na
  verdade está carregada (336 linhas, `tier=2`, confirmado ao desenhar o schema abaixo). As 3
  provas principais do lançamento já têm dado no Lab; deixa de ser um risco em aberto.
- **Schema desenhado (2026-08-26)**: `docs/migrations/2026-08-26-agente-caso-uso3-schema-abccc.sql`
  — `abccc_estatisticas_animal` (resumo por SBB: linha alta/baixa, participações com peso,
  finalistas produzidos, árvore crua de 5 gerações) + `abccc_linhagens_em_alta` (ranking
  recalculado a cada sync). Nenhuma das duas entra na lista hardcoded de `provisionar_schema_cabanha()`
  — confirmado antes de escrever a migration, não vaza pra schemas `cab_*`. Falta aplicar (depois
  do `revisor-isolamento`), o job de sync e as RPCs `abccc_*`.
- ✅ **Concluído (2026-08-27)**: job de sincronização deployado, testado (29.282 animais, ranking
  batendo com os números validados) e agendado via `pg_cron`/`pg_net`/Vault (diário, 06:00 UTC).
  RPCs `abccc_resumo_animal`/`abccc_ranking_linhagens` aplicadas, revisadas
  (`revisor-isolamento`, aprovado) e conectadas ao `agente-ia` (v7) — system prompt reescrito com
  a terminologia/regras da base de conhecimento ABCCC. FAB do chat reativado no `index.html`
  (estava escondido a pedido do Luciano desde 2026-08-25).
  ✅ **Resolvido (2026-08-28)**: Luciano carregou US$ 20 de crédito na organização Anthropic
  (confirmado via screenshot do console). O bloqueio que restava (`ANTHROPIC_API_KEY` configurada
  mas sem crédito) está fechado — falta só um teste ponta a ponta numa conversa real pra confirmar
  o comportamento do modelo em produção, não mais nenhum bloqueio de configuração/pagamento.

### 🐛 Bug real achado testando com crédito carregado (2026-08-28): tool_use com campo extra
Primeira pergunta que precisou de ferramenta deu `Claude API 400: messages.1.content.1.tool_use.
input_json: Extra inputs are not permitted`. Causa: ao montar o histórico depois de consumir o
streaming SSE, o código fazia `{ ...b, input: JSON.parse(b.input_json||'{}') }` — isso **espalha**
`b` inteiro (que ainda carrega `input_json`, o acumulador temporário de JSON parcial usado durante
o streaming) e só *adiciona* `input` por cima, sem remover o campo velho. O bloco reenviado pra API
na rodada seguinte ficava com os dois campos ao mesmo tempo, e a API rejeita.

Travava **qualquer pergunta que precisasse de 2+ rodadas de ferramenta** — ou seja, quase toda
pergunta útil (a primeira rodada nunca falhava, porque o histórico contaminado só era reenviado
na rodada seguinte). Corrigido (`agente-ia` v8, `supabase/functions/agente-ia/index.ts`): agora
desestrutura `b` removendo `input_json` explicitamente antes de montar o bloco final. Testado
isoladamente (sem precisar de rede) simulando os eventos SSE reais da Anthropic — reproduziu o bug
exato na versão antiga e confirmou o schema limpo (`id`/`input`/`name`/`type`, nada a mais) na
versão corrigida.

## 🥕 Nutrição — refactor implementado (2026-08-21)
Luciano reportou 3 problemas reais, confirmados lendo o código antes de propor solução: projeto
nutricional não persistia no banco (o módulo inteiro rodava em memória — `nutProj` era recriado
vazio a cada load, zero chamadas ao Supabase em toda a seção de Nutrição), não dava pra criar
novos templates (`NUT_TEMPLATES` era uma constante JS fixa de 7 chaves), e não dava pra ter dois
itens do mesmo tipo num template/projeto (ração/aveia/alfafa/verde/sal eram campos únicos, não
listas — só suplementos já era array). Spec completa em `docs/spec-nutricao-refactor.md`.

**Pedro assumiu o projeto do app mobile (Android/iOS); esta frente passou a ser trabalhada
direto por mim (Claude) com o Luciano**, fora do padrão usual "spec pro Pedro construir" — por
isso já foi direto pra implementação, banco e frontend.

- **Schema** (`docs/migrations/2026-08-21-nutricao-refactor-fase0.sql`, aplicada via MCP):
  `nutricao_templates`/`nutricao_template_itens` (templates configuráveis, CRUD real) +
  `nutricao_projetos`/`nutricao_projeto_itens` (projeto por animal, histórico real via
  status ativo/finalizado, índice único parcial garantindo no máximo 1 ativo por animal).
  Suplementos deixaram de ser um array à parte — viram só mais um `tipo` de item.
  ⚠️ **Achado no caminho**: já existiam tabelas `nutricao_itens`/`nutricao_projetos` de uma
  tentativa anterior abandonada (formato incompleto, nunca lida pelo frontend — mesmo espírito
  do achado de "garanhões fantasma"). 17 linhas órfãs na Mãe de Deus (todas "Aveia" default,
  datadas de março) foram migradas pra estrutura nova antes de derrubar as tabelas velhas — nada
  perdido. Os 7 templates que eram a constante JS `NUT_TEMPLATES` foram semeados como dados reais
  em todos os 8 tenants, valores idênticos aos que já estavam calibrados.
- **`provisionar_schema_cabanha`** e **`carregar_dados_cabanha`** (bootstrap de login)
  atualizadas — cabanhas novas já nascem com os 7 templates seedados; o bootstrap já devolve
  `nutricao_templates`/`nutricao_projetos` com itens aninhados.
- **Frontend** (`index.html`): bloco inteiro de Nutrição reescrito — persistência real via
  `_supa()` (mesmo padrão de `tratamentos`), CRUD completo de templates (criar/editar/excluir,
  modal dinâmico), listas de itens em vez de campos fixos (qualquer quantidade de itens por
  categoria, incluindo dois tipos de ração no mesmo animal), Lista de Compras generalizada pra
  agrupar por `(tipo, produto)` em vez de chaves fixas.
- **Testado** com harness funcional (jsdom + vm, simulando o bootstrap real e as respostas do
  Supabase) — 10 cenários cobrindo aplicar template, adicionar segundo item do mesmo tipo,
  suplemento, lista de compras com produtos separados, e criar template novo do zero. Todos
  passaram. **Não testado ainda em navegador real com sessão/login de verdade** — só a lógica
  client-side isolada. Sintaxe do arquivo inteiro validada com `node --check`, sem referências
  órfãs aos identificadores antigos (`NUT_TEMPLATES`, `nutTemplatesCustom`, `.suplementos` etc.)

## 🚀 Meta V1.5 até 29/08/2026 (definida com o Pedro em 2026-08-02)
Plano completo em `docs/roadmap-v15.md`. Origem: `docs/roadmap-gestao-crioulo.pdf` (roadmap geral), marco
"V1.5 · Agosto 2026" — 6 itens: personalização de cores, trial automático 30d, painel admin da plataforma,
dashboard de métricas de uso, portal do cliente, relatórios em PDF. Nenhum começado ainda. Fases 0-1
(promover staging→main + personalização de cores) são a base de baixo risco pra começar; Fase 2 (trial)
tem decisão de produto já tomada (cartão tokenizado, cobra só no dia 30) mas falta decidir o que fazer se a
cobrança falhar. Risco de prazo sinalizado no documento — 27 dias é apertado pra tudo isso sozinho.

## 🎯 Próximos passos combinados (2026-08-02)
1. **Revisão do módulo de Reprodução Equina com olhar veterinário** — o Pedro vai mandar uma spec completa
   (revisão do que já foi construído nas 8 fases, com correções/ajustes do ponto de vista clínico). Aguardando
   o documento antes de agir.
2. **Fluxo de cadastro do admin inicial (dono da cabanha) não pode depender só do código expirável** — achado
   direto do incidente do Thiago: pra um usuário convidado *depois* por um admin já ativo, o fluxo atual
   funciona (se o código expirar, o admin reenvia pela aba Usuários — item v7 acima). Mas o **admin
   inicial/dono**, criado no provisionamento self-serve (`provisionar-cabanha` → `enviar-acesso`), não tem
   ninguém "de dentro" da cabanha pra reenviar se o código dele expirar antes do primeiro login — hoje isso só
   se resolve com intervenção manual nossa via banco (exatamente o que foi feito pro Thiago). Precisa de um
   fluxo diferente pra esse caso específico — ex.: link de recuperação autosserviço, expiração maior só pra
   esse primeiro convite, ou uma tela de "reenviar meu próprio acesso" que não dependa de já estar logado.
   Ainda não desenhado — próxima frente de trabalho.

## Arquitetura (o que existe e funciona)
- **App:** `index.html` único, sem framework/bundler. **Produção:** GitHub Pages, branch `main`, `app.mimba.com.br`.
  **Staging:** Cloudflare Pages, branch `staging`, `mimba-hml.pages.dev` — **mesmo banco Supabase da produção**
  (staging isola só código, não dados).
- **Backend:** Supabase `fmjfvfufkqswweyasjyp` (Postgres + Edge Functions Deno + Auth). anon key pública.
- **Multi-tenant por schema:** cada cabanha = `cab_<slug>`. `public` é o **template**. Control-plane em `public`.
- **Login identity-first:** Supabase Auth (email+senha, JWT). `tenant_memberships` (identidade → N cabanhas +
  perfil). `minhas_cabanhas()` → 1 entra direto, N abre seletor (agora filtrado por `ambiente_teste`, ver acima).
- **Isolamento (RLS):** policies só `authenticated` via `tem_acesso_tenant(<tenant_id>)` em `(select ...)`. `anon`
  sem acesso aos schemas de cabanha. *(Mas ver achado de segurança acima — escrita não é restrita por perfil.)*

## Fluxo de contratação (self-serve) — construído e testado no sandbox
```
mimba.com.br/assinar (form) → Edge Function criar-checkout → Asaas (cliente + assinatura mensal)
   → insere signup → devolve invoiceUrl (+ callback p/ /obrigado)
cliente paga (Asaas) → redireciona p/ mimba.com.br/obrigado
Asaas → asaas-webhook (valida token) → provisionar-cabanha → cabanha isolada → enviar-acesso   ✅ testado ponta a ponta
```
`enviar-acesso` também recebeu o fix "só código, sem link" (mesmo padrão do `convidar-usuario`).

## Edge Functions (produção — mesmo projeto Supabase pra staging e prod)
- `criar-checkout` (verify_jwt=false) — form → Asaas → signup → invoiceUrl.
- `asaas-webhook` (verify_jwt=false) — valida token; PAYMENT_CONFIRMED/RECEIVED → `provisionar-cabanha` → `enviar-acesso`.
- `provisionar-cabanha` (verify_jwt=false, exige `Bearer service_role`).
- `enviar-acesso` (verify_jwt=false, exige `Bearer service_role`) — v7, código sem link.
- `convidar-usuario` (verify_jwt=**true**) — v7, ver ciclo completo acima.
- `buscar-abccc`, `analise-sangues` (features do app).
- RPCs principais: `provisionar_schema_cabanha`, `minhas_cabanhas` (com `ambiente_teste`), `tem_acesso_tenant`,
  `buscar_auth_user_por_email`, `vincular_admin_cabanha`, `carregar_dados_cabanha`, `atualizar_tenant`,
  `vincular_usuario_cabanha` (idempotente), `revogar_acesso_usuario`, `usuarios_pendentes_tenant`.

## Secrets (nomes; valores só no Supabase)
`SB_MGMT_TOKEN`, `ASAAS_WEBHOOK_TOKEN`, `ASAAS_API_KEY` (⚠️ `$` no início, sandbox agora), `ASAAS_BASE_URL`
(opcional), `RESEND_API_KEY` (+ opcionais `RESEND_FROM`/`RESEND_REPLY_TO`/`APP_URL`/`ACCESS_REDIRECT_TO`).

## Estado por frente
| Frente | Estado |
|---|---|
| Login identity-first + isolamento + sessão persistente | ✅ no ar em produção (promovido em `097dbce`) |
| Provisionamento automático | ✅ testado |
| E-mail de acesso / convite de usuário (código, sem link, reenvio) | ✅ v7, testado com caso real (Thiago) |
| Checkout self-serve (sandbox) | ✅ testado ponta a ponta |
| ROADMAP Prioridades 1-6 + Reprodução Equina v2 | ✅ concluídas — **em produção** (promovido em `097dbce`, ver atualização 2026-08-21 no topo) |
| Redesign visual da casca | ✅ implementado, ⏳ aguardando validação do sócio |
| Segregação staging/produção (`ambiente_teste`) | ✅ construído, ⚠️ Santa Adelina marcada teste temporariamente |
| RLS permissiva por perfil (achado de segurança) | ❌ registrado, não corrigido |
| **Promover `staging` → `main`** | ✅ feito (`097dbce`, verificado 2026-08-21 direto no código) — Santa Adelina segue `ambiente_teste=true`, decisão de reverter pendente |
| Rename repo `cabanha`→`mimba` | ⏳ adiado |
| Cutover Asaas p/ produção | ❌ trocar `ASAAS_API_KEY`/`ASAAS_BASE_URL` + domínio + redeploy |
| Rate-limit no `criar-checkout`/`criar-checkout-trial` | ✅ 8/60min e 5/60min por IP (2026-08-02) — reCAPTCHA ainda não |
| Refactor do index.html | ❌ futuro (precisa de um ADR novo com o `arquiteto` — `0004` já foi usado pra captura de cartão do trial) |

## Gotchas (já mordido)
- **Trocou secret de Edge Function → redeploy a função** (cache do valor antigo).
- **Secret com `$`/especial via CLI → aspas simples**, ou use o painel.
- `verify_jwt` **false** em webhook/funções públicas; **true** só na `convidar-usuario`.
- `perfil` é enum `adm/vet/cab`. `sangues_linhagem.total_anc` é gerada. `tenants`: email_admin/asaas_customer_id não únicos.
- MCP do Supabase tem **acesso completo** (não é read-only) — writes via `apply_migration`/`execute_sql` direto.
- Schema `public` tem `ALTER DEFAULT PRIVILEGES` do Supabase que concede `anon`/`PUBLIC` automaticamente em toda
  **tabela e função** nova criada por `postgres` — sempre `revoke ... from anon, public` explícito depois de criar.
- **Link e código de acesso (Auth `type=recovery`) compartilham o mesmo token** — nunca mandar os dois, só o código.
- Named-property shadowing do HTML: `<input name="submit">` sobrescreve `form.submit()` — use
  `HTMLFormElement.prototype.submit.call(form)`.
- CORS preflight custa caro em request→request diferente de endpoint: prefira 1 RPC que devolve tudo a N chamadas
  REST separadas.
- **`ambiente_teste` esconde cabanhas reais de quem testa via staging** — inclusive de admins/suporte. Ver seção
  "Segregação de ambiente" acima antes de usar staging pra investigar algo de um cliente real.
- **`auth.users` sem FK formal de `public`/schemas de tenant** — apagar uma linha de `auth.users` não cascateia
  pra `tenant_memberships` nem `<schema>.usuarios`; limpar manualmente se algum dia for necessário excluir conta.

## Repos e domínios
- App: `mimba-app/cabanha` → **app.mimba.com.br** (main) / **mimba-hml.pages.dev** (staging, Cloudflare Pages).
- Landing: `mimba-app/mimba-landing` → **mimba.com.br**.
- Deploy do app (main): push → GitHub Pages + `versionar.yml`. Deploy staging: push na branch `staging` → Cloudflare Pages automático.

Memória do projeto (auto-carrega): `MEMORY.md` + arquivos.
