-- BUG CRITICO achado testando o agente ao vivo (2026-08-28): abccc_sangues_animal
-- consultava public.sangues_linhagem (o TEMPLATE, sempre vazio por design --
-- cab_* e que tem o dado real de cada tenant) em vez do schema da cabanha do
-- usuario. Resultado: a ferramenta SEMPRE retornava null pra qualquer SBB, em
-- qualquer cabanha -- silenciosamente, sem erro. Isso empurrava o modelo a
-- "preencher a lacuna" sozinho quando as duas fontes de genealogia pareciam
-- vazias, e foi pego em flagrante inventando uma linha_baixa fabricada
-- (nome de outro animal real do Lab, colado como se fosse a mae de um
-- animal diferente).
--
-- Corrigido pro mesmo padrao de cab_buscar_animal: SECURITY DEFINER,
-- tem_acesso_tenant, resolve o schema real da cabanha, EXECUTE dinamico.

create or replace function public.abccc_sangues_animal(p_tenant_id uuid, p_sbb text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
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
    $q$select jsonb_build_object(
         'sbb', animal_sbb, 'pai', pai, 'mae', mae,
         'avo_paterno', avo_paterno, 'avo_materno', avo_materno,
         'total_ancestrais', jsonb_array_length(coalesce(ancestrais, '[]'::jsonb)),
         'consultado_em', consultado_em
       )
       from %I.sangues_linhagem
       where animal_sbb = upper(trim($1)) and erro is null$q$,
    v_schema
  ) into v_resultado using p_sbb;

  return v_resultado;
end;
$$;

comment on function public.abccc_sangues_animal is
  'RPC read-only pro agente de IA: pedigree cru por SBB, lido do schema REAL da '
  'cabanha do usuario (nao do template public). Corrigido 2026-08-28 -- versao '
  'anterior lia public.sangues_linhagem (sempre vazio) e nunca funcionou.';

-- Mesmo padrao de revoke/grant das outras RPCs do agente (Postgres da EXECUTE
-- a PUBLIC por padrao em funcao nova).
revoke execute on function public.abccc_sangues_animal(uuid, text) from public, anon;
grant execute on function public.abccc_sangues_animal(uuid, text) to authenticated;

-- Assinatura antiga (so p_sbb, sem tenant) -- dropada de vez, nao so deixada
-- orfa. Achado na revisao de isolamento (2026-08-28): essa funcao tinha
-- EXECUTE aberto pra `anon` (proacl mostrava anon=X/postgres) e nunca passou
-- pelo padrao de revoke das outras RPCs do agente -- inofensiva enquanto
-- public.sangues_linhagem ficar vazia (garantia de convencao, nao de schema),
-- mas e uma bomba-relogio desnecessaria deixar viva. O Edge Function
-- (supabase/functions/agente-ia/index.ts) ja foi atualizado pra chamar so a
-- assinatura nova, com p_tenant_id, nesta mesma janela de deploy.
drop function if exists public.abccc_sangues_animal(text);
