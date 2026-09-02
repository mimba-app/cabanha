-- Achado real (2026-09-01): o GA4 registrou 1 evento "lead_submit" em 28/08
-- (pós-lançamento) mas public.leads está com 0 linhas -- o frontend só dispara
-- esse evento depois que a Edge Function capturar-lead responde
-- {sucesso:true}, e essa resposta só acontece depois de um insert que
-- funcionou. Ou seja: pelo código, era pra existir uma linha. Não tem como
-- recuperar o conteúdo desse lead específico agora (nada foi persistido em
-- lugar nenhum), mas dá pra fechar a lacuna pra frente -- se o insert
-- principal falhar por qualquer motivo (RLS, rede, bug futuro), a função vai
-- gravar aqui como fallback, com o erro, em vez de só um console.log que some
-- depois de 24h nos logs da Edge Function.
--
-- Mesmo padrão de leads/signups: RLS ligada, zero grant pra anon/authenticated
-- -- só service_role (a própria Edge Function) escreve/lê.

create table public.leads_erros (
  id uuid primary key default gen_random_uuid(),
  nome text,
  contato text,
  origem text,
  pagina_url text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  erro text not null,
  etapa text not null, -- em que ponto falhou: 'rate_limit', 'insert', 'payload'
  criado_em timestamptz not null default now()
);

comment on table public.leads_erros is
  'Fallback de public.leads -- guarda a tentativa de captura de lead quando o '
  'insert principal falha, pra não depender só do GA4 pra saber que um '
  'visitante tentou deixar contato. Não é dado de tenant.';

alter table public.leads_erros enable row level security;
-- Sem policy de propósito: default-deny pra anon/authenticated via PostgREST.
