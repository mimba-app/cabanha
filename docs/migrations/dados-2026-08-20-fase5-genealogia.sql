-- PROJETO ANALÍTICO (mimba-analytics) — Fase 5: inteligência de cruzamentos.
--
-- ⚠️ NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico (ADR 0005).
--
-- Implementa a especificação de "Mimba Analytics" (analytics-prompt_1.md, Luciano):
-- genealogia normalizada até 5 gerações, resultados competitivos com peso por tier
-- de prova, e uma RPC de análise de cruzamento que cruza ancestrais em comum entre
-- garanhão e égua para estimar força competitiva e consanguinidade.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- DUAS CORREÇÕES em relação ao rascunho original — documentadas aqui porque mudam
-- resultado, não são só estilo:
--
-- 1. IC (consanguinidade) — o rascunho original monta o cálculo com
--    `string_to_array(array_to_string(array_agg(sbb_pai), ','), ',')` filtrando por
--    `WHERE sbb = p_sbb_garanhao`. Isso agrega UMA linha (o próprio garanhão) e tenta
--    desmontar o `sbb_pai` dela como se fosse uma lista de ancestrais — não é: é um
--    único UUID/texto, não uma lista. O resultado do jeito que estava escrito não
--    calcula sobreposição de ancestral nenhuma, sempre daria 0 ou erro de cast.
--    Aqui, a estimativa usa o que a `animal_posicoes` realmente guarda — as 3
--    posições paternas (p1=pai, p2=avô paterno, p3=avó paterna) e as 3 maternas
--    (m1=mãe, m2=avô materno, m3=avó materna) — e verifica se algum indivíduo do
--    lado do garanhão aparece também do lado da égua. Quando aparece, soma a
--    contribuição de Wright pra esse ancestral: (1/2)^(profundidade_pai +
--    profundidade_mãe + 1), profundidade 1 pra pai/mãe (p1/m1) e 2 pra avós
--    (p2/p3/m2/m3) — é a fórmula padrão de coeficiente de parentesco, só que
--    limitada à profundidade que a matview cobre (2 gerações), não às 5 gerações
--    que a tabela normalizada permite guardar. Documentado como limitação, não
--    escondido: um ancestral comum na 3ª geração pra trás não entra nessa conta.
--
-- 2. Peso por objetivo — o rascunho original tem
--    `v_tiers_objetivo := CASE p_objetivo WHEN 'morfologia' THEN ARRAY[1,2,3] WHEN
--    'freio' THEN ARRAY[1,2,3] ... ELSE ARRAY[1,2,3] END` — todo ramo devolve o
--    mesmo array. Na prática "objetivo" não mudava peso nenhum, apesar da regra de
--    negócio #7 do documento dizer explicitamente que deveria. Aqui, `p_objetivo`
--    aplica um multiplicador (x2) aos matches cujo `provas_tier.tipo` bate com o
--    objetivo pedido (morfologia→'morfologia', freio→'funcional', doma→'doma',
--    resistencia→'resistencia'); 'completo' não aplica multiplicador. Todos os
--    tiers continuam entrando na busca — só o peso muda.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. animais_genealogia — cada animal, uma linha só. Genealogia por referência
--    recursiva (sbb_pai/sbb_mae apontam pra outras linhas desta mesma tabela).
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.animais_genealogia (
  sbb                text primary key,
  nome               text not null,
  sexo               text,
  pelagem            text,
  nasc               date,
  sbb_pai            text references public.animais_genealogia(sbb) on delete set null,
  sbb_mae            text references public.animais_genealogia(sbb) on delete set null,
  geracoes_completas integer not null default 0,
  fonte              text not null default 'manual'
                     check (fonte in ('abccc','catalogo_pdf','plantel_cabanha','manual')),
  atualizado_em      timestamptz not null default now(),
  criado_em          timestamptz not null default now()
);

comment on table public.animais_genealogia is
  'Cada animal cadastrado uma unica vez. Genealogia ate 5 geracoes por referencia
   recursiva (sbb_pai/sbb_mae). Fase 5 da area de dados (mimba-analytics).';

create index if not exists idx_ag_pai on public.animais_genealogia(sbb_pai);
create index if not exists idx_ag_mae on public.animais_genealogia(sbb_mae);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. resultados_competitivos — uma linha por premiação/participação.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.resultados_competitivos (
  id          uuid primary key default gen_random_uuid(),
  sbb         text references public.animais_genealogia(sbb) on delete set null,
  nome_animal text not null,
  prova       text not null,
  tier        integer not null check (tier in (1,2,3)),
  ciclo       text,
  colocacao   text,
  fonte       text not null default 'historico_abccc'
              check (fonte in ('historico_abccc','catalogo_pdf','manual')),
  criado_em   timestamptz not null default now()
);

create index if not exists idx_rc_sbb   on public.resultados_competitivos(sbb);
create index if not exists idx_rc_tier  on public.resultados_competitivos(tier);
create index if not exists idx_rc_prova on public.resultados_competitivos(prova);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. provas_tier — hierarquia de provas. Tier nunca é hardcoded no código: sempre
--    derivado daqui.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.provas_tier (
  prova text primary key,
  tier  integer not null check (tier in (1,2,3)),
  tipo  text    not null check (tipo in ('morfologia','funcional','resistencia','doma','paleteada','rienda'))
);

insert into public.provas_tier (prova, tier, tipo) values
  -- Tier 1 — finais máximas
  ('Final Freio de Ouro',          1, 'funcional'),
  ('Freio de Ouro FICCC',          1, 'funcional'),
  ('Morfologia Expointer',         1, 'morfologia'),
  ('Morfologia FICCC',             1, 'morfologia'),
  -- Tier 2 — seletivas
  ('Bocal de Ouro',                2, 'funcional'),
  ('Marcha Anual de Resistencia',  2, 'resistencia'),
  ('Final da Doma de Ouro',        2, 'doma'),
  ('Um Ano de Doma',               2, 'doma'),
  ('Um Ano de Freio',              2, 'funcional'),  -- não estava no rascunho original;
                                                       -- apareceu no catálogo real carregado
                                                       -- na Fase 2 (edição jovem do Freio de Ouro)
  ('Final Nacional de Paleteadas', 2, 'paleteada'),
  ('Movimento a La Rienda',        2, 'rienda'),
  -- Tier 3 — base
  ('Exposição Morfológica',        3, 'morfologia'),
  ('Morfologia Passaporte',        3, 'morfologia'),
  ('Credenciadora Aberta',         3, 'morfologia'),
  ('Credenciadora de Inéditos',    3, 'morfologia'),
  ('Credenciadora Mista',          3, 'morfologia'),
  ('Classificatória Regional',     3, 'funcional')
on conflict (prova) do update set tier = excluded.tier, tipo = excluded.tipo;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. animal_posicoes — matview com as 6 posições genealógicas relevantes de cada
--    animal (2 gerações: pai/mãe + avós). Acelera analisar_cruzamento — sem ela,
--    cada chamada faria 2 self-joins recursivos na hora.
-- ─────────────────────────────────────────────────────────────────────────────
drop materialized view if exists public.animal_posicoes;
create materialized view public.animal_posicoes as
select
  a.sbb,
  a.sbb_pai                       as p1,
  pai.sbb_pai                     as p2,
  pai.sbb_mae                     as p3,
  a.sbb_mae                       as m1,
  mae.sbb_pai                     as m2,
  mae.sbb_mae                     as m3
from public.animais_genealogia a
left join public.animais_genealogia pai on pai.sbb = a.sbb_pai
left join public.animais_genealogia mae on mae.sbb = a.sbb_mae;

-- Índice único em sbb: pré-requisito pra refresh concorrente (mesma correção da
-- fase3b/mv_abccc_resultados — nunca mais criar matview sem pensar em como ela
-- vai ser atualizada depois).
create unique index on public.animal_posicoes(sbb);
create index on public.animal_posicoes(p1);
create index on public.animal_posicoes(p2);
create index on public.animal_posicoes(m1);
create index on public.animal_posicoes(m2);

revoke all on public.animal_posicoes from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. genealogia_atualizar_posicoes() — refresh da matview. Chamar depois de
--    qualquer carga/enriquecimento em lote, nunca durante consulta de usuário.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.genealogia_atualizar_posicoes()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v bigint;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  refresh materialized view concurrently public.animal_posicoes;
  select count(*) into v from public.animal_posicoes;
  return jsonb_build_object('linhas', v, 'atualizado_em', now());
end; $$;
revoke all on function public.genealogia_atualizar_posicoes() from public, anon;
grant execute on function public.genealogia_atualizar_posicoes() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. carregar_catalogo_genealogia — carga em lote de catálogo com genealogia real
--    (sbb_pai/sbb_mae como SBB, não só nome — diferente do dataset de resultados
--    históricos da ABCCC, que só tem nome de pai/mãe em texto). Espelha o padrão
--    de dados_inserir_lote (fase1): recebe um array jsonb, staff-gated.
--
--    Regra crítica (do doc original, mantida): nunca duplicar um animal. Upsert
--    só preenche campos ainda nulos (coalesce) — não sobrescreve genealogia já
--    mais completa que o catálogo novo trouxer pra um animal que já existia.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.carregar_catalogo_genealogia(p_linhas jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_linha jsonb; v_sbb text; v_sbb_pai text; v_sbb_mae text;
  v_animais integer := 0; v_resultados integer := 0; v_tier integer;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;

  for v_linha in select * from jsonb_array_elements(p_linhas) loop
    v_sbb     := nullif(trim(v_linha->>'sbb'), '');
    v_sbb_pai := nullif(trim(v_linha->>'sbb_pai'), '');
    v_sbb_mae := nullif(trim(v_linha->>'sbb_mae'), '');

    -- Pai e mãe primeiro (regra: existir antes de qualquer referência apontar pra eles).
    if v_sbb_pai is not null then
      insert into public.animais_genealogia (sbb, nome, sexo, fonte)
      values (v_sbb_pai, coalesce(nullif(trim(v_linha->>'nome_pai'), ''), v_sbb_pai), 'Macho', 'catalogo_pdf')
      on conflict (sbb) do nothing;
    end if;
    if v_sbb_mae is not null then
      insert into public.animais_genealogia (sbb, nome, sexo, fonte)
      values (v_sbb_mae, coalesce(nullif(trim(v_linha->>'nome_mae'), ''), v_sbb_mae), 'Fêmea', 'catalogo_pdf')
      on conflict (sbb) do nothing;
    end if;

    if v_sbb is not null then
      insert into public.animais_genealogia (sbb, nome, sexo, nasc, sbb_pai, sbb_mae, fonte)
      values (
        v_sbb, coalesce(nullif(trim(v_linha->>'nome'), ''), v_sbb),
        nullif(trim(v_linha->>'sexo'), ''),
        -- Catálogos vêm em DD/MM/YYYY (padrão BR), não no formato ISO que ::date
        -- assume por padrão — cast direto ia falhar ou trocar dia/mês silenciosamente.
        to_date(nullif(v_linha->>'nasc', ''), 'DD/MM/YYYY'),
        v_sbb_pai, v_sbb_mae, 'catalogo_pdf'
      )
      on conflict (sbb) do update set
        nome     = coalesce(public.animais_genealogia.nome, excluded.nome),
        sexo     = coalesce(public.animais_genealogia.sexo, excluded.sexo),
        nasc     = coalesce(public.animais_genealogia.nasc, excluded.nasc),
        sbb_pai  = coalesce(public.animais_genealogia.sbb_pai, excluded.sbb_pai),
        sbb_mae  = coalesce(public.animais_genealogia.sbb_mae, excluded.sbb_mae),
        atualizado_em = now();
      v_animais := v_animais + 1;
    end if;

    if v_linha->>'prova' is not null then
      select tier into v_tier from public.provas_tier where prova = trim(v_linha->>'prova');
      if v_tier is not null then
        insert into public.resultados_competitivos (sbb, nome_animal, prova, tier, ciclo, colocacao, fonte)
        values (
          v_sbb, coalesce(nullif(trim(v_linha->>'nome'), ''), v_sbb, 'desconhecido'),
          trim(v_linha->>'prova'), v_tier, nullif(trim(v_linha->>'ciclo'), ''),
          nullif(trim(v_linha->>'colocacao'), ''), 'catalogo_pdf'
        );
        v_resultados := v_resultados + 1;
      end if;
    end if;
  end loop;

  return jsonb_build_object('animais', v_animais, 'resultados', v_resultados);
end; $$;
revoke all on function public.carregar_catalogo_genealogia(jsonb) from public, anon;
grant execute on function public.carregar_catalogo_genealogia(jsonb) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. analisar_cruzamento — score competitivo + IC + matches históricos.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.analisar_cruzamento(
  p_sbb_garanhao text,
  p_sbb_egua     text,
  p_objetivo     text default 'completo'  -- 'morfologia' | 'freio' | 'doma' | 'resistencia' | 'completo'
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

  -- CORREÇÃO 2 (ver cabeçalho do arquivo): objetivo -> tipo de prova que ganha peso extra.
  v_tipo_objetivo := case p_objetivo
    when 'morfologia'  then 'morfologia'
    when 'freio'       then 'funcional'
    when 'doma'        then 'doma'
    when 'resistencia' then 'resistencia'
    else null  -- 'completo': nenhum tipo ganha peso extra
  end;

  -- Matches: animais em resultados cuja PRÓPRIA genealogia (posições p1..m3)
  -- coincide em >=2 pontos com as posições do cruzamento planejado — ou seja,
  -- "alguém com essa mesma combinação de linhagem já competiu, e foi como?".
  -- Fiel ao desenho original; a única mudança aqui é incluir ap.m1=v_m1 na soma
  -- (ausente no rascunho original — 5 termos em vez dos 6 que os comentários do
  -- próprio autor descrevem; oversight, não redesenho).
  select jsonb_agg(m order by (m->>'score')::numeric desc)
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

  -- CORREÇÃO 1 (ver cabeçalho do arquivo): IC real por sobreposição de ancestrais
  -- comuns entre a linhagem paterna do garanhão {p1,p2,p3} e a linhagem materna
  -- da égua {m1,m2,m3} — coeficiente de Wright aproximado, limitado à
  -- profundidade de 2 gerações que animal_posicoes cobre.
  select coalesce(sum(contrib), 0) into v_ic
  from (
    select power(0.5, prof_p + prof_m + 1) as contrib
    from (values (v_p1,1),(v_p2,2),(v_p3,2)) as pais(sbb, prof_p)
    join (values (v_m1,1),(v_m2,2),(v_m3,2)) as maes(sbb, prof_m)
      on pais.sbb = maes.sbb and pais.sbb is not null
  ) t;
  v_ic := round(v_ic * 100, 2);

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
    'ic_aviso', 'estimado com profundidade de 2 geracoes (pais+avos); ancestral comum mais antigo nao entra nesta conta',
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rodar depois de aplicar:
--   select count(*) from public.provas_tier;               -- 18
--   select count(*) from public.animal_posicoes;            -- 0 antes da carga
--   select proname, proacl from pg_proc where proname in
--     ('analisar_cruzamento','carregar_catalogo_genealogia','genealogia_atualizar_posicoes')
--     and pronamespace = 'public'::regnamespace;             -- sem anon em nenhum
-- ═══════════════════════════════════════════════════════════════════════════════
