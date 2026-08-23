import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// agente-ia — chat flutuante do agente de IA interno (ADR 0006 + 0007).
//
// Diferente da maioria das Edge Functions deste projeto, esta é a primeira a
// nascer versionada no repo (`supabase/functions/agente-ia/index.ts`) em vez
// de só existir no dashboard do Supabase — vale a pena revisar código aqui.
//
// Roda com o JWT do usuário logado (verify_jwt=true, nunca service_role). O
// modelo (Claude) NUNCA monta SQL livre: as únicas "ferramentas" que ele pode
// chamar são RPCs Postgres já existentes e read-only (`cab_buscar_animal`,
// `cab_listar_gestacoes_ativas`, `cab_resumo_periodo`) mais uma busca estática
// (`ajuda_sistema`, sem RPC nenhuma). A autorização real de cada ferramenta
// acontece no Postgres via `tem_acesso_tenant` dentro da própria RPC — esta
// função nunca eleva privilégio pra satisfazer uma chamada de ferramenta.
//
// Escopo desta v1 (ver docs/adr/0006 e 0007): caso de uso 1 (dado da própria
// cabanha) + caso de uso 4 (ajuda de uso). Conhecimento geral do Mimba Lab e
// score de cruzamento sob demanda ficam de fora por ora.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
// Sem fallback hardcoded de propósito — o ID de modelo certo na API pública da
// Anthropic muda com o tempo; melhor exigir a variável explicitamente do que
// arriscar embutir um ID desatualizado/errado. Configurar junto com a
// ANTHROPIC_API_KEY quando ela existir (ver docs.anthropic.com/en/docs/about-claude/models).
const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL");
const MAX_RODADAS_TOOL_USE = 5;

function resp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

// Mantido em sincronia manual com docs/agente-ia-base-conhecimento.md — texto
// curto o bastante pra caber inline no system prompt sem busca/embeddings.
const BASE_CONHECIMENTO_USO = `
O Mimba organiza a gestão da cabanha em: Dashboard (resumo geral e alertas), Animais (cadastro e
ficha de cada animal), Reprodutivo (Gestações ativas, Planejador de ciclo, Cruzamentos/Conselho,
Protocolos, Crias por ciclo, Plantel), Nutrição (projetos, templates, lista de compras), Eventos
(calendário/histórico, por animal, resultados), Estoque (itens, alertas, movimentações), Medidas
(corporais por animal), Financeiro (lançamentos), Sangues (genealogia via ABCCC/SBB) e Relatórios.

Administradores convidam novos usuários (veterinário, cabanheiro, outro administrador) pela tela
de Usuários. O agente é só consulta — não cadastra nem edita nada, e não tem acesso a dado de
outra cabanha. Sugestões de manejo/cruzamento são apoio à decisão, não prescrição veterinária.
`.trim();

const SYSTEM_PROMPT = `Você é o assistente interno do Mimba, um sistema de gestão para cabanhas de
cavalo Crioulo. Responda em português do Brasil, de forma direta e objetiva.

Você tem acesso a ferramentas que consultam o banco de dados da cabanha do usuário logado (fonte
"cabanha") e a uma base de conhecimento estática sobre como o sistema funciona (fonte "sistema").
Cada resultado de ferramenta já vem marcado com sua fonte real — nunca invente ou troque a fonte
de uma informação. Sempre que combinar mais de uma fonte numa resposta, deixe claro pro usuário
qual é qual (ex.: "na sua cabanha..." vs. "sobre como o sistema funciona...").

Você NÃO tem acesso a dado de nenhuma outra cabanha, e não tem (por ora) um mecanismo de calcular
o score de cruzamento sob demanda entre um garanhão e uma égua específicos fora da tela do
Conselho — se perguntarem isso, explique essa limitação em vez de inventar um número.

Base de conhecimento de uso do sistema (fonte "sistema"):
${BASE_CONHECIMENTO_USO}`;

const TOOLS = [
  {
    name: "cab_buscar_animal",
    description: "Busca animais da cabanha do usuário por nome, SBB ou RP. Retorna até 10 resultados compactos.",
    input_schema: {
      type: "object",
      properties: { termo: { type: "string", description: "Nome, código SBB ou RP (ou parte deles) a buscar" } },
      required: ["termo"],
    },
  },
  {
    name: "cab_listar_gestacoes_ativas",
    description: "Lista as gestações ativas (éguas prenhas) da cabanha do usuário, com datas de cobertura, confirmação e parto previsto.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "cab_resumo_periodo",
    description: "Contagens agregadas da cabanha do usuário num período: nascimentos, coberturas registradas, vacinas aplicadas, vacinas e exames vencendo no período.",
    input_schema: {
      type: "object",
      properties: {
        data_inicio: { type: "string", description: "Data inicial, formato YYYY-MM-DD" },
        data_fim: { type: "string", description: "Data final, formato YYYY-MM-DD" },
      },
      required: ["data_inicio", "data_fim"],
    },
  },
  {
    name: "ajuda_sistema",
    description: "Consulta a base de conhecimento estática sobre como o Mimba funciona (não é dado de banco, não muda por cabanha).",
    input_schema: {
      type: "object",
      properties: { topico: { type: "string", description: "O que o usuário quer entender sobre o sistema" } },
      required: ["topico"],
    },
  },
];

type Ferramenta = { id: string; name: string; input: Record<string, unknown> };

async function executarFerramenta(supa: ReturnType<typeof createClient>, tenantId: string, chamada: Ferramenta) {
  switch (chamada.name) {
    case "cab_buscar_animal": {
      const { data, error } = await supa.rpc("cab_buscar_animal", { p_tenant_id: tenantId, p_termo: chamada.input.termo });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_listar_gestacoes_ativas": {
      const { data, error } = await supa.rpc("cab_listar_gestacoes_ativas", { p_tenant_id: tenantId });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_resumo_periodo": {
      const { data, error } = await supa.rpc("cab_resumo_periodo", {
        p_tenant_id: tenantId,
        p_data_inicio: chamada.input.data_inicio,
        p_data_fim: chamada.input.data_fim,
      });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "ajuda_sistema":
      return { fonte: "sistema", resultado: BASE_CONHECIMENTO_USO };
    default:
      return { fonte: "sistema", erro: `ferramenta desconhecida: ${chamada.name}` };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resp(405, { erro: "metodo" });

  if (!ANTHROPIC_API_KEY || !ANTHROPIC_MODEL) {
    return resp(500, { erro: "ANTHROPIC_API_KEY/ANTHROPIC_MODEL nao configurados — agente ainda nao esta ativo." });
  }

  const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
  const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return resp(401, { erro: "nao autenticado" });

  // Client com o JWT do próprio usuário — nunca service_role. Toda RPC chamada
  // a partir daqui roda com a autorização real desse usuário.
  const supa = createClient(SUPA_URL, ANON, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: errUser } = await supa.auth.getUser();
  if (errUser || !user) return resp(401, { erro: "sessao invalida" });

  let body: any;
  try { body = await req.json(); } catch { return resp(400, { erro: "payload" }); }
  const { tenant_id, mensagens } = body;
  if (!tenant_id || !Array.isArray(mensagens) || mensagens.length === 0) {
    return resp(400, { erro: "tenant_id e mensagens (array) sao obrigatorios" });
  }

  // Cota mensal — checa e incrementa ANTES de gastar qualquer chamada de LLM.
  const { data: uso, error: errUso } = await supa.rpc("agente_ia_registrar_uso", { p_tenant_id: tenant_id });
  if (errUso) return resp(403, { erro: errUso.message });
  if (uso?.excedeu) {
    return resp(429, { erro: `Limite de mensagens do agente de IA atingido este mês (${uso.cota}). Fala com o suporte se precisar de mais.` });
  }

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      const enviar = (evento: string, dados: unknown) => {
        controller.enqueue(encoder.encode(`event: ${evento}\ndata: ${JSON.stringify(dados)}\n\n`));
      };

      let historico = [...mensagens];

      try {
        for (let rodada = 0; rodada < MAX_RODADAS_TOOL_USE; rodada++) {
          const r = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "x-api-key": ANTHROPIC_API_KEY,
              "anthropic-version": "2023-06-01",
              "content-type": "application/json",
            },
            body: JSON.stringify({
              model: ANTHROPIC_MODEL,
              max_tokens: 1024,
              system: SYSTEM_PROMPT,
              messages: historico,
              tools: TOOLS,
              stream: true,
            }),
          });

          if (!r.ok || !r.body) {
            const detalhe = await r.text().catch(() => "");
            enviar("erro", { erro: `Claude API ${r.status}: ${detalhe}` });
            controller.close();
            return;
          }

          // Consome o SSE da Claude, repassando texto pro cliente incrementalmente
          // e acumulando blocos de tool_use (chegam em pedaços de JSON parcial).
          const reader = r.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";
          const blocosConteudo: any[] = [];
          let stopReason: string | null = null;

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const partes = buffer.split("\n\n");
            buffer = partes.pop() ?? "";

            for (const parte of partes) {
              const linhaDados = parte.split("\n").find((l) => l.startsWith("data: "));
              if (!linhaDados) continue;
              const evento = JSON.parse(linhaDados.slice(6));

              if (evento.type === "content_block_start") {
                blocosConteudo[evento.index] = { ...evento.content_block };
                if (evento.content_block.type === "tool_use") blocosConteudo[evento.index].input_json = "";
              } else if (evento.type === "content_block_delta") {
                if (evento.delta.type === "text_delta") {
                  blocosConteudo[evento.index].text = (blocosConteudo[evento.index].text ?? "") + evento.delta.text;
                  enviar("texto", { delta: evento.delta.text });
                } else if (evento.delta.type === "input_json_delta") {
                  blocosConteudo[evento.index].input_json += evento.delta.partial_json;
                }
              } else if (evento.type === "message_delta") {
                if (evento.delta.stop_reason) stopReason = evento.delta.stop_reason;
              }
            }
          }

          const blocosFinais = blocosConteudo.map((b) =>
            b.type === "tool_use" ? { ...b, input: JSON.parse(b.input_json || "{}") } : b
          );
          historico.push({ role: "assistant", content: blocosFinais });

          if (stopReason !== "tool_use") {
            enviar("fim", {});
            controller.close();
            return;
          }

          const chamadasFerramenta = blocosFinais.filter((b) => b.type === "tool_use") as Ferramenta[];
          const resultados = await Promise.all(
            chamadasFerramenta.map(async (chamada) => {
              enviar("ferramenta", { nome: chamada.name });
              const resultado = await executarFerramenta(supa, tenant_id, chamada);
              return {
                type: "tool_result" as const,
                tool_use_id: chamada.id,
                content: JSON.stringify(resultado),
              };
            })
          );
          historico.push({ role: "user", content: resultados });
        }

        enviar("erro", { erro: "Limite de rodadas de ferramentas atingido." });
        controller.close();
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        enviar("erro", { erro: msg });
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: { ...CORS, "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" },
  });
});
