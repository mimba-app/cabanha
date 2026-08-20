-- PROJETO ANALÍTICO (mimba-analytics) — Fase 4: índices de expressão, DEPOIS da carga.
--
-- ⚠️ NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico (ADR 0005).
--
-- ⚠️ APLICAR SÓ DEPOIS DE CARREGAR OS DADOS. Se rodar antes, perde-se todo o ganho:
-- o ponto é justamente não pagar manutenção de índice durante a inserção em massa.
--
-- POR QUÊ ESTÁ SEPARADO: na versão que rodou em produção, estes 4 índices existiam já na
-- criação da tabela. Com eles presentes, cada linha inserida reavalia 4 extrações de jsonb
-- e atualiza 5 árvores de índice. Multiplicado pelas 83.778 linhas da ABCCC — e somado ao
-- INSERT linha a linha, corrigido na fase 2 — foi parte do que saturou a CPU e derrubou a
-- instância. Construir o índice de uma vez sobre a tabela já cheia é muito mais barato do
-- que mantê-lo incremental durante a carga.
--
-- CONCURRENTLY em todos: não bloqueia escrita na tabela enquanto constrói. Custa uma
-- varredura a mais, mas é o comportamento certo num banco que alguém pode estar usando.
-- Atenção: `create index concurrently` NÃO pode rodar dentro de bloco de transação —
-- execute este arquivo statement a statement, ou fora de BEGIN/COMMIT.

create index concurrently if not exists dados_registros_sbb_idx
  on public.dados_registros((dados->>'SBB'));

create index concurrently if not exists dados_registros_pai_idx
  on public.dados_registros((dados->>'Pai'));

create index concurrently if not exists dados_registros_mae_idx
  on public.dados_registros((dados->>'Mãe'));

create index concurrently if not exists dados_registros_animal_idx
  on public.dados_registros((dados->>'Animal'));

-- Estatísticas atualizadas logo após a carga: sem isso o planner ainda acha que a tabela
-- está vazia e escolhe plano ruim nas primeiras consultas.
analyze public.dados_registros;

-- ────────────────────────────────────────────────────────────────────────────
-- Conferir que os 4 ficaram válidos (INVALID acontece se um create concurrently falhar
-- no meio; o índice fica lá, inútil, e precisa ser dropado e refeito):
--
--   select i.indexrelid::regclass as indice, i.indisvalid as valido,
--          pg_size_pretty(pg_relation_size(i.indexrelid)) as tamanho
--     from pg_index i
--    where i.indrelid = 'public.dados_registros'::regclass
--    order by 1;
--
-- Todos têm que aparecer com valido = true.
-- ────────────────────────────────────────────────────────────────────────────
