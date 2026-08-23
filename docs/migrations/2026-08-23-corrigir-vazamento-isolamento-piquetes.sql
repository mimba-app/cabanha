-- CORREÇÃO DE ISOLAMENTO (prioridade máxima, achado durante investigação de
-- performance): a tabela `piquetes` tem, em `public` (template) e em 7 das 8
-- cabanhas já provisionadas (todas menos cab_cabanha_tupan), DUAS policies
-- permissivas para `authenticated`/`ALL`:
--   - `memb_all`      → qual = tem_acesso_tenant(<tenant_id>)   (correta)
--   - `piquetes_auth` → qual = true                              (sem checagem nenhuma)
-- Policies permissivas se combinam com OR — a policy `piquetes_auth` (true)
-- anula completamente a `memb_all`, deixando `piquetes` sem isolamento real:
-- qualquer usuário autenticado de QUALQUER cabanha pode ler/escrever piquetes
-- de qualquer outra cabanha. Confirmado via pg_policies (qual='true' AND
-- roles ? 'authenticated') — nenhuma outra tabela tem esse padrão, é
-- isolado a `piquetes`.
--
-- Fix: dropar `piquetes_auth`, mantendo só `memb_all` (que já existe e já
-- está correta) — em `public` e em cada schema `cab_*` já provisionado.
drop policy if exists piquetes_auth on public.piquetes;

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    -- cab_cabanha_tupan não tem a tabela piquetes (nasceu depois dela virar
    -- opcional/removida do template numa fase intermediária) — "drop policy
    -- if exists" só protege contra a POLICY não existir, não a TABELA.
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'piquetes') then
      execute format('drop policy if exists piquetes_auth on %I.piquetes', r.schema_name);
    end if;
  end loop;
end $$;
