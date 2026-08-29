-- GAP achado testando o agente ao vivo (2026-08-28): perguntado "relatório dos animais
-- por estágio", o agente não tinha nenhuma ferramenta pra isso e respondeu confundindo
-- "estágio de atividade" (campo animais.estagio -- CAMPO, CRIA, PISTA MORFOLOGIA, ARREIO
-- CABANHA, PISTA FUNCIONAL, LAÇO etc., o mesmo dado do card "Estágio / atividade" do
-- Dashboard) com "estágio de confirmação na ABCCC" (situação de registro), que é outra
-- coisa. Sem ferramenta certa, ele inventou a resposta errada com dado real mas do campo
-- errado -- não é alucinação de nome, mas é resposta factualmente errada pra pergunta feita.
--
-- Mesmo padrão de cab_resumo_geral/cab_buscar_animal: SECURITY DEFINER, tem_acesso_tenant,
-- schema dinâmico, só animais ativos (ativo=true), agrupado por estagio.

create or replace function public.cab_agrupar_por_estagio(p_tenant_id uuid)
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
    $q$select coalesce(jsonb_agg(t order by t.total desc), '[]'::jsonb) from (
       select coalesce(estagio, 'Sem estágio definido') as estagio, count(*) as total
       from %I.animais
       where ativo = true
       group by estagio
     ) t$q$,
    v_schema
  ) into v_resultado;

  return v_resultado;
end;
$$;

comment on function public.cab_agrupar_por_estagio(uuid) is
  'RPC read-only pro agente de IA: contagem de animais ativos agrupada por estágio de atividade (CAMPO, CRIA, PISTA MORFOLOGIA etc.) -- mesmo dado do card "Estágio / atividade" do Dashboard. Não confundir com situação de confirmação ABCCC.';

revoke execute on function public.cab_agrupar_por_estagio(uuid) from public, anon;
grant execute on function public.cab_agrupar_por_estagio(uuid) to authenticated;
