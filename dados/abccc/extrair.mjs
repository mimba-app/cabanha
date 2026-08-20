#!/usr/bin/env node
// Extrai a tabela do painel de resultados da ABCCC (Power BI publish-to-web) para CSV.
// Fonte: https://www.cavalocrioulo.org.br/eventos/painel_resultados
// Uso:  node extrair.mjs [--ciclo=2026|all|1982,1983] [--saida=arquivo.csv]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = path.dirname(fileURLToPath(import.meta.url));
const API = 'https://wabi-brazil-south-b-primary-api.analysis.windows.net/public/reports/querydata?synchronous=true';
const RESOURCE_KEY = '7ae570a3-b838-4624-8535-13eb3059a593'; // do parâmetro ?r= do embed público

const args = Object.fromEntries(process.argv.slice(2).map(a => {
  const m = a.match(/^--([^=]+)=?(.*)$/); return m ? [m[1], m[2]] : [a, true];
}));

// Ordem e rótulos como aparecem no visual
const COLUNAS = [
  ['evtencerramento.sbb', 'SBB'],
  ['abccc ANIMA_PR.DAD_DESCRI', 'Animal'],
  ['evtencerramento.SexoNome', 'Sexo'],
  ['abccc ANIMA.DAD_DESCRI', 'Pai'],
  ['abccc ANIMA (2).DAD_DESCRI', 'Mãe'],
  ['abccc PESSOAS.DAD_DESCRI', 'Criador'],
  ['evtencerramento.ciclo', 'Ciclo'],
  ['evtencerramento.cidade', 'Cidade'],
  ['evtprova.descricao', 'Prova'],
  ['evtclassificacao_inscrito.Premio_Generico', 'Colocação'],
];

function montarCorpo(ciclos) {
  const body = JSON.parse(fs.readFileSync(path.join(DIR, 'query.json'), 'utf8'));
  const q = body.queries[0].Query.Commands[0].SemanticQueryDataShapeCommand.Query;
  const iCiclo = q.Where.findIndex(w => w.Condition?.In?.Expressions?.[0]?.Column?.Property === 'ciclo');
  if (ciclos === 'all') {
    if (iCiclo >= 0) q.Where.splice(iCiclo, 1);
  } else if (ciclos) {
    const vals = ciclos.split(',').map(c => [{ Literal: { Value: `'${c.trim()}'` } }]);
    q.Where[iCiclo].Condition.In.Values = vals;
  }
  return body;
}

// Decodifica o formato DSR compactado do Power BI (ValueDicts + bitmask R/Ø)
function decodificar(json) {
  const data = json.results[0].result.data;
  const nomePorValue = Object.fromEntries(data.descriptor.Select.map(d => [d.Value, d.Name]));
  const ds = data.dsr.DS[0];
  const dicts = ds.ValueDicts || {};
  const dm = ds.PH[0].DM0 || [];
  const schema = dm.find(x => x.S)?.S;
  if (!schema) return { headers: [], rows: [], restart: ds.RT || null };
  const cols = schema.map(s => ({ nome: nomePorValue[s.N] || s.N, dict: s.DN }));
  const rows = [];
  let anterior = new Array(cols.length).fill(null);
  for (const item of dm) {
    const C = item.C || [];
    const R = item.R || 0;
    const NUL = item['Ø'] || 0;
    if (!C.length && !R && !NUL) continue;
    const linha = new Array(cols.length);
    let ci = 0;
    for (let j = 0; j < cols.length; j++) {
      if (R & (1 << j)) { linha[j] = anterior[j]; continue; }
      if (NUL & (1 << j)) { linha[j] = null; continue; }
      let v = C[ci++];
      const d = cols[j].dict;
      if (d && dicts[d] && typeof v === 'number') v = dicts[d][v];
      linha[j] = v;
    }
    rows.push(linha);
    anterior = linha;
  }
  return { headers: cols.map(c => c.nome), rows, restart: ds.RT || null };
}

async function consultar(body) {
  const r = await fetch(API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json;charset=UTF-8', 'X-PowerBI-ResourceKey': RESOURCE_KEY },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${(await r.text()).slice(0, 300)}`);
  return decodificar(await r.json());
}

const csvCampo = v => {
  const s = (v ?? '').toString().trim();
  return /[",;\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const ciclo = args.ciclo || '2026';
const saida = path.join(DIR, args.saida || `painel-resultados-${ciclo === 'all' ? 'todos-ciclos' : ciclo}.csv`);

const body = montarCorpo(ciclo);
const janela = body.queries[0].Query.Commands[0].SemanticQueryDataShapeCommand.Binding.DataReduction.Primary.Window;

let headers = null;
const todas = [];
for (let pagina = 1; pagina <= 50; pagina++) {
  const { headers: h, rows, restart } = await consultar(body);
  if (!headers) headers = h;
  // páginas de continuação repetem a linha do restart token — descarta
  if (pagina > 1) rows.shift();
  todas.push(...rows);
  process.stderr.write(`  página ${pagina}: +${rows.length} linhas (total ${todas.length})\n`);
  if (!restart || !rows.length) break;
  janela.RestartTokens = restart;
}

// reordena para a ordem do visual
const idx = COLUNAS.map(([ref]) => headers.indexOf(ref));
const faltando = COLUNAS.filter((_, i) => idx[i] === -1).map(([, r]) => r);
if (faltando.length) throw new Error(`Colunas não encontradas na resposta: ${faltando.join(', ')}`);

const linhas = [COLUNAS.map(([, rot]) => rot).join(',')];
for (const r of todas) linhas.push(idx.map(i => csvCampo(r[i])).join(','));
fs.writeFileSync(saida, '﻿' + linhas.join('\n') + '\n', 'utf8'); // BOM p/ Excel

console.log(`${todas.length} linhas -> ${saida}`);
