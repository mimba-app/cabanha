-- Reprodutivo v4 — Fase 7: coluna de foto no cadastro de Animais
-- docs/spec-reprodutivo-v4-saude-vet.md, seção 8 (Fase 7)
--
-- Mesmo padrão já usado pra laudos (vacinacoes.laudo_url/exames.laudo_url): base64 (data URI) direto
-- num campo text, sem bucket de Storage — a foto é lida via FileReader no browser (limite 5MB) e
-- persistida como está, sem infra nova.

alter table public.animais add column if not exists foto_url text;
comment on column public.animais.foto_url is
  'Reprodutivo v4 (spec Fase 7): foto do animal, mesmo padrão de vacinacoes/exames.laudo_url — data URI
   base64 direto no campo, sem bucket de Storage. Limite de 5MB aplicado no client (FileReader).';

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.animais add column if not exists foto_url text', r.schema_name);
  end loop;
end $$;
