-- ============================================================================
-- Área de Dados — Fase 3: view tipada, índice de expressão e RPCs de análise
-- ============================================================================
-- Duas famílias de RPC, com públicos diferentes:
--   abccc_*  → staff Mimba (tela de Inteligência do Painel Mimba)
--   ref_*    → QUALQUER usuário logado, de qualquer cabanha. São o contrato de
--              consumo das funcionalidades do app (ficha do animal, Sangues...).
--              Só devolvem dado de referência público da ABCCC — nunca dado de tenant.
-- ============================================================================

create or replace view public.vw_abccc_resultados with (security_invoker = true) as
select r.dataset_id, r.linha,
       r.dados->>'SBB'        as sbb,
       r.dados->>'Animal'     as animal,
       r.dados->>'Sexo'       as sexo,
       r.dados->>'Pai'        as pai,
       r.dados->>'Mãe'        as mae,
       r.dados->>'Criador'    as criador,
       r.dados->>'Ciclo'      as ciclo,
       r.dados->>'Cidade'     as cidade,
       r.dados->>'Prova'      as prova,
       r.dados->>'Colocação'  as colocacao
from public.dados_registros r
join public.dados_datasets d on d.id = r.dataset_id
where d.tipo = 'resultados_abccc' and d.status = 'publicado';

-- Índice de expressão: pesa a premiação. Não é métrica oficial da ABCCC — é um
-- ranqueamento nosso, pra comparar reprodutores em pé de igualdade.
create or replace function public.abccc_pontos(p text) returns numeric
immutable language sql as $$
  select case p
    when 'GRANDE CAMPEÃ(O)'         then 10
    when 'RES. GRANDE CAMPEÃ(O)'    then 7
    when 'CAMPEÃ(O) CATEGORIA'      then 5
    when 'CAMPEÃO CATEGORIA'        then 5
    when '1º LUGAR'                 then 5
    when 'RES. CAMPEÃ(O) CATEGORIA' then 3
    when 'RES. CAMPEÃOO CATEGORIA'  then 3
    when '2º LUGAR'                 then 3
    when '3º LUGAR'                 then 2
    when '3º MELHOR'                then 2
    when '3º MELHOR CATEGORIA'      then 2
    when '4º LUGAR'                 then 1
    when '4º MELHOR'                then 1
    when '4º MELHOR CATEGORIA'      then 1
    else 0.5
  end;
$$;

create or replace function public.abccc_e_campeao(p text) returns boolean
immutable language sql as $$
  select p in ('GRANDE CAMPEÃ(O)','CAMPEÃ(O) CATEGORIA','CAMPEÃO CATEGORIA','1º LUGAR');
$$;

-- ─── Análises (staff) ───────────────────────────────────────────────────────
create or replace function public.abccc_resumo()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  select jsonb_build_object(
    'registros', count(*), 'animais', count(distinct sbb), 'reprodutores', count(distinct pai),
    'criadores', count(distinct criador), 'provas', count(distinct prova),
    'cidades', count(distinct cidade), 'ciclo_min', min(ciclo), 'ciclo_max', max(ciclo),
    'campeonatos', count(*) filter (where public.abccc_e_campeao(colocacao))
  ) into v from public.vw_abccc_resultados;
  return v;
end; $$;

-- p_dimensao: 'pai' | 'mae' | 'criador' | 'animal' | 'prova' | 'cidade'
create or replace function public.abccc_ranking(
  p_dimensao text default 'pai', p_ciclo_de text default null,
  p_ciclo_ate text default null, p_limite integer default 25
) returns table (
  nome text, premiacoes bigint, animais bigint, campeoes bigint,
  grandes_campeoes bigint, indice numeric
) language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  if p_dimensao not in ('pai','mae','criador','animal','prova','cidade') then
    raise exception 'dimensao invalida: %', p_dimensao;
  end if;
  return query
  select t.chave,
         count(*),
         count(distinct t.sbb),
         count(*) filter (where public.abccc_e_campeao(t.colocacao)),
         count(*) filter (where t.colocacao = 'GRANDE CAMPEÃ(O)'),
         round(sum(public.abccc_pontos(t.colocacao))::numeric, 1)
  from (
    select case p_dimensao when 'pai' then v.pai when 'mae' then v.mae
                           when 'criador' then v.criador when 'animal' then v.animal
                           when 'prova' then v.prova else v.cidade end as chave,
           v.sbb, v.colocacao
    from public.vw_abccc_resultados v
    where (p_ciclo_de  is null or v.ciclo >= p_ciclo_de)
      and (p_ciclo_ate is null or v.ciclo <= p_ciclo_ate)
  ) t
  where t.chave is not null and t.chave <> ''
  group by t.chave
  order by 6 desc, 2 desc
  limit least(coalesce(p_limite,25), 200);
end; $$;

create or replace function public.abccc_buscar(p_termo text, p_limite integer default 30)
returns table (sbb text, animal text, sexo text, pai text, mae text, criador text,
               premiacoes bigint, campeoes bigint, indice numeric)
language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  return query
  select v.sbb, max(v.animal), max(v.sexo), max(v.pai), max(v.mae), max(v.criador),
         count(*), count(*) filter (where public.abccc_e_campeao(v.colocacao)),
         round(sum(public.abccc_pontos(v.colocacao))::numeric,1)
  from public.vw_abccc_resultados v
  where v.animal ilike '%'||p_termo||'%' or v.sbb ilike '%'||p_termo||'%'
  group by v.sbb
  order by 9 desc
  limit least(coalesce(p_limite,30), 100);
end; $$;

-- ─── Consumo cross-tenant (qualquer cabanha) ────────────────────────────────
-- Ficha do animal: o que este SBB já ganhou.
create or replace function public.ref_abccc_animal(p_sbb text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'acesso negado'; end if;
  if p_sbb is null or btrim(p_sbb) = '' then return null; end if;
  select jsonb_build_object(
    'sbb', p_sbb,
    'animal', max(animal), 'sexo', max(sexo), 'pai', max(pai), 'mae', max(mae), 'criador', max(criador),
    'premiacoes', count(*),
    'campeonatos', count(*) filter (where public.abccc_e_campeao(colocacao)),
    'grandes_campeonatos', count(*) filter (where colocacao = 'GRANDE CAMPEÃ(O)'),
    'indice', round(sum(public.abccc_pontos(colocacao))::numeric,1),
    'ciclo_primeiro', min(ciclo), 'ciclo_ultimo', max(ciclo),
    'resultados', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'ciclo', x.ciclo, 'cidade', x.cidade, 'prova', x.prova, 'colocacao', x.colocacao)
             order by x.ciclo desc), '[]'::jsonb)
      from public.vw_abccc_resultados x where x.sbb = p_sbb)
  ) into v
  from public.vw_abccc_resultados where sbb = p_sbb;
  if (v->>'premiacoes')::int = 0 then return null; end if;
  return v;
end; $$;

-- Análise de sangue: força de um reprodutor pelo desempenho da progênie.
create or replace function public.ref_abccc_reprodutor(p_nome text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'acesso negado'; end if;
  if p_nome is null or btrim(p_nome) = '' then return null; end if;
  select jsonb_build_object(
    'nome', p_nome,
    'filhos_premiados', count(distinct sbb),
    'premiacoes', count(*),
    'campeonatos', count(*) filter (where public.abccc_e_campeao(colocacao)),
    'grandes_campeonatos', count(*) filter (where colocacao = 'GRANDE CAMPEÃ(O)'),
    'indice', round(sum(public.abccc_pontos(colocacao))::numeric,1),
    'ciclo_primeiro', min(ciclo), 'ciclo_ultimo', max(ciclo),
    'como', case when count(*) filter (where pai = p_nome) > 0 then 'pai' else 'mae' end,
    'melhores_filhos', (
      select coalesce(jsonb_agg(f), '[]'::jsonb) from (
        select jsonb_build_object('sbb', y.sbb, 'animal', max(y.animal),
                 'campeonatos', count(*) filter (where public.abccc_e_campeao(y.colocacao)),
                 'indice', round(sum(public.abccc_pontos(y.colocacao))::numeric,1)) as f
        from public.vw_abccc_resultados y
        where y.pai = p_nome or y.mae = p_nome
        group by y.sbb
        order by round(sum(public.abccc_pontos(y.colocacao))::numeric,1) desc
        limit 10) t)
  ) into v
  from public.vw_abccc_resultados where pai = p_nome or mae = p_nome;
  if (v->>'premiacoes')::int = 0 then return null; end if;
  return v;
end; $$;

revoke all on function public.abccc_resumo()                                from public, anon;
revoke all on function public.abccc_ranking(text,text,text,integer)         from public, anon;
revoke all on function public.abccc_buscar(text,integer)                    from public, anon;
revoke all on function public.ref_abccc_animal(text)                        from public, anon;
revoke all on function public.ref_abccc_reprodutor(text)                    from public, anon;
grant execute on function public.abccc_resumo()                        to authenticated;
grant execute on function public.abccc_ranking(text,text,text,integer) to authenticated;
grant execute on function public.abccc_buscar(text,integer)            to authenticated;
grant execute on function public.ref_abccc_animal(text)                to authenticated;
grant execute on function public.ref_abccc_reprodutor(text)            to authenticated;
