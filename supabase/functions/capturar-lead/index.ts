import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// capturar-lead — recebe o mini-formulário "Quero conhecer" da landing
// (mimba.com.br). Pública, sem autenticação (visitante ainda não é cliente).
// Mesmo padrão de rate-limit por IP do ADR 0004 (criar-checkout/
// criar-checkout-trial) — é um endpoint público, alvo natural de spam.
//
// Escreve com service_role porque `public.leads` não tem NENHUM grant pra
// anon/authenticated de propósito (mesmo padrão de `signups`) — só esta
// função (e o time, via SQL) toca essa tabela.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function resp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resp(405, { erro: "metodo" });

  const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supa = createClient(SUPA_URL, SERVICE);

  // Rate-limit por IP — 5 tentativas / 60min (mais folgado que o checkout,
  // mas ainda protege contra bot enchendo a tabela).
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("x-real-ip") || "desconhecido";
  const { data: liberado } = await supa.rpc("checar_rate_limit", { p_chave: `capturar-lead:${ip}`, p_limite: 5, p_janela_minutos: 60 });
  if (liberado !== true) return resp(429, { erro: "Muitas tentativas. Tente novamente mais tarde." });

  let body: any;
  try { body = await req.json(); } catch { return resp(400, { erro: "payload" }); }
  const { nome, contato, origem, pagina_url, utm_source, utm_medium, utm_campaign } = body;
  if (!nome || !contato) return resp(400, { erro: "Preencha nome e contato." });
  if (String(nome).length > 200 || String(contato).length > 200) return resp(400, { erro: "Campo muito longo." });

  const { error } = await supa.from("leads").insert({
    nome: String(nome).trim(),
    contato: String(contato).trim(),
    origem: origem ? String(origem).slice(0, 100) : "landing",
    pagina_url: pagina_url ? String(pagina_url).slice(0, 500) : null,
    utm_source: utm_source ? String(utm_source).slice(0, 200) : null,
    utm_medium: utm_medium ? String(utm_medium).slice(0, 200) : null,
    utm_campaign: utm_campaign ? String(utm_campaign).slice(0, 200) : null,
  });
  if (error) return resp(500, { erro: "Falha ao registrar. Tente novamente." });

  return resp(200, { sucesso: true });
});
