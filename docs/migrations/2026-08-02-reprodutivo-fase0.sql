-- Fase 0 da spec docs/spec-reprodutivo-v3.md — fundação de banco.
-- Gerado por Claude, NÃO aplicado automaticamente (regra do projeto: MCP gera, humano aplica no SQL Editor).
-- Revisão de isolamento pendente antes de aplicar (mexe em provisionamento — provisionar_schema_cabanha).
--
-- O que faz:
--   1. animais.confirmado (novo campo, sem bloqueio de idade — só UI vai avisar)
--   2. fontes_cobertura.demerito (novo campo, independente de tem_rm)
--   3. _calc_ciclo_texto: corte de ciclo passa de agosto pra julho
--   4. encerrar_ciclo_reproducao: soma bônus de tem_rm (+30) e demerito (+120) na renovação automática
--      do saldo por ciclo (default: empilha os dois — ver nota no fim do arquivo se quiser mudar)
--   5. Arquiva a tabela legada "coberturas" em cada cab_* existente (rename, sem apagar dado)
--   6. Remove 'coberturas' do array de tabelas clonadas em provisionar_schema_cabanha
--      (senão cabanhas novas quebrariam tentando clonar uma tabela que não existe mais no template)

begin;

-- ============================================================================
-- 1) animais.confirmado — template + todos os tenants existentes
-- ============================================================================
alter table public.animais add column if not exists confirmado boolean not null default false;

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.animais add column if not exists confirmado boolean not null default false', r.schema_name);
  end loop;
end $$;

-- ============================================================================
-- 2) fontes_cobertura.demerito — template + todos os tenants existentes
-- ============================================================================
alter table public.fontes_cobertura add column if not exists demerito boolean not null default false;

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.fontes_cobertura add column if not exists demerito boolean not null default false', r.schema_name);
  end loop;
end $$;

-- ============================================================================
-- 3) _calc_ciclo_texto — corte de ciclo: agosto -> julho
-- ============================================================================
create or replace function public._calc_ciclo_texto(p_data date)
 returns text
 language sql
 immutable
as $function$
  select case when extract(month from p_data) >= 7
    then lpad((extract(year from p_data)::int % 100)::text, 2, '0') || '/' || lpad(((extract(year from p_data)::int + 1) % 100)::text, 2, '0')
    else lpad(((extract(year from p_data)::int - 1) % 100)::text, 2, '0') || '/' || lpad((extract(year from p_data)::int % 100)::text, 2, '0')
  end;
$function$;

-- ============================================================================
-- 4) encerrar_ciclo_reproducao — soma o bônus de demerito (+120) ao de tem_rm (+30),
--    base 120. Único ajuste desta função nesta migration; resto do corpo é idêntico
--    ao que já está em produção.
-- ============================================================================
create or replace function public.encerrar_ciclo_reproducao()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  r record;
  v_ciclo_novo text := public._calc_ciclo_texto(current_date);
  v_vencidas int; v_cancelados int; v_recriadas int; v_cota_vencidas int;
  v_total_vencidas int := 0; v_total_cancelados int := 0; v_total_recriadas int := 0; v_total_cota int := 0;
begin
  for r in select id as tenant_id, schema_name, nome_exibicao
           from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    -- 1. Fontes de garanhão próprio com saldo > 0: vencem (saldo = adquirida - confirmadas - negociadas aceitas/quitadas)
    execute format($f$
      update %I.fontes_cobertura f set status = 'vencida', atualizado_em = now()
      where f.tipo = 'proprio' and f.status = 'ativa'
        and (
          f.quantidade_adquirida
          - coalesce((select count(*) from %I.acasalamentos a where a.fonte_cobertura_id = f.id and a.status = 'confirmado'), 0)
          - coalesce((select sum(n.quantidade) from %I.coberturas_negociadas n where n.fonte_cobertura_id = f.id and n.status in ('aceito','quitado')), 0)
        ) > 0
    $f$, r.schema_name, r.schema_name, r.schema_name);
    get diagnostics v_vencidas = row_count;

    -- 2. Acasalamentos em_curso sem confirmação: cancelados por encerramento de ciclo
    execute format($f$
      update %I.acasalamentos set status = 'cancelado', motivo_cancelamento = 'Encerramento de ciclo', atualizado_em = now()
      where status = 'em_curso'
    $f$, r.schema_name);
    get diagnostics v_cancelados = row_count;

    -- 3. Fontes de garanhão próprio: recria pro ciclo novo com limite vigente
    --    (120 base, +30 se tem_rm, +120 se demerito — bônus empilham), só se ainda
    --    não existir uma fonte própria do mesmo garanhão nesse ciclo (evita duplicar em reexecução)
    execute format($f$
      insert into %I.fontes_cobertura (tipo, garanhao_nome, garanhao_sbb, tem_rm, demerito, quantidade_adquirida, ciclo, status, obs)
      select 'proprio', f.garanhao_nome, f.garanhao_sbb, f.tem_rm, f.demerito,
             120 + (case when f.tem_rm then 30 else 0 end) + (case when f.demerito then 120 else 0 end),
             %L, 'ativa',
             'Renovada automaticamente no encerramento de ciclo'
      from %I.fontes_cobertura f
      where f.tipo = 'proprio'
        and not exists (
          select 1 from %I.fontes_cobertura f2
          where f2.tipo = 'proprio' and f2.ciclo = %L
            and coalesce(f2.garanhao_sbb, f2.garanhao_nome) = coalesce(f.garanhao_sbb, f.garanhao_nome)
        )
      group by f.garanhao_nome, f.garanhao_sbb, f.tem_rm, f.demerito
    $f$, r.schema_name, v_ciclo_novo, r.schema_name, r.schema_name, v_ciclo_novo);
    get diagnostics v_recriadas = row_count;

    -- 4. Cota / direito de uso com vigência expirada: vencem
    execute format($f$
      update %I.fontes_cobertura set status = 'vencida', atualizado_em = now()
      where tipo in ('cota','direito_uso') and status = 'ativa'
        and vigencia_fim is not null and vigencia_fim < current_date
    $f$, r.schema_name);
    get diagnostics v_cota_vencidas = row_count;

    insert into public.webhook_log (evento, tenant_id, payload, processado)
    values ('encerramento_ciclo_reproducao', r.tenant_id,
      jsonb_build_object('ciclo_novo', v_ciclo_novo, 'fontes_vencidas', v_vencidas,
                          'acasalamentos_cancelados', v_cancelados, 'fontes_recriadas', v_recriadas,
                          'cota_direito_uso_vencidas', v_cota_vencidas),
      true);

    v_total_vencidas := v_total_vencidas + v_vencidas;
    v_total_cancelados := v_total_cancelados + v_cancelados;
    v_total_recriadas := v_total_recriadas + v_recriadas;
    v_total_cota := v_total_cota + v_cota_vencidas;
  end loop;

  return jsonb_build_object(
    'ciclo_novo', v_ciclo_novo, 'tenants_processados',
    (select count(*) from public.tenants where provisionado = true),
    'total_fontes_vencidas', v_total_vencidas, 'total_acasalamentos_cancelados', v_total_cancelados,
    'total_fontes_recriadas', v_total_recriadas, 'total_cota_direito_uso_vencidas', v_total_cota
  );
end;
$function$;

-- ============================================================================
-- 5) Arquiva a tabela legada "coberturas" em cada tenant existente (rename, sem apagar)
-- ============================================================================
do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    if exists (
      select 1 from information_schema.tables
      where table_schema = r.schema_name and table_name = 'coberturas'
    ) then
      execute format('alter table %I.coberturas rename to coberturas_arquivadas_legado', r.schema_name);
    end if;
  end loop;
end $$;

-- Template public.coberturas está sempre vazio (é o molde) — pode só renomear por
-- consistência; novas cabanhas não vão mais recebê-la de qualquer forma (item 6).
alter table if exists public.coberturas rename to coberturas_arquivadas_legado;

-- ============================================================================
-- 6) provisionar_schema_cabanha — tira 'coberturas' do array de tabelas clonadas
--    (cabanhas NOVAS não nascem mais com essa tabela; dado legado das antigas
--    continua intacto, só renomeado no passo 5 acima)
-- ============================================================================
create or replace function public.provisionar_schema_cabanha(p_schema text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_tenant  uuid;
  t         text;
  trg       record;
  v_tabelas text[] := array[
    'usuarios','animais','vacinacoes','exames','vermifugacoes','medidas',
    'fontes_cobertura','acasalamentos','tentativas','gestacoes',
    'protocolos_reproducao','protocolo_aplicado','coberturas_negociadas',
    'eventos','eventos_animais','estoque_itens','estoque_movimentos',
    'lancamentos','pendencias','nutricao_itens','nutricao_projetos',
    'sangues_linhagem','animal_midia','audit_log'];
begin
  select id into v_tenant from public.tenants where schema_name = p_schema;
  if v_tenant is null then
    raise exception 'Tenant inexistente para o schema % (crie a linha em public.tenants antes)', p_schema;
  end if;

  execute format('create schema if not exists %I', p_schema);

  foreach t in array v_tabelas loop
    execute format('drop table if exists %I.%I cascade', p_schema, t);
    execute format('create table %I.%I (like public.%I including all)', p_schema, t, t);
    execute format('alter table %I.%I enable row level security', p_schema, t);
  end loop;

  execute format('alter table %I.gestacoes add constraint gestacoes_protocolo_aplicado_id_fkey foreign key (protocolo_aplicado_id) references %I.protocolo_aplicado(id)', p_schema, p_schema);

  execute format('create sequence if not exists %I.audit_log_id_seq owned by %I.audit_log.id', p_schema, p_schema);
  execute format('alter table %I.audit_log alter column id set default nextval(%L)', p_schema, p_schema || '.audit_log_id_seq');

  foreach t in array v_tabelas loop
    if t = 'audit_log' then
      execute format('create policy memb_read on %I.audit_log for select to authenticated using ((select public.tem_acesso_tenant(%L)))', p_schema, v_tenant);
      execute format('create policy memb_insert on %I.audit_log for insert to authenticated with check (false)', p_schema);
    else
      execute format('create policy memb_all on %I.%I for all to authenticated using ((select public.tem_acesso_tenant(%L))) with check ((select public.tem_acesso_tenant(%L)))', p_schema, t, v_tenant, v_tenant);
    end if;
  end loop;

  for trg in
    select c.relname as tabela, pg_get_triggerdef(tg.oid) as def
    from pg_trigger tg
    join pg_class c on c.oid = tg.tgrelid and c.relnamespace = 'public'::regnamespace
    where not tg.tgisinternal and c.relname = any(v_tabelas)
  loop
    execute replace(trg.def,
                    format(' ON public.%I ', trg.tabela),
                    format(' ON %I.%I ', p_schema, trg.tabela));
  end loop;

  execute format('grant usage on schema %I to authenticated', p_schema);
  execute format('grant select, insert, update, delete on all tables in schema %I to authenticated', p_schema);
  execute format('grant usage, select on all sequences in schema %I to authenticated', p_schema);
  execute format('revoke all privileges on all tables in schema %I from anon', p_schema);

  return jsonb_build_object('schema', p_schema, 'tenant_id', v_tenant,
                            'tabelas', array_length(v_tabelas,1), 'status', 'concluido');
exception when others then
  raise exception 'Erro ao provisionar %: %', p_schema, sqlerrm;
end;
$function$;

commit;

-- ============================================================================
-- Verificação sugerida após aplicar:
-- ============================================================================
-- select confirmado from cab_<algum_schema>.animais limit 1;
-- select demerito from cab_<algum_schema>.fontes_cobertura limit 1;
-- select public._calc_ciclo_texto('2026-07-01'::date);  -- esperado: '26/27'
-- select public._calc_ciclo_texto('2026-06-30'::date);  -- esperado: '25/26'
-- select table_name from information_schema.tables where table_schema = 'cab_<algum_schema>' and table_name like 'coberturas%';
--   (esperado: só 'coberturas_arquivadas_legado', não 'coberturas')
--
-- Nota sobre o bônus de tem_rm + demerito: o padrão escolhido acima EMPILHA os dois
-- (120 base, +30 tem_rm, +120 demerito = até 270 coberturas/ano). Se a intenção real
-- for "o maior teto já cobre tudo" (240 fixo quando demerito, ignorando tem_rm), troque
-- a expressão da soma no passo 4 antes de aplicar.
