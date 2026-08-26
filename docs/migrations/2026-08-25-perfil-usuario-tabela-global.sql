-- ADR 0008: corrige o bug de "Meu Perfil" salvando em `usuarios_master` (tabela
-- legada, RLS service_role only, id de espaço errado — ver ADR pra detalhe).
-- Cria `preferencias_usuario`, control-plane, 1:1 com a identidade global
-- (auth.users.id), NÃO clonada por tenant (mesma categoria de tenants/
-- tenant_memberships/mimba_staff — a skill nova-migration-tenant não se aplica
-- aqui).
--
-- Nome NÃO é `perfil_usuario`: já existe um ENUM public.perfil_usuario
-- (adm/vet/cab, usado em usuarios.perfil em todo schema cab_*) — colidiria.

create table public.preferencias_usuario (
  auth_user_id      uuid primary key references auth.users(id) on delete cascade,
  cargo             text,
  telefone_pessoal  text,
  foto_url          text,
  notif_email       boolean not null default true,
  idioma            text not null default 'pt-BR',
  fuso_horario      text not null default 'America/Sao_Paulo',
  updated_at        timestamptz not null default now()
);

comment on table public.preferencias_usuario is
  'Preferências pessoais do usuário (Conta > Meu Perfil), 1:1 com auth.users. '
  'Não é template por-tenant — igual tenants/tenant_memberships. Ver ADR 0008.';

alter table public.preferencias_usuario enable row level security;

create policy self_select on public.preferencias_usuario for select
  to authenticated
  using ((select auth.uid()) = auth_user_id);

create policy self_upsert on public.preferencias_usuario for insert
  to authenticated
  with check ((select auth.uid()) = auth_user_id);

create policy self_update on public.preferencias_usuario for update
  to authenticated
  using ((select auth.uid()) = auth_user_id)
  with check ((select auth.uid()) = auth_user_id);
