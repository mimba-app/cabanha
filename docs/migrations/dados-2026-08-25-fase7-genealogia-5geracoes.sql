-- PROJETO ANALÍTICO (mimba-analytics) — Fase 7: genealogia real de 5 gerações.
--
-- ⚠️ NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico (ADR 0005).
--    Este projeto (njynlsugmvtuvcczmuld) é isolado do de produção (fmjfvfufkqswweyasjyp)
--    desde o incidente de 19/08/2026 — ver docs/handoff-mimba-lab-cruzamentos.md.
--
-- Contexto: a Fase 5 (dados-2026-08-20-fase5-genealogia.sql) só populava
-- animal_posicoes com 2 gerações (pai/mãe + avós), porque só existia sbb_pai/sbb_mae
-- (linkagem por SBB). Um catálogo/backfill real de 5 gerações via ABCCC
-- (mesma técnica da edge function de produção `analise-sangues`) só traz, a partir
-- da 2ª geração, NOME do ancestral — não SBB (a página quinta_geracao.php da ABCCC
-- não linka SBB nos ancestrais além do pai/mãe direto). Por isso a genealogia de
-- 5 gerações é guardada como lista de nomes por geração/lado (`ancestrais_pos`,
-- mesmo formato de `sangues_linhagem.ancestrais_pos` em produção), não como cadeia
-- de SBBs. `sbb_pai`/`sbb_mae` continuam sendo a linkagem real (SBB) de 1ª geração.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. animais_genealogia — cache de 5ª geração (nome+geração+lado) e metadados de
--    consulta, no mesmo padrão de `public.sangues_linhagem` (produção).
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.animais_genealogia
  add column if not exists ancestrais_pos jsonb,        -- [{nome, lado:'pat'|'mat', gen:1..5}, ...]
  add column if not exists abccc_consultado_em timestamptz,
  add column if not exists abccc_erro text;

comment on column public.animais_genealogia.ancestrais_pos is
  'Ancestrais por nome ate 5a geracao, vindos de quinta_geracao.php (ABCCC). Sem SBB
   alem da 1a geracao (sbb_pai/sbb_mae) - a ABCCC nao linka SBB dos avos em diante
   nessa pagina. Lado = metade do pedigree (pat = ramo do pai, mat = ramo da mae).';

create index if not exists idx_ag_ancestrais_pos on public.animais_genealogia using gin (ancestrais_pos);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. abccc_ancestrais_lado — ancestrais (nome + geracao) de um lado do pedigree
--    de um animal, com fallback pras 2 gs geracoes de animal_posicoes (SBB→nome)
--    quando o animal ainda nao tem ancestrais_pos carregado (retrocompatibilidade
--    com a Fase 5). Usada pelo calculo de IC em analisar_cruzamento.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.abccc_ancestrais_lado(p_sbb text, p_lado text)
returns table(nome text, gen integer)
language sql stable security definer set search_path to 'public' as $$
  with base as (
    select trim(elem->>'nome') as nome, (elem->>'gen')::int as gen
    from public.animais_genealogia ag,
         jsonb_array_elements(coalesce(ag.ancestrais_pos, '[]'::jsonb)) elem
    where ag.sbb = p_sbb and elem->>'lado' = p_lado
  ),
  fallback_2g as (
    -- Só entra em jogo se `base` vier vazio (animal sem 5a geracao carregada ainda).
    select f.nome, f.gen from (
      select (case p_lado when 'pat' then p1.nome when 'mat' then m1.nome end) as nome, 1 as gen
      from public.animal_posicoes apz
      left join public.animais_genealogia p1 on p1.sbb = apz.p1
      left join public.animais_genealogia m1 on m1.sbb = apz.m1
      where apz.sbb = p_sbb
      union all
      select (case p_lado when 'pat' then p2.nome when 'mat' then m2.nome end), 2
      from public.animal_posicoes apz
      left join public.animais_genealogia p2 on p2.sbb = apz.p2
      left join public.animais_genealogia m2 on m2.sbb = apz.m2
      where apz.sbb = p_sbb
      union all
      select (case p_lado when 'pat' then p3.nome when 'mat' then m3.nome end), 2
      from public.animal_posicoes apz
      left join public.animais_genealogia p3 on p3.sbb = apz.p3
      left join public.animais_genealogia m3 on m3.sbb = apz.m3
      where apz.sbb = p_sbb
    ) f
    where f.nome is not null
  )
  select distinct on (nome) nome, gen
  from (
    select * from base
    union all
    select * from fallback_2g where not exists (select 1 from base)
  ) u
  where nome is not null
  order by nome, gen asc;
$$;
revoke all on function public.abccc_ancestrais_lado(text,text) from public, anon;
grant execute on function public.abccc_ancestrais_lado(text,text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. analisar_cruzamento — troca o IC de 2 gs (SBB, p1..m3) por IC de 5 gs
--    (nome, via abccc_ancestrais_lado). score_competitivo continua em 2 gs
--    (SBB, animal_posicoes) — estender isso exigiria carregar ancestrais_pos
--    pra TODOS os animais de resultados_competitivos, nao só finalistas/garanhoes
--    consultados; fica registrado como proxima etapa, nao redesenhado aqui.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.analisar_cruzamento(
  p_sbb_garanhao text,
  p_sbb_egua     text,
  p_objetivo     text default 'completo'
)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_p1 text; v_p2 text; v_p3 text;
  v_m1 text; v_m2 text; v_m3 text;
  v_matches jsonb;
  v_score_comp numeric;
  v_ic numeric;
  v_score_limpeza numeric;
  v_nota numeric;
  v_tipo_objetivo text;
  v_gar_5g boolean; v_egua_5g boolean; v_ic_aviso text;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;

  if p_objetivo not in ('morfologia','freio','doma','resistencia','completo') then
    raise exception 'objetivo invalido: %', p_objetivo;
  end if;

  select p1,p2,p3 into v_p1,v_p2,v_p3 from public.animal_posicoes where sbb = p_sbb_garanhao;
  select m1,m2,m3 into v_m1,v_m2,v_m3 from public.animal_posicoes where sbb = p_sbb_egua;

  if v_p1 is null and v_p2 is null and v_p3 is null and not exists (select 1 from public.animais_genealogia where sbb = p_sbb_garanhao) then
    raise exception 'garanhao % nao cadastrado', p_sbb_garanhao;
  end if;
  if v_m1 is null and v_m2 is null and v_m3 is null and not exists (select 1 from public.animais_genealogia where sbb = p_sbb_egua) then
    raise exception 'egua % nao cadastrada', p_sbb_egua;
  end if;

  v_tipo_objetivo := case p_objetivo
    when 'morfologia'  then 'morfologia'
    when 'freio'       then 'funcional'
    when 'doma'        then 'doma'
    when 'resistencia' then 'resistencia'
    else null
  end;

  select jsonb_agg(m order by m.score desc)
  into v_matches
  from (
    select
      rc.id, rc.nome_animal, rc.prova, rc.tier, rc.ciclo, rc.colocacao, pt.tipo,
      (
        (ap.p1 = v_p1 and v_p1 is not null)::int +
        (ap.p2 = v_p2 and v_p2 is not null)::int +
        (ap.p3 = v_p3 and v_p3 is not null)::int +
        (ap.m1 = v_m1 and v_m1 is not null)::int +
        (ap.m2 = v_m2 and v_m2 is not null)::int +
        (ap.m3 = v_m3 and v_m3 is not null)::int
      ) as posicoes_coincidentes,
      (
        case rc.tier when 1 then 10 when 2 then 5 else 1 end
        * case when pt.tipo = v_tipo_objetivo then 2 else 1 end
      ) as score
    from public.resultados_competitivos rc
    join public.animal_posicoes ap on ap.sbb = rc.sbb
    join public.provas_tier pt on pt.prova = rc.prova
  ) m
  where m.posicoes_coincidentes >= 2;

  select least(100, coalesce(sum((m->>'score')::numeric), 0) / 10.0)
  into v_score_comp
  from jsonb_array_elements(coalesce(v_matches, '[]'::jsonb)) m;

  -- IC de 5 geracoes: ancestrais em comum entre o ramo paterno do garanhao (lado
  -- 'pat' da sua propria arvore) e o ramo materno da egua (lado 'mat' da dela),
  -- casando por NOME (unica chave disponivel alem da 1a geracao) — formula de
  -- Wright, 0.5^(geracao_no_garanhao + geracao_na_egua + 1).
  select coalesce(sum(power(0.5, pat.gen + mat.gen + 1)), 0) into v_ic
  from public.abccc_ancestrais_lado(p_sbb_garanhao, 'pat') pat
  join public.abccc_ancestrais_lado(p_sbb_egua, 'mat') mat
    on pat.nome = mat.nome;
  v_ic := round(v_ic * 100, 2);

  select (ancestrais_pos is not null and jsonb_array_length(ancestrais_pos) > 0)
    into v_gar_5g from public.animais_genealogia where sbb = p_sbb_garanhao;
  select (ancestrais_pos is not null and jsonb_array_length(ancestrais_pos) > 0)
    into v_egua_5g from public.animais_genealogia where sbb = p_sbb_egua;
  v_ic_aviso := case
    when coalesce(v_gar_5g,false) and coalesce(v_egua_5g,false)
      then 'calculado com profundidade de 5 geracoes (ABCCC)'
    else 'estimado com profundidade de 2 geracoes (pais+avos) — animal sem 5a geracao carregada ainda'
  end;

  v_score_limpeza := case
    when v_ic = 0     then 100
    when v_ic <= 3    then 80
    when v_ic <= 6.25 then 50
    when v_ic <= 12.5 then 20
    else 0
  end;

  v_nota := round((v_score_comp * 0.6) + (v_score_limpeza * 0.4));

  return jsonb_build_object(
    'nota_geral', v_nota,
    'score_competitivo', round(v_score_comp),
    'score_limpeza', v_score_limpeza,
    'ic_estimado', v_ic,
    'ic_aviso', v_ic_aviso,
    'posicoes', jsonb_build_object(
      'garanhao', jsonb_build_object('sbb', p_sbb_garanhao, 'pai', v_p1, 'avo_paterno', v_p2, 'avo_materno_do_pai', v_p3),
      'egua',     jsonb_build_object('sbb', p_sbb_egua, 'mae', v_m1, 'avo_paterno_da_mae', v_m2, 'avo_materno', v_m3)
    ),
    'matches', coalesce(v_matches, '[]'::jsonb),
    'objetivo', p_objetivo
  );
end; $$;
revoke all on function public.analisar_cruzamento(text,text,text) from public, anon;
grant execute on function public.analisar_cruzamento(text,text,text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. genealogia_atualizar_posicoes — permitir tambem chamada via service_role
--    (o backfill de 5a geracao roda como script externo, sem sessao de staff
--    logado, direto contra a REST API com a service_role key).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.genealogia_atualizar_posicoes()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v bigint;
begin
  if not (public.sou_staff_mimba() or auth.role() = 'service_role') then
    raise exception 'acesso negado';
  end if;
  refresh materialized view concurrently public.animal_posicoes;
  select count(*) into v from public.animal_posicoes;
  return jsonb_build_object('linhas', v, 'atualizado_em', now());
end; $$;
revoke all on function public.genealogia_atualizar_posicoes() from public, anon;
grant execute on function public.genealogia_atualizar_posicoes() to authenticated;

-- 4b. genealogia_resumo — acrescenta contagem de animais com 5a geracao carregada.
create or replace function public.genealogia_resumo()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  select jsonb_build_object(
    'animais_total', (select count(*) from public.animais_genealogia),
    'animais_com_genealogia', (select count(*) from public.animais_genealogia where sbb_pai is not null or sbb_mae is not null),
    'animais_com_5a_geracao', (select count(*) from public.animais_genealogia where ancestrais_pos is not null and jsonb_array_length(ancestrais_pos) > 0),
    'resultados_catalogo', (select count(*) from public.resultados_competitivos where fonte = 'catalogo_pdf'),
    'posicoes', (select count(*) from public.animal_posicoes)
  ) into v;
  return v;
end; $$;
revoke all on function public.genealogia_resumo() from public, anon;
grant execute on function public.genealogia_resumo() to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rodar depois de aplicar:
--   select column_name from information_schema.columns
--     where table_name='animais_genealogia' and column_name='ancestrais_pos';    -- 1 linha
--   select proname from pg_proc where proname='abccc_ancestrais_lado';           -- 1 linha
--   select public.genealogia_resumo();  -- animais_com_5a_geracao deve aparecer, comeca em 0
-- ═══════════════════════════════════════════════════════════════════════════════
