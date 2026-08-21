-- PROJETO ANALÍTICO (mimba-analytics) — Fase 6: backfill da genealogia/resultados
-- a partir do dataset ABCCC já carregado (83.778 linhas, fase 2/2b, tipo
-- 'resultados_abccc' em dados_registros).
--
-- ⚠️ NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico (ADR 0005).
-- ⚠️ RODAR DEPOIS da fase5 (tabelas/RPCs de genealogia precisam existir).
--
-- Esse dataset só tem NOME de pai/mãe em texto, não SBB (é assim que o painel da
-- ABCCC expõe os resultados históricos) — então aqui só entra o animal em si
-- (sbb + nome), sem sbb_pai/sbb_mae. A genealogia de verdade vem da fase 2
-- (catálogos com SBB de pai/mãe, via carregar_catalogo_genealogia) e do
-- enriquecimento incremental (fase 3, edge function enriquecer-genealogia).
--
-- Idempotente: ON CONFLICT DO NOTHING / DO UPDATE só preenchendo nulos.

-- 1. Animais — um por SBB distinto, sem genealogia ainda.
insert into public.animais_genealogia (sbb, nome, sexo, fonte)
select distinct on (r.dados->>'SBB')
  r.dados->>'SBB',
  coalesce(nullif(r.dados->>'Animal',''), r.dados->>'SBB'),
  nullif(r.dados->>'Sexo',''),
  'abccc'
from public.dados_registros r
join public.dados_datasets d on d.id = r.dataset_id
where d.tipo = 'resultados_abccc' and d.status = 'publicado'
  and nullif(r.dados->>'SBB','') is not null
on conflict (sbb) do update set
  nome = coalesce(public.animais_genealogia.nome, excluded.nome),
  sexo = coalesce(public.animais_genealogia.sexo, excluded.sexo);

-- 2. Resultados — uma linha por premiação, tier derivado de provas_tier. Provas
--    que não estão na tabela (fora do escopo de morfologia/funcional/etc. que o
--    catálogo cobre) ficam de fora — é o `join` interno com provas_tier abaixo,
--    de propósito: sem tier não entra no ranking de analisar_cruzamento.
insert into public.resultados_competitivos (sbb, nome_animal, prova, tier, ciclo, colocacao, fonte)
select
  nullif(r.dados->>'SBB',''),
  coalesce(nullif(r.dados->>'Animal',''), r.dados->>'SBB', 'desconhecido'),
  r.dados->>'Prova',
  pt.tier,
  nullif(r.dados->>'Ciclo',''),
  nullif(r.dados->>'Colocação',''),
  'historico_abccc'
from public.dados_registros r
join public.dados_datasets d on d.id = r.dataset_id
join public.provas_tier pt on pt.prova = r.dados->>'Prova'
where d.tipo = 'resultados_abccc' and d.status = 'publicado';

-- 3. Atualiza a matview (vazia até aqui, já que nenhum sbb_pai/sbb_mae foi
--    preenchido nesta fase — mas os SBBs já existem, prontos pra fase 2 e o
--    enriquecimento incremental completarem sbb_pai/sbb_mae depois).
select public.genealogia_atualizar_posicoes();

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rodar depois de aplicar:
--   select count(*) from public.animais_genealogia;      -- ~26 mil (SBBs distintos)
--   select count(*) from public.resultados_competitivos; -- só provas com tier mapeado
--   select prova, count(*) from public.resultados_competitivos
--     group by prova order by 2 desc;
-- ═══════════════════════════════════════════════════════════════════════════
