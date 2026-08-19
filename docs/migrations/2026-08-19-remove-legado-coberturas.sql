-- Remove por completo a tabela legada `coberturas_arquivadas_legado` (aba "Legado" do
-- Reprodutivo, descontinuada). Único uso real restante era a Cabanha Mãe de Deus (Luciano),
-- que tinha 4 gestações ativas presas no fluxo antigo — já migradas pro sistema vigente
-- (fontes_cobertura + acasalamentos + gestacoes) numa query separada antes desta migration
-- (não precisa repetir aqui, já rodou). A cabanha de teste do Pedro tinha 2 registros de
-- fixture, descartados (não eram dado real).
--
-- Achados na investigação:
-- - `provisionar_schema_cabanha()` já NÃO inclui essa tabela no array `v_tabelas` — cabanhas
--   provisionadas de algum ponto em diante já nascem sem ela. Não precisa mexer na RPC de
--   provisionamento.
-- - `carregar_dados_cabanha()` (RPC de bootstrap) ainda selecionava dela (`v_cob`, chave
--   'coberturas' no jsonb) — removido nesta migration.
-- - Nenhuma FK de outra tabela aponta pra ela (verificado via pg_constraint) — DROP TABLE
--   direto é seguro, sem cascade em dado de terceiros.

-- 1) Bootstrap RPC — recriada sem a leitura da tabela legada.
create or replace function public.carregar_dados_cabanha(p_tenant_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_schema text;
  v_animais jsonb; v_vac jsonb; v_exam jsonb; v_verm jsonb;
  v_med jsonb; v_evt jsonb; v_est jsonb; v_mov jsonb; v_lanc jsonb; v_pend jsonb; v_usr jsonb;
  v_fontes jsonb; v_acasal jsonb; v_tent jsonb; v_gest jsonb; v_prot jsonb; v_protap jsonb; v_negoc jsonb;
  v_estagios jsonb; v_ativ jsonb; v_trat jsonb;
begin
  if not (select public.tem_acesso_tenant(p_tenant_id)) then
    raise exception 'sem acesso a esta cabanha';
  end if;

  select schema_name into v_schema from public.tenants where id = p_tenant_id;
  if v_schema is null then
    raise exception 'cabanha nao encontrada';
  end if;

  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.animais where ativo=true order by nome) t', v_schema) into v_animais;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.vacinacoes order by data desc) t', v_schema) into v_vac;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.exames order by data desc) t', v_schema) into v_exam;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.vermifugacoes order by data desc) t', v_schema) into v_verm;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.medidas order by data desc) t', v_schema) into v_med;
  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (
       select e.*, coalesce((select jsonb_agg(ea) from %I.eventos_animais ea where ea.evento_id = e.id), ''[]''::jsonb) as eventos_animais
       from %I.eventos e order by e.data desc
     ) t', v_schema, v_schema) into v_evt;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.estoque_itens where ativo=true order by nome) t', v_schema) into v_est;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.estoque_movimentos order by criado_em desc limit 500) t', v_schema) into v_mov;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.lancamentos order by data desc limit 1000) t', v_schema) into v_lanc;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.pendencias where resolvida=false order by gerada_em desc) t', v_schema) into v_pend;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select id,login,senha_hash,nome,perfil,ativo,criado_em,auth_user_id,especialidade_reproducao from %I.usuarios order by nome) t', v_schema) into v_usr;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.fontes_cobertura order by criado_em desc) t', v_schema) into v_fontes;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.acasalamentos order by criado_em desc) t', v_schema) into v_acasal;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.tentativas order by data desc) t', v_schema) into v_tent;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.gestacoes order by data_confirmacao desc) t', v_schema) into v_gest;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.protocolos_reproducao where ativo=true order by nome) t', v_schema) into v_prot;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.protocolo_aplicado order by criado_em desc) t', v_schema) into v_protap;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.coberturas_negociadas order by criado_em desc) t', v_schema) into v_negoc;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.reproducao_estagios order by criado_em desc) t', v_schema) into v_estagios;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.reproducao_atividades order by data desc) t', v_schema) into v_ativ;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.tratamentos order by data_inicio desc) t', v_schema) into v_trat;

  return jsonb_build_object(
    'animais', v_animais, 'vacinacoes', v_vac, 'exames', v_exam, 'vermifugacoes', v_verm,
    'medidas', v_med, 'eventos', v_evt, 'estoque_itens', v_est,
    'estoque_movimentos', v_mov, 'lancamentos', v_lanc, 'pendencias', v_pend, 'usuarios', v_usr,
    'fontes_cobertura', v_fontes, 'acasalamentos', v_acasal, 'tentativas', v_tent, 'gestacoes', v_gest,
    'protocolos_reproducao', v_prot, 'protocolo_aplicado', v_protap, 'coberturas_negociadas', v_negoc,
    'reproducao_estagios', v_estagios, 'reproducao_atividades', v_ativ, 'tratamentos', v_trat
  );
end;
$function$;

-- 2) Dropar a tabela do template + de todos os schemas de cabanha já provisionados.
drop table if exists public.coberturas_arquivadas_legado cascade;

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('drop table if exists %I.coberturas_arquivadas_legado cascade', r.schema_name);
  end loop;
end $$;
