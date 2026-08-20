-- PROJETO ANALÍTICO (mimba-analytics, ref njynlsugmvtuvcczmuld) — Fase 0: gate de staff.
--
-- ⚠️ ESTA MIGRATION NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico, conforme
-- ADR 0005. A skill `nova-migration-tenant` NÃO se aplica: não existe schema `cab_*` aqui.
--
-- POR QUÊ EXISTE: no projeto de produção, `public.mimba_staff` e `public.sou_staff_mimba()`
-- foram criados direto pelo SQL Editor e nunca foram versionados — não existem em `docs/`.
-- Como o projeto analítico tem Auth próprio (decisão do ADR 0005: NÃO compartilhar JWT secret
-- entre os projetos, pra não recriar raio de explosão comum), eles precisam ser recriados aqui.
-- Esta é a primeira vez que esse gate fica versionado. Se um dia produção voltar e as
-- definições de lá divergirem desta, esta é a que vale para este projeto.
--
-- Toda a Área de Dados pendura a RLS neste gate, então ele vem antes de tudo.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Quem é staff da Mimba
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.mimba_staff (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  nome         text,
  criado_em    timestamptz not null default now()
);

comment on table public.mimba_staff is
  'Funcionários/sócios da Mimba com acesso à área analítica. Espelha o mimba_staff do projeto
   de produção, mas é uma lista independente — os dois projetos têm Auth separado (ADR 0005).
   Sincronização é manual e deliberada: são 2 pessoas.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. O gate
-- ─────────────────────────────────────────────────────────────────────────────
-- SECURITY DEFINER porque precisa ler mimba_staff mesmo quando o chamador não tem
-- permissão de ler a tabela — é exatamente esse o ponto de um gate.
-- STABLE (não VOLATILE) pra que o planner possa cachear dentro da query; as policies
-- chamam envolto em `(select ...)` pra avaliar uma vez por query, não por linha.
create or replace function public.sou_staff_mimba()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.mimba_staff where auth_user_id = auth.uid()
  );
$$;

comment on function public.sou_staff_mimba() is
  'true se o usuário autenticado é staff da Mimba. Gate de toda a RLS da área analítica.';

-- anon nunca; só usuário logado pergunta se é staff.
revoke all on function public.sou_staff_mimba() from public, anon;
grant execute on function public.sou_staff_mimba() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS na própria tabela de staff
-- ─────────────────────────────────────────────────────────────────────────────
-- Sem isso, a lista de quem é staff fica legível por qualquer usuário logado.
alter table public.mimba_staff enable row level security;

drop policy if exists staff_le on public.mimba_staff;
create policy staff_le on public.mimba_staff
  for select to authenticated
  using ((select public.sou_staff_mimba()));

-- Escrita: ninguém pela API. Entrar/sair da lista de staff é operação de SQL Editor,
-- feita por quem tem acesso ao projeto. Não há policy de insert/update/delete de propósito.
revoke all on public.mimba_staff from anon;
grant select on public.mimba_staff to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Cadastrar o staff — PASSO MANUAL
-- ─────────────────────────────────────────────────────────────────────────────
-- Crie os usuários em Authentication → Users no dashboard deste projeto (Pedro e Luciano),
-- e então rode o bloco abaixo. Ele resolve o auth_user_id pelo email, então não é preciso
-- copiar UUID à mão. Idempotente.
--
--   insert into public.mimba_staff (auth_user_id, email, nome)
--   select u.id, u.email, v.nome
--     from auth.users u
--     join (values
--       ('pportella23@gmail.com', 'Pedro Portella'),
--       ('EMAIL_DO_LUCIANO',      'Luciano Mantelli')
--     ) as v(email, nome) on lower(u.email) = lower(v.email)
--   on conflict (auth_user_id) do update
--     set email = excluded.email, nome = excluded.nome;
--
-- Conferir depois:
--   select email, nome, criado_em from public.mimba_staff order by criado_em;
--
-- E testar o gate de verdade (não basta chamar como postgres, que ignora RLS):
--   set local role authenticated;
--   set local request.jwt.claims = '{"sub":"<uuid-do-usuario>","role":"authenticated"}';
--   select public.sou_staff_mimba();   -- deve dar true pra staff, false pra qualquer outro
--   reset role;
