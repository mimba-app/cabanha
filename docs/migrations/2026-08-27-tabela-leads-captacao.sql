-- Captacao de leads da landing (ADR informal -- pedido direto do founder,
-- 2026-08-27): registrar quem clicou no CTA "Quero conhecer" mas ainda nao
-- assinou, pra dar seguimento depois (ligar/mandar mensagem).
--
-- Mesmo padrao de `signups`: RLS ligada, ZERO grant pra anon/authenticated --
-- so `service_role` (a Edge Function `capturar-lead`) escreve e le. Nao e
-- dado de tenant, nao passa por `tem_acesso_tenant`.

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  contato text not null,
  origem text not null default 'landing',
  pagina_url text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  criado_em timestamptz not null default now()
);

comment on table public.leads is
  'Contatos capturados na landing antes de assinar (CTA "Quero conhecer") -- '
  'pra follow-up manual do time comercial. Nao e dado de tenant.';
comment on column public.leads.contato is
  'Email ou WhatsApp, texto livre (a landing pede so um campo de contato).';

alter table public.leads enable row level security;
-- Sem nenhuma policy de proposito -- default-deny pra anon/authenticated via
-- PostgREST. service_role sempre ignora RLS (usado pela Edge Function).
