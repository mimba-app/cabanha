-- Corrige o RPC de bootstrap do login (`carregar_dados_cabanha`) estourando
-- statement_timeout do Postgres — confirmado via logs (`canceling statement due
-- to statement timeout`, recorrente hoje pra Cabanha Mãe de Deus). A função faz
-- ~20 queries sequenciais, uma por tabela, dentro de uma única chamada; a maioria
-- agrega a tabela do tenant inteira em JSON sem limite nenhum. `lancamentos`
-- (limit 1000) e `estoque_movimentos` (limit 500) já tinham essa proteção — mas
-- vacinacoes, exames, vermifugacoes, medidas e eventos não tinham, e são
-- exatamente as tabelas que mais crescem com o uso normal da cabanha (um
-- registro por vacina/exame/medição/evento, por animal, ao longo dos anos).
--
-- Trade-off consciente: como o bootstrap ainda é a única fonte hoje pra
-- histVacinas/histExames/medidas/eventosEsp no frontend (sem endpoint separado
-- de histórico paginado por animal), limitar corta os registros mais antigos
-- que excederem o teto — não corta por animal, corta pelo total do tenant,
-- ordenado do mais recente pro mais antigo. Os limites abaixo são generosos o
-- bastante pra não afetar o uso normal de uma cabanha ativa; se algum dia
-- alguma delas voltar a aproximar do teto, o path certo é criar um RPC de
-- histórico sob demanda por animal (fora do escopo deste hotfix) em vez de só
-- subir o número aqui.
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
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.vacinacoes order by data desc limit 3000) t', v_schema) into v_vac;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.exames order by data desc limit 3000) t', v_schema) into v_exam;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.vermifugacoes order by data desc limit 3000) t', v_schema) into v_verm;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I.medidas order by data desc limit 3000) t', v_schema) into v_med;
  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (
       select e.*, coalesce((select jsonb_agg(ea) from %I.eventos_animais ea where ea.evento_id = e.id), ''[]''::jsonb) as eventos_animais
       from %I.eventos e order by e.data desc limit 1000
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
