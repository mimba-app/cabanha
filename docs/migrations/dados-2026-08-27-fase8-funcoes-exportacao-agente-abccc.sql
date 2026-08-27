-- Funcoes de apoio ao job de sincronizacao periodica do agente Mimba (ADR 0009,
-- job em supabase/functions/sync-abccc-estatisticas/index.ts). Aplicadas no
-- Mimba Lab (njynlsugmvtuvcczmuld), NAO no projeto de producao -- o job so
-- chama estas RPCs via service_role e copia o resultado pra producao, nunca
-- faz JOIN cru de 88k linhas em JS (ver ADR 0010, isolamento producao<->Lab).
--
-- Versao final consolidada em 2026-08-27, apos duas correcoes empiricas:
-- 1. linha_baixa omite o avo materno quando o registro dele e so um "stub"
--    nunca resolvido pelo scraper (nome = sbb) -- regra de silencio na
--    ausencia, secao 3.2 da base de conhecimento.
-- 2. abccc_exportar_linhagens_em_alta usa PAI DIRETO (sbb_pai) dos finalistas
--    do ciclo mais recente, nao recorrencia pela arvore inteira de 5 geracoes
--    -- a versao "arvore inteira" testada primeiro sobrevalorizava fundadores
--    antigos (apareciam em quase toda arvore so por profundidade de
--    pedigree). A versao "pai direto" bate exatamente com os numeros ja
--    validados na base de conhecimento (Fantastico de Sao Pedro 28, Xeque
--    Mate da Boa Vista 16, Basco Veneno 16, Chamame Nochero 14 -- Morfologia
--    Expointer 2026).

create or replace function public.abccc_peso_colocacao(p_colocacao text, p_prova text)
returns text
language plpgsql
immutable
as $$
declare
  c text := upper(trim(coalesce(p_colocacao, '')));
  n int;
begin
  if c = '' then
    return 'baixo';
  end if;

  if p_prova = 'Doma de Ouro' and c ~ '^[0-9]+$' then
    n := c::int;
    if n = 1 then return 'muito_alto'; end if;
    if n between 2 and 4 then return 'alto'; end if;
    if n between 5 and 8 then return 'medio'; end if;
    return 'baixo';
  end if;

  case c
    when 'MELHOR EXEMPLAR DA RAÇA' then return 'maximo';
    when 'GRANDE CAMPEÃ(O)' then return 'muito_alto';
    when '1º LUGAR' then return 'muito_alto';
    when 'RES. GRANDE CAMPEÃ(O)' then return 'alto';
    when '2º LUGAR' then return 'alto';
    when '3º MELHOR' then return 'alto';
    when '4º MELHOR' then return 'alto';
    when '3º LUGAR' then return 'alto';
    when '4º LUGAR' then return 'alto';
    when 'CAMPEÃ(O) CATEGORIA' then return 'medio';
    when 'RES. CAMPEÃ(O) CATEGORIA' then return 'medio';
    when '3º MELHOR CATEGORIA' then return 'medio';
    when '4º MELHOR CATEGORIA' then return 'medio';
    when '5º LUGAR' then return 'medio';
    when '6º LUGAR' then return 'medio';
    when '7º LUGAR' then return 'medio';
    when '8º LUGAR' then return 'medio';
    else return 'baixo';
  end case;
end;
$$;

comment on function public.abccc_peso_colocacao is
  'Mapeia texto de colocacao (resultados_competitivos.colocacao) pro peso de narrativa '
  'da secao 6 de docs/agente-ia-base-conhecimento-abccc.md. Numero de inscricao cru '
  '(sem destaque) cai no default baixo.';

create or replace function public.abccc_exportar_resumo(p_limit int default 1000, p_offset int default 0)
returns table (
  sbb text,
  nome text,
  sexo text,
  sbb_pai text,
  sbb_mae text,
  linha_alta text,
  linha_baixa text,
  ancestrais_pos jsonb,
  participacoes jsonb,
  finalistas_produzidos jsonb
)
language sql
stable
as $$
  with provas_principais as (
    select unnest(array['Morfologia Expointer','Final Freio de Ouro','Doma de Ouro']) as prova
  ),
  participacoes_agg as (
    select
      rc.sbb,
      jsonb_agg(
        jsonb_build_object(
          'prova', rc.prova, 'tier', rc.tier, 'ciclo', rc.ciclo,
          'colocacao', rc.colocacao,
          'peso', public.abccc_peso_colocacao(rc.colocacao, rc.prova)
        )
        order by rc.ciclo desc nulls last
      ) as participacoes
    from resultados_competitivos rc
    where rc.sbb is not null
    group by rc.sbb
  ),
  finalistas_por_lado as (
    select ag.sbb_pai as sbb, rc.prova, count(distinct ag.sbb) as contagem
    from animais_genealogia ag
    join resultados_competitivos rc on rc.sbb = ag.sbb
    join provas_principais pp on pp.prova = rc.prova
    where ag.sbb_pai is not null
    group by ag.sbb_pai, rc.prova
    union all
    select ag.sbb_mae as sbb, rc.prova, count(distinct ag.sbb) as contagem
    from animais_genealogia ag
    join resultados_competitivos rc on rc.sbb = ag.sbb
    join provas_principais pp on pp.prova = rc.prova
    where ag.sbb_mae is not null
    group by ag.sbb_mae, rc.prova
  ),
  finalistas_agg as (
    select sbb, jsonb_object_agg(prova, contagem) as finalistas_produzidos
    from (select sbb, prova, sum(contagem) as contagem from finalistas_por_lado group by sbb, prova) x
    group by sbb
  )
  select
    ag.sbb, ag.nome, ag.sexo, ag.sbb_pai, ag.sbb_mae,
    case when pai.nome is not null and pai.nome <> pai.sbb then pai.nome else null end as linha_alta,
    case when mae.nome is not null and mae.nome <> mae.sbb then
      mae.nome || case
        when avo_materno.nome is not null and avo_materno.nome <> avo_materno.sbb
          then ' que vem a ser ' || avo_materno.nome
        else ''
      end
    else null end as linha_baixa,
    ag.ancestrais_pos,
    coalesce(pa.participacoes, '[]'::jsonb) as participacoes,
    coalesce(fa.finalistas_produzidos, '{}'::jsonb) as finalistas_produzidos
  from animais_genealogia ag
  left join animais_genealogia pai on pai.sbb = ag.sbb_pai
  left join animais_genealogia mae on mae.sbb = ag.sbb_mae
  left join animais_genealogia avo_materno on avo_materno.sbb = mae.sbb_pai
  left join participacoes_agg pa on pa.sbb = ag.sbb
  left join finalistas_agg fa on fa.sbb = ag.sbb
  order by ag.sbb
  limit p_limit offset p_offset;
$$;

comment on function public.abccc_exportar_resumo is
  'Pagina de resumo por SBB pronta pra copiar em public.abccc_estatisticas_animal (producao). '
  'Chamada repetida com offset crescente pelo job de sincronizacao ate a pagina vir vazia. '
  'linha_alta/linha_baixa omitem nome de ancestral cujo registro e so um stub nao resolvido '
  '(nome = sbb) -- regra de silencio na ausencia, secao 3.2 da base de conhecimento.';

create or replace function public.abccc_exportar_linhagens_em_alta(p_top_n int default 15)
returns table (
  prova text,
  janela text,
  sbb_ancestral text,
  nome_ancestral text,
  contagem_finalistas integer,
  posicao_ranking integer
)
language plpgsql
stable
as $$
declare
  v_provas text[] := array['Morfologia Expointer','Final Freio de Ouro','Doma de Ouro'];
  v_prova text;
  v_ciclo text;
  v_total int;
begin
  foreach v_prova in array v_provas loop
    select rc.ciclo, count(*) into v_ciclo, v_total
    from resultados_competitivos rc
    where rc.prova = v_prova and rc.ciclo is not null
    group by rc.ciclo
    order by rc.ciclo desc
    limit 1;

    if v_ciclo is null then
      continue;
    end if;

    return query
      with finalistas as (
        select distinct rc.sbb
        from resultados_competitivos rc
        where rc.prova = v_prova and rc.ciclo = v_ciclo and rc.sbb is not null
      ),
      contagem as (
        select ag.sbb_pai as sbb_pai_ct, pai.nome as nome_pai_ct, count(distinct ag.sbb) as contagem_pai
        from finalistas f
        join animais_genealogia ag on ag.sbb = f.sbb
        join animais_genealogia pai on pai.sbb = ag.sbb_pai
        where ag.sbb_pai is not null and pai.nome <> pai.sbb
        group by ag.sbb_pai, pai.nome
      ),
      rankeado as (
        select sbb_pai_ct, nome_pai_ct, contagem_pai,
               row_number() over (order by contagem_pai desc, nome_pai_ct) as posicao_pai
        from contagem
        order by contagem_pai desc
        limit p_top_n
      )
      select v_prova, v_prova || ' ' || v_ciclo || ', ' || v_total || ' finalistas',
             r.sbb_pai_ct, r.nome_pai_ct, r.contagem_pai::int, r.posicao_pai::int
      from rankeado r;
  end loop;
end;
$$;

comment on function public.abccc_exportar_linhagens_em_alta is
  'Ranking dos pais diretos (sbb_pai) que mais produziram finalistas no ciclo mais recente '
  'de cada prova principal, com SBB resolvido de verdade. Metodologia corrigida em '
  '2026-08-27 -- versao anterior contava recorrencia pela arvore inteira de 5 geracoes, o '
  'que sobrevalorizava fundadores antigos em vez de sires atualmente relevantes.';

grant execute on function public.abccc_peso_colocacao(text, text) to service_role;
grant execute on function public.abccc_exportar_resumo(int, int) to service_role;
grant execute on function public.abccc_exportar_linhagens_em_alta(int) to service_role;
