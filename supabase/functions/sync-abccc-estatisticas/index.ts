import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// sync-abccc-estatisticas — job de sincronização periódica (ADR 0009 + ADR 0010).
//
// Lê do Mimba Lab (njynlsugmvtuvcczmuld, projeto Supabase separado e isolado)
// com credencial própria daquele projeto, e escreve em duas tabelas de
// produção (abccc_estatisticas_animal / abccc_linhagens_em_alta). NÃO roda no
// caminho de requisição de nenhuma cabanha — é chamado por cron (ou
// manualmente por alguém da equipe), nunca pelo agente durante uma conversa.
// Preserva a invariante da ADR 0010: nenhuma requisição de cabanha toca o
// projeto analítico, nem direta nem por proxy.
//
// O cálculo pesado (JOINs sobre 29k/88k linhas, peso de colocação, ranking de
// linhagens em alta) roda dentro do Postgres do Lab via RPCs dedicadas
// (abccc_exportar_resumo/abccc_exportar_linhagens_em_alta) — esta função só
// pagina os resultados e faz upsert em produção, nunca puxa tabela crua.
//
// Autenticação: NÃO usa JWT de usuário (não existe usuário nenhum aqui) —
// exige um segredo compartilhado (SYNC_ABCCC_SHARED_SECRET) no header
// Authorization, deployado com verify_jwt=false. Quem agendar o cron precisa
// configurar esse header na chamada agendada.

const LAB_URL = Deno.env.get("LAB_SUPABASE_URL");
const LAB_KEY = Deno.env.get("LAB_SERVICE_ROLE_KEY");
const SHARED_SECRET = Deno.env.get("SYNC_ABCCC_SHARED_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PAGE_SIZE = 1000;
const TOP_N_LINHAGENS = 15;

function resp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return resp(405, { erro: "metodo" });

  if (!SHARED_SECRET) {
    return resp(500, { erro: "SYNC_ABCCC_SHARED_SECRET nao configurado -- job nao pode rodar." });
  }
  if (req.headers.get("Authorization") !== `Bearer ${SHARED_SECRET}`) {
    return resp(401, { erro: "nao autorizado" });
  }
  if (!LAB_URL || !LAB_KEY) {
    return resp(500, { erro: "LAB_SUPABASE_URL/LAB_SERVICE_ROLE_KEY nao configurados." });
  }

  const lab = createClient(LAB_URL, LAB_KEY);
  const prod = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const inicio = Date.now();
  const agora = new Date().toISOString();
  let totalAnimais = 0;

  try {
    // 1. Resumo por SBB, paginado -- ver public.abccc_exportar_resumo no Lab.
    let offset = 0;
    while (true) {
      const { data, error } = await lab.rpc("abccc_exportar_resumo", { p_limit: PAGE_SIZE, p_offset: offset });
      if (error) throw new Error(`Lab (resumo, offset ${offset}): ${error.message}`);
      if (!data || data.length === 0) break;

      const linhas = data.map((r: Record<string, unknown>) => ({ ...r, sincronizado_em: agora }));
      const { error: errUpsert } = await prod.from("abccc_estatisticas_animal").upsert(linhas, { onConflict: "sbb" });
      if (errUpsert) throw new Error(`Producao (upsert resumo, offset ${offset}): ${errUpsert.message}`);

      totalAnimais += linhas.length;
      if (data.length < PAGE_SIZE) break;
      offset += PAGE_SIZE;
    }

    // 2. Ranking de linhagens em alta -- recompute inteiro, substitui as linhas
    //    antigas das provas recalculadas (ver public.abccc_exportar_linhagens_em_alta).
    const { data: linhagens, error: errLinhagens } = await lab.rpc("abccc_exportar_linhagens_em_alta", {
      p_top_n: TOP_N_LINHAGENS,
    });
    if (errLinhagens) throw new Error(`Lab (linhagens_em_alta): ${errLinhagens.message}`);

    const provasAtualizadas = [...new Set((linhagens ?? []).map((l: { prova: string }) => l.prova))];
    if (provasAtualizadas.length > 0) {
      const { error: errDelete } = await prod
        .from("abccc_linhagens_em_alta")
        .delete()
        .in("prova", provasAtualizadas);
      if (errDelete) throw new Error(`Producao (limpar linhagens antigas): ${errDelete.message}`);
    }

    if (linhagens && linhagens.length > 0) {
      const linhasLinhagens = linhagens.map((l: Record<string, unknown>) => ({ ...l, sincronizado_em: agora }));
      const { error: errInsert } = await prod.from("abccc_linhagens_em_alta").insert(linhasLinhagens);
      if (errInsert) throw new Error(`Producao (inserir linhagens): ${errInsert.message}`);
    }

    return resp(200, {
      status: "concluido",
      animais_sincronizados: totalAnimais,
      linhagens_atualizadas: linhagens?.length ?? 0,
      provas_recalculadas: provasAtualizadas,
      duracao_ms: Date.now() - inicio,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return resp(500, { erro: msg, animais_sincronizados_antes_do_erro: totalAnimais, duracao_ms: Date.now() - inicio });
  }
});
