-- Agente de IA interno — Fase 1 (ADR 0006 + 0007), caso de uso 1 (dado da
-- própria cabanha) + infraestrutura de cota por tenant.
--
-- Três RPCs novas, read-only, tenant-scoped, seguindo exatamente o padrão já
-- validado em `carregar_dados_cabanha` (security definer, search_path fixo,
-- gate `tem_acesso_tenant` na primeira linha, `execute format(%I)` pra tocar o
-- schema do tenant) — são as "ferramentas" que a Edge Function `agente-ia` vai
-- expor pro tool-calling da Claude. O agente NUNCA monta SQL livre: só chama
-- essas RPCs nomeadas, exatamente como qualquer outra parte do app.
--
-- Mais uma tabela de controle (`uso_ia_mensal`, control-plane em `public`,
-- não por tenant) e uma RPC de incremento (`agente_ia_registrar_uso`) — a
-- Edge Function chama essa RPC antes de gastar uma chamada de LLM, e aborta
-- com 429 se a cota do plano (planos.features->>'cota_ia_mensal', default 50
-- se a chave não existir) já foi atingida no mês corrente.

-- ── cab_buscar_animal ────────────────────────────────────────────────────────
create or replace function public.cab_buscar_animal(p_tenant_id uuid, p_termo text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_schema text;
  v_resultado jsonb;
begin
  if not (select public.tem_acesso_tenant(p_tenant_id)) then
    raise exception 'sem acesso a esta cabanha';
  end if;

  select schema_name into v_schema from public.tenants where id = p_tenant_id;
  if v_schema is null then
    raise exception 'cabanha nao encontrada';
  end if;

  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (
       select id, nome, sbb, rp, sexo, nasc, pelagem, situacao, estagio, ativo
       from %I.animais
       where nome ilike ''%%'' || $1 || ''%%'' or sbb ilike ''%%'' || $1 || ''%%'' or rp ilike ''%%'' || $1 || ''%%''
       order by nome
       limit 10
     ) t', v_schema
  ) into v_resultado using p_termo;

  return v_resultado;
end;
$function$;

grant execute on function public.cab_buscar_animal(uuid, text) to authenticated;
revoke all on function public.cab_buscar_animal(uuid, text) from public, anon;

-- ── cab_listar_gestacoes_ativas ──────────────────────────────────────────────
create or replace function public.cab_listar_gestacoes_ativas(p_tenant_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_schema text;
  v_resultado jsonb;
begin
  if not (select public.tem_acesso_tenant(p_tenant_id)) then
    raise exception 'sem acesso a esta cabanha';
  end if;

  select schema_name into v_schema from public.tenants where id = p_tenant_id;
  if v_schema is null then
    raise exception 'cabanha nao encontrada';
  end if;

  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (
       select g.id, g.data_cobertura, g.data_confirmacao, g.parto_previsto, g.status,
              a.nome as egua_nome, a.sbb as egua_sbb
       from %I.gestacoes g
       left join %I.animais a on a.id = g.egua_id
       where g.status = ''gestando''
       order by g.parto_previsto nulls last
     ) t', v_schema, v_schema
  ) into v_resultado;

  return v_resultado;
end;
$function$;

grant execute on function public.cab_listar_gestacoes_ativas(uuid) to authenticated;
revoke all on function public.cab_listar_gestacoes_ativas(uuid) from public, anon;

-- ── cab_resumo_periodo ───────────────────────────────────────────────────────
-- Contagens agregadas no período — base do "resumo da semana"/"resumo do mês"
-- que o agente pode responder sem precisar trazer linha por linha.
create or replace function public.cab_resumo_periodo(p_tenant_id uuid, p_data_inicio date, p_data_fim date)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_schema text;
  v_nascimentos int4;
  v_coberturas int4;
  v_vacinas_aplicadas int4;
  v_vacinas_vencendo int4;
  v_exames_vencendo int4;
begin
  if not (select public.tem_acesso_tenant(p_tenant_id)) then
    raise exception 'sem acesso a esta cabanha';
  end if;

  select schema_name into v_schema from public.tenants where id = p_tenant_id;
  if v_schema is null then
    raise exception 'cabanha nao encontrada';
  end if;

  execute format('select count(*) from %I.animais where nasc between $1 and $2', v_schema)
    into v_nascimentos using p_data_inicio, p_data_fim;

  execute format('select count(*) from %I.tentativas where data between $1 and $2', v_schema)
    into v_coberturas using p_data_inicio, p_data_fim;

  execute format('select count(*) from %I.vacinacoes where data between $1 and $2', v_schema)
    into v_vacinas_aplicadas using p_data_inicio, p_data_fim;

  execute format('select count(*) from %I.animais where ativo=true and prox_vac between $1 and $2', v_schema)
    into v_vacinas_vencendo using p_data_inicio, p_data_fim;

  execute format('select count(*) from %I.animais where ativo=true and val_exame between $1 and $2', v_schema)
    into v_exames_vencendo using p_data_inicio, p_data_fim;

  return jsonb_build_object(
    'periodo', jsonb_build_object('inicio', p_data_inicio, 'fim', p_data_fim),
    'nascimentos', v_nascimentos,
    'coberturas_registradas', v_coberturas,
    'vacinas_aplicadas', v_vacinas_aplicadas,
    'vacinas_vencendo_no_periodo', v_vacinas_vencendo,
    'exames_vencendo_no_periodo', v_exames_vencendo
  );
end;
$function$;

grant execute on function public.cab_resumo_periodo(uuid, date, date) to authenticated;
revoke all on function public.cab_resumo_periodo(uuid, date, date) from public, anon;

-- ── Cota de uso mensal por tenant ────────────────────────────────────────────
create table if not exists public.uso_ia_mensal (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  mes date not null,
  contagem int4 not null default 0,
  atualizado_em timestamptz not null default now(),
  primary key (tenant_id, mes)
);

alter table public.uso_ia_mensal enable row level security;

drop policy if exists "service_role only" on public.uso_ia_mensal;
create policy "service_role only" on public.uso_ia_mensal
  for all
  using ((select auth.role()) = 'service_role');

revoke all on public.uso_ia_mensal from public, anon, authenticated;

-- RPC de incremento — chamada pela Edge Function com o JWT do usuário (não
-- service_role), mas a checagem de tenant é feita aqui, não por RLS na tabela
-- (a tabela em si é bloqueada até pra `authenticated`, só a RPC entra nela).
create or replace function public.agente_ia_registrar_uso(p_tenant_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_mes date := date_trunc('month', now())::date;
  v_contagem int4;
  v_cota int4;
begin
  if not (select public.tem_acesso_tenant(p_tenant_id)) then
    raise exception 'sem acesso a esta cabanha';
  end if;

  select coalesce((p.features->>'cota_ia_mensal')::int4, 50)
    into v_cota
  from public.tenants t
  join public.planos p on p.id = t.plano_id
  where t.id = p_tenant_id;

  v_cota := coalesce(v_cota, 50);

  insert into public.uso_ia_mensal (tenant_id, mes, contagem)
  values (p_tenant_id, v_mes, 1)
  on conflict (tenant_id, mes)
  do update set contagem = public.uso_ia_mensal.contagem + 1, atualizado_em = now()
  returning contagem into v_contagem;

  return jsonb_build_object('contagem', v_contagem, 'cota', v_cota, 'excedeu', v_contagem > v_cota);
end;
$function$;

grant execute on function public.agente_ia_registrar_uso(uuid) to authenticated;
revoke all on function public.agente_ia_registrar_uso(uuid) from public, anon;
