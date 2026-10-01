import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const ABCCC_URL = 'https://www.cavalocrioulo.org.br/pesquisa/pesquisas.php';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const url = new URL(req.url);
  const sbb   = (url.searchParams.get('sbb') || '').trim().toUpperCase();
  const debug = url.searchParams.get('debug') || '';
  if (!sbb) return new Response(JSON.stringify({ erro: 'SBB nao informado' }), {
    status: 400, headers: { ...CORS, 'Content-Type': 'application/json' }
  });

  let html = '';
  try {
    const res = await fetch(ABCCC_URL, {
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'pt-BR,pt;q=0.9',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'https://www.cavalocrioulo.org.br/',
      },
      body: `sbb=${encodeURIComponent(sbb)}&pesquisar=Pesquisar`,
      signal: AbortSignal.timeout(15000),
    });
    const buf = await res.arrayBuffer();
    try { html = new TextDecoder('windows-1252').decode(buf); }
    catch(_) { html = new TextDecoder('utf-8', { fatal: false }).decode(buf); }
  } catch (e) {
    return new Response(JSON.stringify({ erro: 'Falha ABCCC: ' + String(e) }), {
      status: 502, headers: { ...CORS, 'Content-Type': 'application/json' }
    });
  }

  // A ABCCC reformulou o site de pesquisa (2026-09/10): a URL antiga que esta
  // função usa não processa mais a busca — agora só devolve de volta a própria
  // página do formulário de pesquisa, que exige um token de reCAPTCHA v3
  // (gerado no navegador do usuário, via grecaptcha.execute) antes de aceitar
  // a submissão de verdade na nova URL (/pesquisas/pesquisa/buscar). Não dá
  // pra resolver isso de um Edge Function — geração de token de reCAPTCHA não
  // pode ser forjada do servidor, e tentar seria contornar uma proteção
  // anti-bot deliberada da própria ABCCC. Até a ABCCC abrir uma via oficial
  // (API ou parceria), a busca automática por SBB fica indisponível — o
  // importante aqui é NÃO confundir isso com "SBB não encontrado" (que tem
  // outro significado pro usuário: pode levar a achar que o animal não está
  // registrado quando na verdade é a integração que está fora do ar).
  const paginaDeFormulario = /id=["']frm-busca["']/i.test(html) || /g-recaptcha-response/i.test(html);
  if (paginaDeFormulario) {
    return new Response(JSON.stringify({
      erro: 'A pesquisa da ABCCC mudou e agora exige verificação humana (reCAPTCHA) — não é possível buscar automaticamente no momento.',
      indisponivel: true,
      sbb,
    }), { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } });
  }

  const sbbIdx = html.toUpperCase().indexOf(sbb);

  if (debug === '1' || debug === '2') {
    const size = debug === '2' ? 15000 : 6000;
    const trecho = sbbIdx >= 0
      ? html.slice(Math.max(0, sbbIdx - 300), sbbIdx + size)
      : html.slice(0, size);
    return new Response(JSON.stringify({ sbb, sbbIdx, trecho }), {
      status: 200, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' }
    });
  }

  if (sbbIdx < 0) return new Response(
    JSON.stringify({ encontrado: 'nao', sbb }),
    { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } }
  );

  return new Response(JSON.stringify(parseAbccc(html, sbb)), {
    status: 200, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' }
  });
});

function calcularCiclo(nasc: string): string {
  const d = new Date(nasc + 'T12:00:00');
  if (isNaN(d.getTime())) return '';
  const mes = d.getMonth() + 1, ano = d.getFullYear();
  const ini = mes >= 8 ? ano : ano - 1;
  return `${String(ini).slice(-2)}/${String(ini+1).slice(-2)}`;
}

function strip(s: string): string {
  return s
    .replace(/&ccedil;/gi,'ç').replace(/&atilde;/gi,'ã').replace(/&otilde;/gi,'õ')
    .replace(/&oacute;/gi,'ó').replace(/&eacute;/gi,'é').replace(/&iacute;/gi,'í')
    .replace(/&aacute;/gi,'á').replace(/&uacute;/gi,'ú').replace(/&agrave;/gi,'à')
    .replace(/&ecirc;/gi,'ê').replace(/&ocirc;/gi,'ô').replace(/&acirc;/gi,'â')
    .replace(/&Ccedil;/gi,'Ç').replace(/&Atilde;/gi,'Ã').replace(/&Otilde;/gi,'Õ')
    .replace(/&Oacute;/gi,'Ó').replace(/&Eacute;/gi,'É').replace(/&Aacute;/gi,'Á')
    .replace(/&Uacute;/gi,'Ú').replace(/&Ucirc;/gi,'Û').replace(/&ucirc;/gi,'û')
    .replace(/&Icirc;/gi,'Î').replace(/&icirc;/gi,'î')
    .replace(/&nbsp;/gi,' ').replace(/&amp;/gi,'&').replace(/&lt;/gi,'<').replace(/&gt;/gi,'>')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
    .replace(/<[^>]+>/g, ' ').replace(/\s+/g,' ').trim();
}

function nextResult(html: string, afterIdx: number): string {
  const chunk = html.slice(afterIdx, afterIdx + 600);
  const m = chunk.match(/class="NomeResult"[^>]*>([^<]{1,120})<\/td>/i);
  return m ? strip(m[1]) : '';
}

// Extrai data dd/mm/yyyy e converte para yyyy-mm-dd
function parseData(val: string): string {
  const m = val.match(/(\d{2})\/(\d{2})\/(\d{4})/);
  return m ? `${m[3]}-${m[2]}-${m[1]}` : '';
}

function parseAbccc(html: string, sbb: string): Record<string,string|boolean> {
  const dados: Record<string,string|boolean> = { encontrado:'nao', sbb };
  const sbbEsc = sbb.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');

  // ── Nome
  const nomeM = html.match(new RegExp('<strong>'+sbbEsc+'<\/strong><\/td>\\s*<td[^>]*><strong>([^<]+)<\/strong>','i'));
  if (nomeM) dados.nome = strip(nomeM[1]).toUpperCase();

  // ── RP: terceira célula SBB | Nome | RP
  const rpM = html.match(new RegExp('<strong>'+sbbEsc+'<\/strong><\/td>\\s*<td[^>]*><strong>[^<]+<\/strong><\/td>\\s*<td[^>]*><strong>(\\d+)<\/strong>','i'));
  if (rpM) dados.rp = rpM[1];

  // ── Parse genérico NomeCampo/NomeResult
  const tableRe = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tM;
  while ((tM = tableRe.exec(html)) !== null) {
    const t = tM[1];
    if (!t.includes('NomeCampo') || !t.includes('NomeResult')) continue;
    const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    const trs: {raw:string;cells:string[]}[] = [];
    let trM;
    while ((trM = trRe.exec(t)) !== null) {
      const cells: string[] = [];
      const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi; let tdM;
      while ((tdM = tdRe.exec(trM[1])) !== null) cells.push(strip(tdM[1]));
      if (cells.length) trs.push({raw:trM[0], cells});
    }
    for (let i=0; i<trs.length-1; i++) {
      if (!trs[i].raw.includes('NomeCampo')) continue;
      if (!trs[i+1].raw.includes('NomeResult')) continue;
      const L=trs[i].cells, V=trs[i+1].cells;
      for (let c=0; c<Math.min(L.length,V.length); c++) {
        const lbl=L[c].toLowerCase().replace(/[:\s.]+$/,'').trim();
        const val=V[c].trim();
        if (!lbl||!val||val==='-'||val==='—') continue;

        // Campos existentes
        if (/nascimento/.test(lbl)){const d=parseData(val);if(d)dados.nasc=d;}
        if (/^sexo$/.test(lbl)) dados.sexo=(val==='F'||/f[êe]mea|egua|égua/i.test(val))?'Fêmea':'Macho';
        if (/pelagem/.test(lbl)&&!dados.pelagem) dados.pelagem=val;
        if (/^rp$|registro.?prov/i.test(lbl)&&!dados.rp) dados.rp=val;
        if (/afixo/.test(lbl)&&!dados.afixo) dados.afixo=val;
        if (/criador.*nome|nome.*criador/i.test(lbl)&&!dados.nome_criador) dados.nome_criador=val;
        if (/propriet.*nome|nome.*propriet/i.test(lbl)&&!dados.nome_proprietario) dados.nome_proprietario=val;
        if (/código.*propriet|propriet.*código/i.test(lbl)&&!dados.cod_proprietario) dados.cod_proprietario=val;
        if (/cidade.*estabelec/i.test(lbl)&&!dados.cidade_estabelecimento) dados.cidade_estabelecimento=val;

        // ── NOVOS CAMPOS ──
        // Status (Habilitado/etc)
        if (/^status$/.test(lbl)&&!dados.status_abccc) dados.status_abccc=val;
        // Situação (Confirmado/Em desenvolvimento/etc)
        if (/^situa/i.test(lbl)&&!dados.situacao) dados.situacao=val;
        // Data de confirmação
        if (/^confirma/i.test(lbl)&&!dados.confirmacao_data){const d=parseData(val);if(d)dados.confirmacao_data=d;else if(val&&val.length>3)dados.confirmacao_data=val;}
        // Registro de Méritos
        if (/m[eé]rito/i.test(lbl)) dados.tem_rm = /sim|s|yes/i.test(val);
        // Última transferência
        if (/transfer/i.test(lbl)&&!dados.ultima_transferencia){const d=parseData(val);if(d)dados.ultima_transferencia=d;}
        // Animal com restrição
        if (/restri/i.test(lbl)) dados.com_restricao = /sim|s|yes/i.test(val);
        // Castrado
        if (/^castra/i.test(lbl)) dados.castrado_abccc = /sim|s|yes/i.test(val);
        // N.M.G.C. (número de galopes/méritos)
        if (/n\.?m\.?g\.?c/i.test(lbl)&&!dados.nmgc) dados.nmgc=val;
        // Medidas oficiais ABCCC
        if (/^altura$/.test(lbl)&&!dados.altura){const n=parseFloat(val.replace(',','.'));if(!isNaN(n))dados.altura=String(n);}
        if (/^torax$|^tórax$/.test(lbl)&&!dados.torax){const n=parseFloat(val.replace(',','.'));if(!isNaN(n))dados.torax=String(n);}
        if (/^canela$/.test(lbl)&&!dados.canela){const n=parseFloat(val.replace(',','.'));if(!isNaN(n))dados.canela=String(n);}
      }
    }
  }

  // Sexo fallback
  if (!dados.sexo) {
    const m=html.match(/class="NomeResult">\s*([MF])\s*<\/td>/i);
    if(m) dados.sexo=m[1]==='F'?'Fêmea':'Macho';
  }
  // Nascimento fallback
  if (!dados.nasc) {
    const dm=html.match(/(\d{2})\/(\d{2})\/(\d{4})/);
    if(dm) dados.nasc=`${dm[3]}-${dm[2]}-${dm[1]}`;
  }

  // ── Pai: label "Nome pai:" + SBB pai
  const paiIdx = html.search(/Nome\s+pai\s*:/i);
  if (paiIdx >= 0) { const v=nextResult(html,paiIdx); if(v) dados.pai=v.toUpperCase(); }
  // SBB pai: link href com ?sbb=BXXXXXX antes de "Dados do Pai"
  const sbbPaiM = html.match(/Dados do Pai[\s\S]{0,2000}?sbb=([A-Z]\d{4,})/i);
  if (sbbPaiM) dados.sbb_pai = sbbPaiM[1].toUpperCase();
  // RP pai
  const rpPaiIdx = html.search(/RP\s+pai\s*:/i);
  if (rpPaiIdx >= 0) { const v=nextResult(html,rpPaiIdx); if(v) dados.rp_pai=v; }

  // ── Mãe: label "Mome m&atilde;e:" (typo ABCCC)
  const maeIdx = html.search(/[MN]ome\s+m(?:&atilde;|ã)e\s*:/i);
  if (maeIdx >= 0) { const v=nextResult(html,maeIdx); if(v) dados.mae=v.toUpperCase(); }
  // SBB mãe
  const sbbMaeM = html.match(/Dados da M[ãa]e[\s\S]{0,2000}?sbb=([A-Z]\d{4,})/i);
  if (sbbMaeM) dados.sbb_mae = sbbMaeM[1].toUpperCase();
  // RP mãe
  const rpMaeIdx = html.search(/RP\s+m(?:&atilde;|ã)e\s*:/i);
  if (rpMaeIdx >= 0) { const v=nextResult(html,rpMaeIdx); if(v) dados.rp_mae=v; }

  if (dados.nasc) dados.ciclo = calcularCiclo(dados.nasc as string);
  if (dados.nome||dados.nasc||dados.sexo||dados.pelagem) dados.encontrado='sim';
  return dados;
}
