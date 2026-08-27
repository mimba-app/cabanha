// Backfill de genealogia de 5 gerações (ABCCC) para o Mimba Lab.
//
// Reimplementação da MESMA lógica das edge functions de produção
// `buscar-abccc` + `analise-sangues` (puxadas via MCP do Supabase em 2026-08-25),
// rodando como script standalone contra o projeto ANALÍTICO (Lab), nunca contra
// produção — os dois projetos são isolados de propósito (ver
// docs/handoff-mimba-lab-cruzamentos.md). Por isso este script fala direto com a
// ABCCC (site público) e com a REST API do Lab via service_role key, sem passar
// pelas edge functions de produção.
//
// Uso:
//   LAB_SUPABASE_URL=https://njynlsugmvtuvcczmuld.supabase.co \
//   LAB_SERVICE_ROLE_KEY=xxx \
//   node dados/genealogia/scraper-5geracoes.mjs sbbs.json [--force]
//
// sbbs.json = array de strings SBB, ex: ["B012345", "B067890"]
//
// Delay: no MÍNIMO 1,5s entre QUALQUER requisição à ABCCC (não só entre animais —
// cada animal já usa 2 chamadas). Pedido explícito do Pedro pra não sobrecarregar
// o site deles; mais conservador que os 600ms usados hoje em produção
// (`analise-sangues`), de propósito, porque aqui é carga em lote de milhares de
// SBBs, não uma consulta pontual de usuário.

import { readFileSync } from 'node:fs';

const ABCCC_BASE = 'https://www.cavalocrioulo.org.br/pesquisa';
const ABCCC_HDR = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  Referer: ABCCC_BASE + '/pesquisas.php',
};
const DELAY_MS = 1500;
// Se a ABCCC começar a responder devagar, aumentamos o delay entre chamadas
// (proteção contra sobrecarregar o site deles e contra estourar nosso próprio
// timeout de 15s em cascata). Volta ao normal quando as respostas normalizam.
const RESP_LENTA_MS = 5000;
const RESP_MUITO_LENTA_MS = 10000;
const DELAY_EXTRA_LENTO_MS = 1500;
const DELAY_EXTRA_MUITO_LENTO_MS = 4000;
const JANELA_TEMPOS = 20;
const HEARTBEAT_A_CADA = 20;

// Circuito de proteção contra bloqueio temporário da ABCCC (observado em
// 2026-08-26: depois de ~2h de requisições contínuas, a ABCCC passou a
// responder "não encontrado" / árvore vazia pra animais que existem de
// verdade — sumiu sozinho depois de um tempo. Em vez de continuar batendo
// nela por horas só pra acumular erro, detectamos a sequência suspeita e
// pausamos, escalando a pausa se o padrão voltar a se repetir logo depois.
const STREAK_SUSPEITA_LIMITE = 3;
const PAUSAS_ESCALONADAS_MS = [5 * 60_000, 15 * 60_000, 30 * 60_000, 60 * 60_000];
const SUCESSOS_PRA_RESETAR_ESCALONAMENTO = 30;

const LAB_URL = process.env.LAB_SUPABASE_URL;
const LAB_KEY = process.env.LAB_SERVICE_ROLE_KEY;
if (!LAB_URL || !LAB_KEY) {
  console.error('Faltam LAB_SUPABASE_URL / LAB_SERVICE_ROLE_KEY no ambiente. Não hardcode a chave — passe por env var.');
  process.exit(1);
}

const [, , arquivoSbbs, ...flags] = process.argv;
const force = flags.includes('--force');
if (!arquivoSbbs) {
  console.error('Uso: node scraper-5geracoes.mjs sbbs.json [--force]');
  process.exit(1);
}

const sbbs = JSON.parse(readFileSync(arquivoSbbs, 'utf8'))
  .map((s) => String(s).trim().toUpperCase())
  .filter(Boolean);

let ultimaChamadaAbccc = 0;
const temposResposta = [];
let delayAtualMs = DELAY_MS;

function registrarTempoResposta(ms) {
  temposResposta.push(ms);
  if (temposResposta.length > JANELA_TEMPOS) temposResposta.shift();
  const media = temposResposta.reduce((a, b) => a + b, 0) / temposResposta.length;

  let novoDelay = DELAY_MS;
  if (media >= RESP_MUITO_LENTA_MS) novoDelay = DELAY_MS + DELAY_EXTRA_MUITO_LENTO_MS;
  else if (media >= RESP_LENTA_MS) novoDelay = DELAY_MS + DELAY_EXTRA_LENTO_MS;

  if (novoDelay !== delayAtualMs) {
    if (novoDelay > delayAtualMs) {
      console.log(`\n⚠ ABCCC respondendo devagar (média ${Math.round(media)}ms nas últimas ${temposResposta.length} chamadas) — aumentando delay para ${novoDelay}ms.`);
    } else {
      console.log(`\n✓ ABCCC normalizou (média ${Math.round(media)}ms) — voltando ao delay padrão de ${novoDelay}ms.`);
    }
    delayAtualMs = novoDelay;
  }
}

async function esperarDelay() {
  const espera = ultimaChamadaAbccc + delayAtualMs - Date.now();
  if (espera > 0) await new Promise((r) => setTimeout(r, espera));
  ultimaChamadaAbccc = Date.now();
}

async function fetchAbccc(url, opts) {
  await esperarDelay();
  const inicio = Date.now();
  try {
    const res = await fetch(url, opts);
    registrarTempoResposta(Date.now() - inicio);
    return res;
  } catch (e) {
    // timeout ou falha de rede também conta como "resposta lenta" pra fins de backoff
    registrarTempoResposta(Math.max(Date.now() - inicio, RESP_MUITO_LENTA_MS));
    throw e;
  }
}

// ── Parada segura (Ctrl+C) ───────────────────────────────────────────────
// Cada animal já é gravado individualmente (upsert) antes de passar pro
// próximo, então interromper não desfaz nada do que já foi processado.
// No primeiro Ctrl+C, terminamos o animal em andamento e paramos com calma
// (resumo final + refresh de animal_posicoes). No segundo Ctrl+C, sai na hora.
let parando = false;
process.on('SIGINT', () => {
  if (parando) {
    console.log('\nSegundo Ctrl+C — saindo imediatamente (sem resumo final).');
    process.exit(130);
  }
  parando = true;
  console.log('\n\n⏸ Parada solicitada (Ctrl+C). Terminando o animal atual e parando com segurança...');
  console.log('   (rode o script de novo com o mesmo sbbs.json pra continuar de onde parou — animais já gravados são pulados automaticamente)');
});

// Sleep que verifica `parando` a cada 5s, pra um Ctrl+C durante uma pausa
// longa (circuito de proteção) não precisar esperar a pausa toda terminar.
async function dormirInterrompivel(ms) {
  const PASSO_MS = 5000;
  let restante = ms;
  while (restante > 0 && !parando) {
    const passo = Math.min(PASSO_MS, restante);
    await new Promise((r) => setTimeout(r, passo));
    restante -= passo;
  }
}

// ── HTML helpers (copiados das edge functions de produção) ──────────────────
function strip(s) {
  return s
    .replace(/&ccedil;/gi, 'ç').replace(/&atilde;/gi, 'ã').replace(/&otilde;/gi, 'õ')
    .replace(/&oacute;/gi, 'ó').replace(/&eacute;/gi, 'é').replace(/&iacute;/gi, 'í')
    .replace(/&aacute;/gi, 'á').replace(/&uacute;/gi, 'ú').replace(/&agrave;/gi, 'à')
    .replace(/&ecirc;/gi, 'ê').replace(/&ocirc;/gi, 'ô').replace(/&acirc;/gi, 'â')
    .replace(/&Ccedil;/gi, 'Ç').replace(/&Atilde;/gi, 'Ã').replace(/&Otilde;/gi, 'Õ')
    .replace(/&Oacute;/gi, 'Ó').replace(/&Eacute;/gi, 'É').replace(/&Aacute;/gi, 'Á')
    .replace(/&Uacute;/gi, 'Ú').replace(/&Ucirc;/gi, 'Û').replace(/&ucirc;/gi, 'û')
    .replace(/&Icirc;/gi, 'Î').replace(/&icirc;/gi, 'î')
    .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
    .replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function nextResult(html, afterIdx) {
  const chunk = html.slice(afterIdx, afterIdx + 600);
  const m = chunk.match(/class="NomeResult"[^>]*>([^<]{1,120})<\/td>/i);
  return m ? strip(m[1]) : '';
}

function parseData(val) {
  const m = val.match(/(\d{2})\/(\d{2})\/(\d{4})/);
  return m ? `${m[3]}-${m[2]}-${m[1]}` : '';
}

// Dados básicos + SBB dos pais (1a geração real) — mesmo parser de `buscar-abccc`.
function parseBasico(html, sbb) {
  const dados = { encontrado: 'nao', sbb };
  const sbbEsc = sbb.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  const nomeM = html.match(new RegExp('<strong>' + sbbEsc + '<\\/strong><\\/td>\\s*<td[^>]*><strong>([^<]+)<\\/strong>', 'i'));
  if (nomeM) dados.nome = strip(nomeM[1]).toUpperCase();

  const tableRe = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tM;
  while ((tM = tableRe.exec(html)) !== null) {
    const t = tM[1];
    if (!t.includes('NomeCampo') || !t.includes('NomeResult')) continue;
    const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    const trs = [];
    let trM;
    while ((trM = trRe.exec(t)) !== null) {
      const cells = [];
      const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
      let tdM;
      while ((tdM = tdRe.exec(trM[1])) !== null) cells.push(strip(tdM[1]));
      if (cells.length) trs.push({ raw: trM[0], cells });
    }
    for (let i = 0; i < trs.length - 1; i++) {
      if (!trs[i].raw.includes('NomeCampo')) continue;
      if (!trs[i + 1].raw.includes('NomeResult')) continue;
      const L = trs[i].cells, V = trs[i + 1].cells;
      for (let c = 0; c < Math.min(L.length, V.length); c++) {
        const lbl = L[c].toLowerCase().replace(/[:\s.]+$/, '').trim();
        const val = V[c].trim();
        if (!lbl || !val || val === '-' || val === '—') continue;
        if (/nascimento/.test(lbl)) { const d = parseData(val); if (d) dados.nasc = d; }
        if (/^sexo$/.test(lbl)) dados.sexo = (val === 'F' || /f[êe]mea|egua|égua/i.test(val)) ? 'Fêmea' : 'Macho';
        if (/pelagem/.test(lbl) && !dados.pelagem) dados.pelagem = val;
      }
    }
  }
  if (!dados.sexo) {
    const m = html.match(/class="NomeResult">\s*([MF])\s*<\/td>/i);
    if (m) dados.sexo = m[1] === 'F' ? 'Fêmea' : 'Macho';
  }
  if (!dados.nasc) {
    const dm = html.match(/(\d{2})\/(\d{2})\/(\d{4})/);
    if (dm) dados.nasc = `${dm[3]}-${dm[2]}-${dm[1]}`;
  }

  const paiIdx = html.search(/Nome\s+pai\s*:/i);
  if (paiIdx >= 0) { const v = nextResult(html, paiIdx); if (v) dados.pai = v.toUpperCase(); }
  const sbbPaiM = html.match(/Dados do Pai[\s\S]{0,2000}?sbb=([A-Z]\d{4,})/i);
  if (sbbPaiM) dados.sbb_pai = sbbPaiM[1].toUpperCase();

  const maeIdx = html.search(/[MN]ome\s+m(?:&atilde;|ã)e\s*:/i);
  if (maeIdx >= 0) { const v = nextResult(html, maeIdx); if (v) dados.mae = v.toUpperCase(); }
  const sbbMaeM = html.match(/Dados da M[ãa]e[\s\S]{0,2000}?sbb=([A-Z]\d{4,})/i);
  if (sbbMaeM) dados.sbb_mae = sbbMaeM[1].toUpperCase();

  if (dados.nome || dados.nasc || dados.sexo || dados.pelagem) dados.encontrado = 'sim';
  return dados;
}

// Árvore de 5 gerações (nome + geração + lado) — portado 1:1 da edge function
// `analise-sangues` v15 (produção), corrigida em 2026-08-26 pelo Luciano após
// comparar contra HTML real da ABCCC. Três bugs que a versão anterior (v14,
// a que copiamos originalmente pra este script) tinha:
//
// 1) Geração errada: decidia pela PRIMEIRA largura de coluna >10px da linha,
//    mas duas gerações diferentes podem compartilhar a mesma primeira
//    largura nessa estrutura de tabela. Corrigido pra usar a SOMA de todas
//    as larguras da linha — calibrado contra uma árvore real confirmada
//    manualmente: 50→ger.1, 100→ger.2, 200→ger.3, 300→ger.4 (validado em 2
//    subárvores independentes, paterna e materna).
// 2) Metade dos ancestrais jogada fora silenciosamente: a tabela usa
//    bgcolor="#CCCCCC" pra ancestral MACHO e bgcolor="#FFFFCC" pra FÊMEA —
//    o parser só reconhecia CCCCCC, descartando toda mãe/avó (paterna e
//    materna). Corrigido pra aceitar os dois.
// 3) Split paterno/materno nunca funcionava: a marca que a v14 procurava pra
//    achar a linha do próprio animal-raiz não existe do jeito que ela
//    esperava, então sempre caía no fallback de cortar a página na metade
//    dos caracteres — misturando ancestrais entre os dois lados. Corrigido
//    pra usar a marca real "<sbb></a> - RP:", que só aparece na linha do
//    animal-raiz (as linhas de ancestrais têm o formato "<sbb></a> / Pelagem").
function extrairAncestraisComGen(html) {
  const resultado = [];
  const linhaRe = /<tr[^>]*>[\s\S]*?bgcolor=["'](?:#CCCCCC|#FFFFCC)["'][\s\S]*?<\/tr>/gi;
  let m;
  while ((m = linhaRe.exec(html)) !== null) {
    const linha = m[0];
    const nomeM = /<strong>([^<]{3,80})<\/strong>/.exec(linha);
    if (!nomeM) continue;
    const nome = strip(nomeM[1]).toUpperCase();
    if (!nome || nome.match(/^\d/)) continue;
    const widths = [...linha.matchAll(/<td[^>]+width=["'](\d+)["']/gi)].map((w) => parseInt(w[1]));
    const somaWidths = widths.reduce((total, w) => total + w, 0);
    let gen;
    if (somaWidths <= 75) gen = 1;
    else if (somaWidths <= 150) gen = 2;
    else if (somaWidths <= 250) gen = 3;
    else if (somaWidths <= 350) gen = 4;
    else gen = 5;
    resultado.push({ nome, gen });
  }
  return resultado;
}

function parseArvore(html, sbb) {
  const sbbUpper = sbb.toUpperCase();
  const sbbEsc = sbbUpper.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const blocoAnimalRe = new RegExp(
    `<a[^>]*href="[^"]*sbb=${sbbEsc}[^"]*"[^>]*>\\s*${sbbEsc}\\s*<\\/a>\\s*-\\s*RP:`, 'i'
  );
  const matchAnimal = blocoAnimalRe.exec(html);
  let htmlPat, htmlMat;
  if (matchAnimal) {
    htmlPat = html.slice(0, matchAnimal.index);
    htmlMat = html.slice(matchAnimal.index + matchAnimal[0].length);
  } else {
    // Não deveria acontecer mais, mas mantido como rede de segurança —
    // sinaliza no log pra investigarmos se a ABCCC mudar o HTML de novo.
    console.log(`   ⚠ não encontrei a raiz da árvore pro SBB ${sbb} no HTML — usando corte no meio como fallback (pode misturar lados pat/mat)`);
    htmlPat = html.slice(0, html.length / 2);
    htmlMat = html.slice(html.length / 2);
  }
  const pat = extrairAncestraisComGen(htmlPat).map((a) => ({ ...a, lado: 'pat' }));
  const mat = extrairAncestraisComGen(htmlMat).map((a) => ({ ...a, lado: 'mat' }));
  return [...pat, ...mat];
}

// ── ABCCC ─────────────────────────────────────────────────────────────────
async function buscarBasicoEToken(sbb) {
  const res = await fetchAbccc(`${ABCCC_BASE}/pesquisas.php`, {
    method: 'POST',
    headers: { ...ABCCC_HDR, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `sbb=${encodeURIComponent(sbb)}&pesquisar=Pesquisar`,
    signal: AbortSignal.timeout(15000),
  });
  const buf = await res.arrayBuffer();
  const html = new TextDecoder('windows-1252').decode(buf);
  const token = html.match(/quinta_geracao\.php\?sbb_busca=[^&]+&token=([a-f0-9]+)/)?.[1] ?? null;
  return { basico: parseBasico(html, sbb), token };
}

async function buscarArvore5g(sbb, token) {
  const url = `${ABCCC_BASE}/quinta_geracao.php?sbb_busca=${encodeURIComponent(sbb)}&token=${token}`;
  const res = await fetchAbccc(url, { headers: ABCCC_HDR, signal: AbortSignal.timeout(15000) });
  const buf = await res.arrayBuffer();
  const html = new TextDecoder('windows-1252').decode(buf);
  return parseArvore(html, sbb);
}

// ── Lab (REST direto, service_role — bypassa RLS, não passa por produção) ───
// A ABCCC devolve o SBB do pai/mãe (1a geração) mesmo quando esse ancestral
// ainda não tem linha própria em animais_genealogia — e a FK sbb_pai/sbb_mae
// exige que ele já exista. Por isso, antes de gravar o animal, garantimos um
// "stub" mínimo do pai/mãe (resolution=ignore-duplicates: só insere se não
// existir, nunca sobrescreve dado melhor que já esteja lá). Quando o próprio
// pai/mãe for processado depois (via jaTemQuery), ele ganha os dados completos.
async function garantirStub(sbb) {
  if (!sbb) return;
  const res = await fetch(`${LAB_URL}/rest/v1/animais_genealogia?on_conflict=sbb`, {
    method: 'POST',
    headers: {
      apikey: LAB_KEY,
      Authorization: `Bearer ${LAB_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=ignore-duplicates',
    },
    // fonte só aceita 'abccc' | 'catalogo_pdf' | 'plantel_cabanha' | 'manual'
    // (check constraint animais_genealogia_fonte_check) — usamos 'abccc' aqui
    // porque o SBB foi descoberto via ABCCC, mesmo que ainda não tenha sido
    // consultado por si só (isso fica pra quando ele for processado no loop).
    body: JSON.stringify({ sbb, nome: sbb, fonte: 'abccc' }),
  });
  if (!res.ok) throw new Error(`stub ${sbb}: HTTP ${res.status} ${await res.text()}`);
}

async function upsertAnimal(row) {
  await garantirStub(row.sbb_pai);
  await garantirStub(row.sbb_mae);
  const res = await fetch(`${LAB_URL}/rest/v1/animais_genealogia`, {
    method: 'POST',
    headers: {
      apikey: LAB_KEY,
      Authorization: `Bearer ${LAB_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates',
    },
    body: JSON.stringify(row),
  });
  if (!res.ok) throw new Error(`upsert ${row.sbb}: HTTP ${res.status} ${await res.text()}`);
}

async function jaTemQuery(sbb) {
  const res = await fetch(
    `${LAB_URL}/rest/v1/animais_genealogia?sbb=eq.${encodeURIComponent(sbb)}&select=ancestrais_pos,abccc_erro`,
    { headers: { apikey: LAB_KEY, Authorization: `Bearer ${LAB_KEY}` } }
  );
  const corpo = await res.json();
  if (!res.ok || !Array.isArray(corpo)) {
    throw new Error(`jaTemQuery ${sbb}: HTTP ${res.status} — ${JSON.stringify(corpo).slice(0, 500)}`);
  }
  const [row] = corpo;
  return !!row && Array.isArray(row.ancestrais_pos) && row.ancestrais_pos.length > 0 && !row.abccc_erro;
}

async function refreshPosicoes() {
  const res = await fetch(`${LAB_URL}/rest/v1/rpc/genealogia_atualizar_posicoes`, {
    method: 'POST',
    headers: { apikey: LAB_KEY, Authorization: `Bearer ${LAB_KEY}`, 'Content-Type': 'application/json' },
    body: '{}',
  });
  if (!res.ok) console.error('Aviso: refresh de animal_posicoes falhou —', res.status, await res.text());
  else console.log('animal_posicoes atualizada:', await res.text());
}

// ── Loop principal ───────────────────────────────────────────────────────
const inicioExecucao = Date.now();
let ok = 0, erros = 0, pulados = 0;

function logHeartbeat(i) {
  const processados = i + 1;
  const decorridoMs = Date.now() - inicioExecucao;
  const porItemMs = decorridoMs / processados;
  const restantes = sbbs.length - processados;
  const etaMs = restantes * porItemMs;
  const mediaResp = temposResposta.length
    ? Math.round(temposResposta.reduce((a, b) => a + b, 0) / temposResposta.length)
    : 0;
  console.log(
    `\n── progresso: ${processados}/${sbbs.length} (${((processados / sbbs.length) * 100).toFixed(1)}%) | ` +
    `ok=${ok} erros=${erros} pulados=${pulados} | ` +
    `decorrido=${formatarDuracao(decorridoMs)} | eta=${formatarDuracao(etaMs)} | ` +
    `resp.média=${mediaResp}ms | delay atual=${delayAtualMs}ms ──\n`
  );
}

function formatarDuracao(ms) {
  const s = Math.round(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const seg = s % 60;
  if (h > 0) return `${h}h${String(m).padStart(2, '0')}m`;
  if (m > 0) return `${m}m${String(seg).padStart(2, '0')}s`;
  return `${seg}s`;
}

// Detecção do padrão visto em 2026-08-26: depois de horas de requisições
// contínuas, a ABCCC às vezes passa a devolver "não encontrado" (ou árvore
// vazia) pra animais que existem de verdade — sozinho, sem aviso, e sozinho
// se resolve depois de um tempo. Contamos essas duas respostas como
// "suspeitas" (erros de conexão normais não entram aqui, esses já têm seu
// próprio backoff via tempo de resposta). Streak de 3 suspeitas seguidas =
// pausa; se o padrão voltar logo depois de retomar, a pausa escala.
let streakSuspeita = 0;
let nivelPausa = 0;
let sucessosBonsSeguidos = 0;

for (let i = 0; i < sbbs.length; i++) {
  if (parando) {
    console.log(`\nParado por pedido do usuário em ${i}/${sbbs.length}. Nada do que já foi processado foi perdido.`);
    break;
  }

  const sbb = sbbs[i];
  process.stdout.write(`[${i + 1}/${sbbs.length}] ${sbb} ... `);

  let suspeito = false;
  try {
    if (!force && (await jaTemQuery(sbb))) { console.log('já carregado, pulando'); pulados++; continue; }

    const { basico, token } = await buscarBasicoEToken(sbb);
    if (basico.encontrado !== 'sim') {
      await upsertAnimal({ sbb, nome: sbb, fonte: 'abccc', abccc_erro: 'não encontrado na ABCCC', abccc_consultado_em: new Date().toISOString() });
      console.log('não encontrado'); erros++;
      suspeito = true;
    } else {
      let ancestraisPos = [];
      if (token) ancestraisPos = await buscarArvore5g(sbb, token);
      else console.log('(sem token pra 5a geração — só dados básicos) ');

      await upsertAnimal({
        sbb,
        nome: basico.nome || sbb,
        sexo: basico.sexo || null,
        pelagem: basico.pelagem || null,
        nasc: basico.nasc || null,
        sbb_pai: basico.sbb_pai || null,
        sbb_mae: basico.sbb_mae || null,
        ancestrais_pos: ancestraisPos,
        geracoes_completas: ancestraisPos.length ? 5 : (basico.sbb_pai || basico.sbb_mae ? 1 : 0),
        fonte: 'abccc',
        abccc_consultado_em: new Date().toISOString(),
        abccc_erro: null,
      });
      console.log(`ok (${ancestraisPos.length} ancestrais)`);
      ok++;
      if (ancestraisPos.length === 0) suspeito = true;
    }
  } catch (e) {
    console.log('ERRO:', e.message);
    try {
      await upsertAnimal({ sbb, nome: sbb, fonte: 'abccc', abccc_erro: String(e.message).slice(0, 500), abccc_consultado_em: new Date().toISOString() });
    } catch (_) {}
    erros++;
  }

  if (suspeito) {
    streakSuspeita++;
    sucessosBonsSeguidos = 0;
  } else {
    streakSuspeita = 0;
    sucessosBonsSeguidos++;
    if (nivelPausa > 0 && sucessosBonsSeguidos >= SUCESSOS_PRA_RESETAR_ESCALONAMENTO) {
      console.log(`\n✓ ${SUCESSOS_PRA_RESETAR_ESCALONAMENTO} respostas boas seguidas — resetando escalonamento de pausa.`);
      nivelPausa = 0;
    }
  }

  if (streakSuspeita >= STREAK_SUSPEITA_LIMITE && !parando) {
    const duracaoMs = PAUSAS_ESCALONADAS_MS[Math.min(nivelPausa, PAUSAS_ESCALONADAS_MS.length - 1)];
    console.log(
      `\n🛑 ${streakSuspeita} respostas suspeitas seguidas ("não encontrado" ou árvore vazia) — ` +
      `pode ser bloqueio temporário de sessão/taxa da ABCCC (já visto antes, some sozinho). ` +
      `Pausando por ${formatarDuracao(duracaoMs)} antes de continuar de onde parou (Ctrl+C interrompe a pausa também)...\n`
    );
    await dormirInterrompivel(duracaoMs);
    streakSuspeita = 0;
    sucessosBonsSeguidos = 0;
    nivelPausa = Math.min(nivelPausa + 1, PAUSAS_ESCALONADAS_MS.length - 1);
    if (!parando) console.log(`▶ Retomando em ${i + 2}/${sbbs.length}...\n`);
  }

  if ((i + 1) % HEARTBEAT_A_CADA === 0) logHeartbeat(i);
}

console.log(`\nConcluído: ${ok} ok, ${erros} erros, ${pulados} já carregados (pulados). Tempo total: ${formatarDuracao(Date.now() - inicioExecucao)}.`);
if (ok > 0) await refreshPosicoes();
