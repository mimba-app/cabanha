import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// convidar-usuario — admin de uma cabanha convida um novo usuário (vet/cabanheiro/
// outro admin) para acessá-la. Diferente das demais funções deste projeto: é chamada
// diretamente pelo navegador de um usuário logado (não por um webhook/service_role),
// então quem autentica o chamador é o próprio Supabase (verify_jwt=true) — o código
// ainda confere explicitamente que quem chama é admin ATIVO do tenant informado antes
// de escrever qualquer coisa.
//
// Fluxo: identidade no Auth (cria ou reaproveita) -> tenant_memberships (cria OU
// reativa, se a pessoa já tinha sido removida antes — ver nota abaixo) -> linha em
// <schema>.usuarios (via RPC vincular_usuario_cabanha) -> e-mail de acesso (código
// de 6 dígitos se identidade nova; aviso simples se a pessoa já tinha conta).

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const APP_URL     = Deno.env.get("APP_URL") ?? "https://app.mimba.com.br";
const REDIRECT_TO = Deno.env.get("ACCESS_REDIRECT_TO") ?? `${APP_URL}/`;
const FROM        = Deno.env.get("RESEND_FROM") ?? "Mimba <acesso@mimba.com.br>";
const REPLY_TO    = Deno.env.get("RESEND_REPLY_TO") ?? "app.mimba@gmail.com";

const PERFIL_LABEL: Record<string, string> = { adm: "Administrador(a)", vet: "Veterinário(a)", cab: "Cabanheiro(a)" };

function resp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}
function esc(s: string): string {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));
}

const CREME = "#faf6ef", TERRA = "#5c3a24", OURO = "#b8862f", TINTA = "#2e2a24", SUAVE = "#8a7f70";
function layout(inner: string): string {
  return `<!doctype html><html><body style="margin:0;padding:0;background:${CREME};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${CREME};padding:32px 0;font-family:'Helvetica Neue',Arial,sans-serif;">
    <tr><td align="center">
      <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;background:#ffffff;border-radius:14px;overflow:hidden;border:1px solid #eadfce;">
        <tr><td style="background:${TERRA};padding:22px 32px;">
          <span style="color:${CREME};font-size:20px;font-weight:700;letter-spacing:.5px;">Mimba</span>
          <span style="color:#d8c39a;font-size:12px;margin-left:8px;">Gestão de Crioulos</span>
        </td></tr>
        <tr><td style="padding:32px;color:${TINTA};font-size:15px;line-height:1.6;">${inner}</td></tr>
        <tr><td style="padding:20px 32px;border-top:1px solid #eee;color:${SUAVE};font-size:12px;line-height:1.5;">
          Você recebeu este e-mail porque foi convidado a acessar uma cabanha na Mimba.<br>
          Em caso de dúvida, responda esta mensagem.
        </td></tr>
      </table>
    </td></tr>
  </table></body></html>`;
}
function botao(url: string, texto: string): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0;"><tr>
    <td style="background:${OURO};border-radius:8px;">
      <a href="${esc(url)}" style="display:inline-block;padding:13px 28px;color:#fff;text-decoration:none;font-weight:600;font-size:15px;">${esc(texto)}</a>
    </td></tr></table>`;
}
function blocoCodigo(codigo: string | null): string {
  if (!codigo) return "";
  return `
    <div style="background:${CREME};border:1px solid #eadfce;border-radius:10px;padding:14px 20px;text-align:center;font-size:28px;font-weight:800;letter-spacing:6px;color:${TERRA};">${esc(codigo)}</div>`;
}

// Gera o link "definir senha" + o código de 6 dígitos equivalente (email_otp). Os dois
// compartilham o MESMO token por baixo — só usamos o código no e-mail (ver nota abaixo
// no ponto de uso), mas o link ainda é gerado/retornado caso um dia seja útil.
async function gerarLinkRecovery(supaUrl: string, service: string, email: string, redirectTo: string): Promise<{ link: string; codigo: string | null }> {
  const r = await fetch(`${supaUrl}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: { apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "application/json" },
    body: JSON.stringify({ type: "recovery", email, redirect_to: redirectTo }),
  });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`generate_link ${r.status}: ${JSON.stringify(d)}`);
  const link = d?.action_link ?? d?.properties?.action_link;
  if (!link) throw new Error("generate_link sem action_link");
  const codigo = d?.email_otp ?? d?.properties?.email_otp ?? null;
  return { link: link as string, codigo };
}

async function enviarEmail(email: string, subject: string, html: string, resendKey: string) {
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to: [email], reply_to: REPLY_TO, subject, html }),
  });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`resend ${r.status}: ${JSON.stringify(d)}`);
  return d;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resp(405, { erro: "metodo" });

  const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const ANON     = Deno.env.get("SUPABASE_ANON_KEY")!;
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return resp(401, { erro: "nao autenticado" });

  // Identifica QUEM está chamando via o próprio JWT (não service_role — é um admin logado).
  const supaCaller = createClient(SUPA_URL, ANON, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: errUser } = await supaCaller.auth.getUser();
  if (errUser || !user) return resp(401, { erro: "sessao invalida" });

  let body: any;
  try { body = await req.json(); } catch { return resp(400, { erro: "payload" }); }
  const { tenant_id, nome, email, perfil } = body;
  if (!tenant_id || !nome || !email || !perfil) {
    return resp(400, { erro: "tenant_id, nome, email e perfil sao obrigatorios" });
  }
  if (!["adm", "vet", "cab"].includes(perfil)) return resp(400, { erro: "perfil invalido" });
  if (!RESEND_API_KEY) return resp(500, { erro: "RESEND_API_KEY nao configurado" });

  const supa = createClient(SUPA_URL, SERVICE);

  // Autorização: só admin ATIVO do próprio tenant pode convidar.
  const { data: membership } = await supa.from("tenant_memberships")
    .select("perfil, ativo").eq("user_id", user.id).eq("tenant_id", tenant_id).maybeSingle();
  if (!membership?.ativo || membership.perfil !== "adm") {
    return resp(403, { erro: "somente administradores podem convidar usuarios" });
  }

  const { data: tenant } = await supa.from("tenants")
    .select("schema_name, nome_cabanha, nome_exibicao, plano_id").eq("id", tenant_id).maybeSingle();
  if (!tenant) return resp(404, { erro: "cabanha nao encontrada" });
  const nomeCab = tenant.nome_exibicao || tenant.nome_cabanha;

  // Limite de usuários do plano (2026-08-29): antes disso não existia nenhuma checagem —
  // max_usuarios era só texto de marketing na landing/checkout, sem bloqueio real.
  // -1/null = ilimitado. Conta só membership ATIVA (removido não ocupa vaga).
  const { data: planoRow } = await supa.from("planos").select("max_usuarios").eq("id", tenant.plano_id).maybeSingle();
  const maxUsuarios = planoRow?.max_usuarios;
  if (typeof maxUsuarios === "number" && maxUsuarios >= 0) {
    const { count } = await supa.from("tenant_memberships")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", tenant_id).eq("ativo", true);
    if ((count ?? 0) >= maxUsuarios) {
      return resp(403, { erro: `Seu plano permite no máximo ${maxUsuarios} usuário(s) ativo(s). Faça upgrade de plano pra convidar mais gente.` });
    }
  }

  try {
    // 1) Identidade no Auth — cria ou reaproveita (multi-cabanha)
    let authUserId: string;
    let identidadeNova = false;
    const criaRes = await fetch(`${SUPA_URL}/auth/v1/admin/users`, {
      method: "POST",
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: `${crypto.randomUUID()}${crypto.randomUUID()}`, email_confirm: true }),
    });
    if (criaRes.ok) {
      authUserId = (await criaRes.json()).id;
      identidadeNova = true;
    } else {
      const { data: achado } = await supa.rpc("buscar_auth_user_por_email", { p_email: email });
      if (!achado) return resp(502, { erro: "falha ao criar/localizar identidade", detalhe: await criaRes.text() });
      authUserId = achado as string;

      // A identidade já existia, mas isso não quer dizer que a pessoa tenha uma senha
      // de verdade — se o convite/link anterior nunca foi concluído (ex.: expirou antes
      // de definir a senha), last_sign_in_at continua null pra sempre. Nesse caso trate
      // como se fosse identidade nova pro e-mail (manda código de novo, em vez de "use a
      // senha que você já tem" — que nunca existiu).
      const getRes = await fetch(`${SUPA_URL}/auth/v1/admin/users/${authUserId}`, {
        headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}` },
      });
      if (getRes.ok) {
        const u = await getRes.json();
        if (!u.last_sign_in_at) identidadeNova = true;
      }
    }

    // 2) Já é membro desta cabanha? — distingue membership ATIVA com identidade que já
    // fez login de verdade (bloqueia, evita duplicar convite) de dois outros casos que
    // devem seguir em frente sem travar: membership INATIVA (pessoa removida antes —
    // reativa) e membership ATIVA mas identidade "pendente" (identidadeNova=true — foi
    // convidada, mas nunca completou o primeiro login porque o código/link anterior
    // expirou; trata como reenvio, sem duplicar membership/linha local).
    const { data: membroExistente } = await supa.from("tenant_memberships")
      .select("id, ativo").eq("user_id", authUserId).eq("tenant_id", tenant_id).maybeSingle();
    if (membroExistente?.ativo && !identidadeNova) {
      return resp(409, { erro: "este usuario ja tem acesso a esta cabanha" });
    }

    // 3) Membership: reativa a linha existente (revogada antes) ou cria uma nova.
    // Se já está ativa e pendente (caso do reenvio), não mexe — só falta reenviar o e-mail.
    if (membroExistente && !membroExistente.ativo) {
      const { error: errM } = await supa.from("tenant_memberships")
        .update({ ativo: true, perfil }).eq("id", membroExistente.id);
      if (errM) throw new Error(`Reativar membership: ${errM.message}`);
    } else if (!membroExistente) {
      const { error: errM } = await supa.from("tenant_memberships")
        .insert({ user_id: authUserId, tenant_id, perfil, ativo: true });
      if (errM) throw new Error(`Membership: ${errM.message}`);
    }

    const { error: errV } = await supa.rpc("vincular_usuario_cabanha", {
      p_schema: tenant.schema_name, p_nome: nome, p_email: email, p_perfil: perfil, p_auth_user_id: authUserId,
    });
    if (errV) throw new Error(`Vincular usuario: ${errV.message}`);

    // 4) E-mail — código de definir senha (identidade nova/pendente) ou aviso simples (já tinha conta de verdade)
    const perfilLabel = PERFIL_LABEL[perfil] || perfil;
    let subject: string, html: string;
    if (identidadeNova) {
      // Só o código, sem link clicável: descobrimos que os dois compartilham o MESMO
      // token por baixo — visitar o link (inclusive por um scanner automático de
      // segurança corporativa) invalida o código, e vice-versa. Mandar os dois "como
      // alternativa" não dá redundância nenhuma, só um jeito de um deles ser gasto sem
      // querer antes da pessoa usar o outro. Só o código evita esse problema de vez,
      // já que nenhum scanner de e-mail "digita" um código dentro do corpo do e-mail.
      const { codigo } = await gerarLinkRecovery(SUPA_URL, SERVICE, email, REDIRECT_TO);
      html = layout(`
        <p style="margin:0 0 16px;">Olá! Você foi convidado(a) por um administrador para acessar a cabanha
        <strong>${esc(nomeCab)}</strong> na Mimba, como <strong>${esc(perfilLabel)}</strong>.</p>
        <p style="margin:0 0 4px;">Para o primeiro acesso, acesse <strong>${esc(APP_URL.replace(/^https?:\/\//, ""))}</strong>, clique em
        "Tenho um código de acesso" e digite o código abaixo. Seu login será o e-mail <strong>${esc(email)}</strong>.</p>
        ${blocoCodigo(codigo)}
        ${botao(`${APP_URL}/?acesso=codigo`, "Ir para a Mimba")}
        <p style="margin:20px 0 0;color:${SUAVE};font-size:13px;">O código é pessoal e tem validade limitada.</p>`);
      subject = `Você foi convidado para a cabanha ${nomeCab} na Mimba`;
    } else {
      html = layout(`
        <p style="margin:0 0 16px;">Olá! A cabanha <strong>${esc(nomeCab)}</strong> foi adicionada à sua conta Mimba
        (<strong>${esc(email)}</strong>), como <strong>${esc(perfilLabel)}</strong>.</p>
        <p style="margin:0 0 8px;">Não há senha nova: entre com a <strong>senha que você já usa</strong>. Ao acessar, a cabanha aparecerá no seletor de cabanhas.</p>
        ${botao(APP_URL, "Acessar a Mimba")}`);
      subject = `A cabanha ${nomeCab} foi adicionada à sua conta Mimba`;
    }

    try {
      await enviarEmail(email, subject, html, RESEND_API_KEY);
    } catch (eMail) {
      // Usuário/membership já foram criados — não desfazer por falha de e-mail.
      // Devolve sucesso parcial pro admin saber que precisa reenviar/avisar manualmente.
      const msg = eMail instanceof Error ? eMail.message : String(eMail);
      return resp(207, { sucesso: true, email_enviado: false, identidade_nova: identidadeNova, aviso: "Usuário criado, mas o e-mail falhou.", erro_email: msg });
    }

    return resp(200, { sucesso: true, email_enviado: true, identidade_nova: identidadeNova });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return resp(500, { erro: msg });
  }
});
