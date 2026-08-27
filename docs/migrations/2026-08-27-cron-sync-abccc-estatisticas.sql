-- Agenda o job de sincronizacao (ADR 0009) pra rodar sozinho, 1x/dia, via
-- pg_cron + pg_net (ambos ja habilitados no projeto de producao). O segredo
-- compartilhado usado pra autenticar a chamada NUNCA fica em texto puro --
-- foi guardado no Supabase Vault ANTES desta migration, via SQL Editor
-- (nao versionado, nao aplicado por este arquivo):
--
--   select vault.create_secret(
--     '<valor gerado com openssl rand -hex 32, mesmo valor do secret
--        SYNC_ABCCC_SHARED_SECRET configurado na Edge Function>',
--     'sync_abccc_shared_secret',
--     'Segredo compartilhado usado pelo cron pra autenticar chamadas a sync-abccc-estatisticas (ADR 0009)'
--   );
--
-- Esta migration só referencia o nome do secret (`sync_abccc_shared_secret`)
-- via `vault.decrypted_secrets` -- nunca o valor.

select cron.schedule(
  'sync-abccc-estatisticas-diario',
  '0 6 * * *', -- 06:00 UTC = 03:00 America/Sao_Paulo (Lab nao muda durante o dia -- diario e suficiente, ver ADR 0009)
  $$
  select net.http_post(
    url := 'https://fmjfvfufkqswweyasjyp.supabase.co/functions/v1/sync-abccc-estatisticas',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'sync_abccc_shared_secret')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);

-- Verificação pós-apply:
--   select jobid, jobname, schedule, active from cron.job where jobname = 'sync-abccc-estatisticas-diario';
--   select * from cron.job_run_details where jobid = (select jobid from cron.job where jobname = 'sync-abccc-estatisticas-diario') order by start_time desc limit 5;
