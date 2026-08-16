-- V1.5 (docs/roadmap-v15.md, Fase 2) — agenda a cobrança automática de trials vencidos.
-- Rode isso no SQL Editor. Só você tem a service_role key (Project Settings → API) —
-- por isso não apliquei este passo direto: preciso dela pra o pg_cron poder chamar a
-- edge function cobrar-trial com autorização.

begin;

-- 1) Guarda a service_role key no Vault (criptografada) — troque o valor abaixo pela
--    chave de verdade (Project Settings → API → service_role, "secret").
select vault.create_secret(
  'COLE_AQUI_A_SERVICE_ROLE_KEY',
  'service_role_key',
  'Usada pelo pg_cron pra chamar edge functions internas (ex.: cobrar-trial).'
);

-- 2) Agenda a chamada diária (03h) pra cobrar-trial via pg_net, usando a key do Vault.
select cron.schedule(
  'cobrar-trials-vencidos',
  '0 3 * * *',
  $$
  select net.http_post(
    url := 'https://fmjfvfufkqswweyasjyp.supabase.co/functions/v1/cobrar-trial',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

commit;

-- Verificação depois de aplicar:
-- select jobid, jobname, schedule, active from cron.job where jobname = 'cobrar-trials-vencidos';
--
-- Teste manual (sem esperar o cron, substitua a key e rode direto no terminal ou Postman):
--   curl -X POST https://fmjfvfufkqswweyasjyp.supabase.co/functions/v1/cobrar-trial \
--     -H "Authorization: Bearer SUA_SERVICE_ROLE_KEY" -H "Content-Type: application/json"
-- Com o ambiente sandbox do Asaas, não deve cobrar nada de verdade — mas teste só depois
-- de confirmar com o Pedro/Thiago que está tudo certo pra rodar (mexe em status de tenant).
