# Mimba — empacotamento mobile (Capacitor)

Fase 1 do plano registrado em `docs/adr/0005-empacotamento-mobile-em-3-fases.md`: empacotar
o `index.html` da raiz do repo com [Capacitor](https://capacitorjs.com) pra publicar nas lojas
sem reescrever o app.

**Isolamento:** esta pasta tem seu próprio `npm`/`package.json`/build step — o único lugar do
repo com isso. O frontend web (`index.html`, GitHub Pages) continua exatamente como antes, sem
framework/bundler. Ver `CLAUDE.md`.

## Como o código chega aqui

`index.html` da raiz é a **única fonte de verdade**. `mobile/www/` e
`mobile/ios/App/App/public/` são cópias geradas — nunca editadas direto, nunca commitadas
(estão no `.gitignore`). Rode a sincronização depois de qualquer mudança no `index.html` da
raiz, ou depois de clonar o repo antes de abrir o Xcode:

```bash
cd mobile
npm install       # só na primeira vez / quando as deps do Capacitor mudarem
npm run sync:ios  # copia ../index.html -> www/, depois roda `cap sync ios`
```

## Rodar no simulador iOS

Precisa de Xcode com a plataforma iOS Simulator instalada. Não precisa de CocoaPods — o
projeto usa Swift Package Manager para as dependências do Capacitor.

```bash
open ios/App/App.xcodeproj
# ▶ Run, com um simulador selecionado
```

Ou via linha de comando (`xcodebuild`), buildando o scheme `App` do
`ios/App/App.xcodeproj` para `platform=iOS Simulator`.

## Bundle ID

`br.com.mimba.app` (definido em `capacitor.config.json`) — reverso do domínio real
(mimba.com.br). Isso fica praticamente permanente depois de publicado nas lojas; não trocar
sem necessidade real.

## Ícone e splash

Gerados a partir de `resources/icon.png` (1024×1024) e `resources/splash.png` (2732×2732) —
o monograma "M." da marca (branco, ponto dourado `#E8C567`, fundo gradiente verde
`#4F6B2E → #33461C`, mesma paleta/tipografia — Manrope ExtraBold — do resto do app) via
[`@capacitor/assets`](https://github.com/ionic-team/capacitor-assets):

```bash
cd mobile
npx @capacitor/assets generate --ios --iconBackgroundColor '#4F6B2E' --iconBackgroundColorDark '#33461C' --splashBackgroundColor '#4F6B2E' --splashBackgroundColorDark '#33461C'
```

Rodar de novo sempre que `resources/icon.png`/`resources/splash.png` mudarem — sobrescreve
`ios/App/App/Assets.xcassets/AppIcon.appiconset` e `Splash.imageset` direto.

## Fora de escopo desta fase (ver ADR 0005)

- **Android** — ainda não adicionado (não tem Android SDK configurado neste ambiente). Pra
  adicionar depois: `npx cap add android` dentro de `mobile/`, com Android Studio + SDK
  instalados.
- **Offline real, push nativo, deep link do fluxo de recuperação de senha** — ficam pra Fase 2
  (detecção simples de conectividade) e Fase 3 (app nativo de verdade) do ADR 0005.
- **Publicação nas lojas** (App Store Connect, certificados, provisioning) — passo seguinte,
  depois de validar o app rodando localmente.
