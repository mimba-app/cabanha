-- Remove a Área de Dados da instância de PRODUÇÃO (projeto fmjfvfufkqswweyasjyp).
--
-- POR QUÊ: em 2026-08-19 a carga analítica da ABCCC (83.778 linhas em dados_registros,
-- inseridas uma a uma, com 4 índices de expressão jsonb, mais a matview mv_abccc_resultados
-- com outros 6 índices e refresh não-concorrente) saturou a CPU de uma instância FREE
-- compartilhada com o banco transacional das cabanhas. Resultado: Database/PostgREST/Auth/
-- Storage unhealthy, 522 em toda a API, statement timeout no bootstrap do login. Produção
-- caiu. Decisão do Pedro: base analítica não mora junto com o transacional — a Área de Dados
-- é refeita num projeto Supabase separado.
--
-- ESCOPO: remove SOMENTE objetos criados pelas migrations 2026-08-19-area-dados-fase*.
-- Nada de tenant, nada de cabanha, nada do control-plane é tocado.
--
-- ⚠️ NÃO REMOVER (pré-existem à Área de Dados e continuam em uso):
--   · public.mimba_staff e public.sou_staff_mimba()  → gate de staff, já existia antes
--   · extensão pg_net                                → usada pelo cron `cobrar-trials-vencidos`
--   · extensão pg_cron                               → idem
--
-- DESTRUTIVO E IRREVERSÍVEL: apaga as 83.778 linhas da ABCCC e os arquivos do bucket.
-- Isso é aceitável de propósito: a base é 100% reconstruível a partir do painel público da
-- ABCCC (o importador está em docs/migrations/2026-08-19-area-dados-fase2-abccc.sql e em
-- dados/abccc/extrair.mjs). Nenhum dado de cliente vive aqui.
--
-- ────────────────────────────────────────────────────────────────────────────
-- ANTES DE APLICAR — conferir o que existe hoje (rodar e guardar a saída):
--
--   select 'tabela' t, relname obj, pg_size_pretty(pg_total_relation_size(c.oid)) tam
--     from pg_class c join pg_namespace n on n.oid=c.relnamespace
--    where n.nspname='public' and relname in
--          ('dados_datasets','dados_registros','dados_fontes_externas','mv_abccc_resultados')
--   union all
--   select 'funcao', p.proname, '' from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname='public' and (p.proname like 'dados\_%' or p.proname like 'abccc\_%'
--                                  or p.proname like 'ref\_abccc\_%')
--   union all
--   select 'bucket', id, '' from storage.buckets where id='dados-mimba';
-- ────────────────────────────────────────────────────────────────────────────

begin;

-- 1. Funções primeiro: nenhuma outra coisa depende delas, e tirar o EXECUTE antes do
--    drop evita janela em que a RPC existe apontando pra tabela já removida.
drop function if exists public.abccc_atualizar_analises();
drop function if exists public.ref_abccc_animal(text);
drop function if exists public.ref_abccc_reprodutor(text);
drop function if exists public.abccc_buscar(text,integer);
drop function if exists public.abccc_ranking(text,text,text,integer);
drop function if exists public.abccc_resumo();
drop function if exists public.abccc_e_campeao(text);
drop function if exists public.abccc_pontos(text);
drop function if exists public.abccc_importar_coletar(uuid,bigint,boolean);
drop function if exists public.abccc_importar_disparar(integer,jsonb,text);
drop function if exists public.dados_resumo();
drop function if exists public.dados_amostra(uuid,integer);
drop function if exists public.dados_listar_datasets();
drop function if exists public.dados_excluir_dataset(uuid);
drop function if exists public.dados_finalizar_dataset(uuid,text,text);
drop function if exists public.dados_inserir_lote(uuid,jsonb);
drop function if exists public.dados_criar_dataset(text,text,text,text,text,text,jsonb,text);

-- 2. Matview e view (a matview carrega 6 índices, que caem junto).
drop materialized view if exists public.mv_abccc_resultados;
drop view if exists public.vw_abccc_resultados;

-- 3. Tabelas. dados_registros tem FK pra dados_datasets, então vai primeiro.
--    O cascade leva junto os 5 índices, as policies staff_all e o trigger de touch.
drop table if exists public.dados_registros       cascade;
drop table if exists public.dados_datasets        cascade;
drop table if exists public.dados_fontes_externas cascade;

-- 4. dados_touch() só existia pro trigger de dados_datasets, que já caiu no passo 3.
drop function if exists public.dados_touch();

-- 5. Storage: policy, arquivos e bucket.
--    A policy é a única que a Área de Dados criou em storage.objects — verificado na
--    revisão de isolamento de 19/08: não havia nenhuma outra policy permissiva ali.
drop policy if exists dados_mimba_staff on storage.objects;
delete from storage.objects where bucket_id = 'dados-mimba';
delete from storage.buckets where id = 'dados-mimba';

-- 6. Fila de respostas do pg_net. A importação da ABCCC trouxe páginas de vários MB por
--    resposta e elas ficam nessa tabela até o TTL passar — é peso morto de vacuum agora.
--    Só limpa o histórico; a extensão e o cron de cobrança continuam intactos.
delete from net._http_response;

commit;

-- ────────────────────────────────────────────────────────────────────────────
-- DEPOIS DE APLICAR — as três consultas têm que voltar VAZIAS:
--
--   select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
--    where n.nspname='public' and relname in
--      ('dados_datasets','dados_registros','dados_fontes_externas',
--       'mv_abccc_resultados','vw_abccc_resultados');
--
--   select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname='public' and (p.proname like 'dados\_%' or p.proname like 'abccc\_%'
--                                  or p.proname like 'ref\_abccc\_%');
--
--   select id from storage.buckets where id='dados-mimba';
--
-- E estas têm que continuar EXISTINDO (não podem ter sido levadas junto):
--
--   select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname='public' and proname in ('sou_staff_mimba','tem_acesso_tenant',
--                                             'minhas_cabanhas','carregar_dados_cabanha');
--   select count(*) from public.mimba_staff;
--   select jobname, schedule, active from cron.job;   -- cobrar-trials-vencidos ativo
--   select extname from pg_extension where extname in ('pg_net','pg_cron');
--
-- Recuperar o espaço e zerar a dívida de vacuum (fora da transação, pode demorar):
--   vacuum (full, analyze) net._http_response;
-- ────────────────────────────────────────────────────────────────────────────
