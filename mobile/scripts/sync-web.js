// Copia o index.html da raiz do repo (fonte única de verdade do app web, sem
// framework/bundler — ver CLAUDE.md e docs/adr/0005-empacotamento-mobile-em-3-fases.md)
// para mobile/www/, que é o que o Capacitor empacota no app nativo. Nunca editar
// mobile/www/index.html diretamente — é gerado, não é uma segunda cópia do código.
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'index.html');
const destDir = path.join(__dirname, '..', 'www');
const dest = path.join(destDir, 'index.html');

fs.mkdirSync(destDir, { recursive: true });
fs.copyFileSync(src, dest);
console.log(`sync-web: copiado ${src} -> ${dest}`);
