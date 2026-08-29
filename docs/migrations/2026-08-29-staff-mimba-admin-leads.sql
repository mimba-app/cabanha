-- Admin de staff Mimba (pedido direto do founder, 2026-08-29): tela simples
-- pra ver os leads capturados na landing (public.leads), mas SÓ pra quem é
-- staff da Mimba (Pedro, Luciano, Thiago) -- nunca pra admin de cabanha
-- (tenant_memberships.perfil='adm' é outra coisa completamente, não dá acesso
-- a nada disso).
--
-- Padrão: tabela de controle sem NENHUM grant a anon/authenticated (mesmo
-- padrão de leads/signups) + função SECURITY DEFINER que só ela enxerga essa
-- tabela, usada como condição de uma policy de leitura em public.leads.

create table public.staff_mimba (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

comment on table public.staff_mimba is
  'Staff Mimba (não é dado de tenant) -- quem está aqui pode ver telas internas '
  'como a de leads. Gerenciado manualmente via SQL/dashboard, não tem UI de '
  'cadastro. Não confundir com tenant_memberships (perfil de cabanha).';

alter table public.staff_mimba enable row level security;
-- Sem policy de propósito: default-deny pra anon/authenticated via PostgREST.
-- service_role e funções SECURITY DEFINER continuam enxergando.

-- Staff atual (ids já existentes em auth.users, conferidos em 2026-08-29):
insert into public.staff_mimba (id, nome, email) values
  ('acc1fe58-9908-499e-9d23-5ddb24da4315', 'Pedro Portella', 'pportella23@gmail.com'),
  ('37931872-f901-4a9e-807c-3e2cab58c7f1', 'Luciano Mantelli', 'luciano.mantelli@fourge.com.br'),
  ('fdf06b75-6027-4994-b83e-f79694d490dc', 'Thiago Persici', 'thiagopersici@gmail.com');

create or replace function public.is_staff_mimba()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.staff_mimba where id = auth.uid() and ativo = true
  );
$$;

comment on function public.is_staff_mimba() is
  'true se o usuário autenticado (auth.uid()) é staff Mimba ativo. '
  'SECURITY DEFINER porque staff_mimba não tem grant nenhum a authenticated.';

-- CREATE FUNCTION concede EXECUTE a PUBLIC por padrão -- fecha isso (anon é
-- membro de PUBLIC) e reabre só pra quem precisa checar a própria condição.
revoke execute on function public.is_staff_mimba() from public;
grant execute on function public.is_staff_mimba() to authenticated;

-- Única policy de leitura de leads pra usuário autenticado -- só passa quem for staff.
create policy leads_staff_leitura on public.leads
  for select to authenticated
  using ( (select public.is_staff_mimba()) );
