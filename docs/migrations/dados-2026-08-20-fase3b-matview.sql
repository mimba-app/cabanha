-- ============================================================================
-- Área de Dados — Fase 3b: materializa a projeção tipada da ABCCC
-- ============================================================================
-- Motivo: as análises liam a view `vw_abccc_resultados`, que extrai 10 campos
-- jsonb de 83k linhas a cada consulta — medido em ~770ms por chamada, lento
-- demais pra uma tela com vários painéis. Materializando: ~357ms.
--
-- ⚠️ Materialized view NÃO respeita RLS. Por isso ela não tem grant pra
-- ninguém — só as funções SECURITY DEFINER (que fazem o próprio controle de
-- acesso) a leem. Se um dia alguém der `grant select ... to authenticated`,
-- todo usuário logado passa a ler a base inteira direto pelo PostgREST.
--
-- A view `vw_abccc_resultados` continua existindo (security_invoker=true, logo
-- respeita RLS) pra consulta ad-hoc de staff.
--
-- Precisa de REFRESH depois de cada carga — feito por abccc_atualizar_analises(),
-- que o frontend chama ao final do upload e da importação da ABCCC.
-- ============================================================================

drop materialized view if exists public.mv_abccc_resultados;
create materialized view public.mv_abccc_resultados as
-- CORREÇÃO (incidente 19/08): r.id entra na projeção só para dar uma chave garantidamente
-- única à matview. `refresh ... concurrently` EXIGE um índice unique, e nenhuma combinação
-- das colunas de negócio é confiavelmente única (o mesmo animal pode repetir prova, ciclo,
-- cidade e colocação). r.id é a PK de dados_registros, então resolve sem inventar regra.
select r.id as registro_id,
       r.dados->>'SBB' as sbb, r.dados->>'Animal' as animal, r.dados->>'Sexo' as sexo,
       r.dados->>'Pai' as pai, r.dados->>'Mãe' as mae, r.dados->>'Criador' as criador,
       r.dados->>'Ciclo' as ciclo, r.dados->>'Cidade' as cidade, r.dados->>'Prova' as prova,
       r.dados->>'Colocação' as colocacao
from public.dados_registros r
join public.dados_datasets d on d.id = r.dataset_id
where d.tipo = 'resultados_abccc' and d.status = 'publicado';

-- CORREÇÃO: índice UNIQUE, pré-requisito do refresh concorrente.
create unique index mv_abccc_pk_idx on public.mv_abccc_resultados(registro_id);

create index mv_abccc_sbb_idx     on public.mv_abccc_resultados(sbb);
create index mv_abccc_pai_idx     on public.mv_abccc_resultados(pai);
create index mv_abccc_mae_idx     on public.mv_abccc_resultados(mae);
create index mv_abccc_ciclo_idx   on public.mv_abccc_resultados(ciclo);
create index mv_abccc_criador_idx on public.mv_abccc_resultados(criador);
create index mv_abccc_animal_idx  on public.mv_abccc_resultados(animal);

revoke all on public.mv_abccc_resultados from public, anon, authenticated;

create or replace function public.abccc_atualizar_analises()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v bigint;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  -- CORREÇÃO (incidente 19/08): CONCURRENTLY. O refresh normal pega ACCESS EXCLUSIVE na
  -- matview e bloqueia todo mundo que tentar lê-la enquanto reconstrói — com 83.778 linhas
  -- e 7 índices isso é bastante tempo de tabela travada. O concorrente troca isso por um
  -- refresh mais lento que não bloqueia leitor nenhum. Exige o índice unique acima.
  refresh materialized view concurrently public.mv_abccc_resultados;
  select count(*) into v from public.mv_abccc_resultados;
  return jsonb_build_object('linhas', v, 'atualizado_em', now());
end; $$;
revoke all on function public.abccc_atualizar_analises() from public, anon;
grant execute on function public.abccc_atualizar_analises() to authenticated;

-- ⚠️ Depois desta migration, as funções abccc_resumo / abccc_ranking / abccc_buscar /
-- ref_abccc_animal / ref_abccc_reprodutor foram recriadas trocando
-- `public.vw_abccc_resultados` por `public.mv_abccc_resultados`. O corpo delas está
-- em 2026-08-19-area-dados-fase3-analises.sql — a única diferença é esse nome.
