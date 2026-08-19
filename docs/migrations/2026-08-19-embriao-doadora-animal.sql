-- Reprodutivo v4 — Fase 14: fonte tipo "embriao" ganha vínculo opcional com um animal
-- cadastrado (a doadora), quando o embrião é de uma égua própria da cabanha.
-- docs/spec-reprodutivo-v4-saude-vet.md, seção 8 (Fase 14)
--
-- Diferente da reversão feita pra "Cota" na Fase 12 (Cota nunca é um animal da cabanha, então
-- nunca deveria vincular) — embrião "próprio" é geneticamente de uma égua real do plantel, então
-- faz sentido apontar pra ela direto. Nullable: embrião "adquirido" (externo) continua sem
-- vínculo nenhum, só nome/SBB em texto livre, igual Direito de uso/Cobertura.

alter table public.fontes_cobertura add column if not exists doadora_animal_id uuid null references public.animais(id);
comment on column public.fontes_cobertura.doadora_animal_id is
  'Reprodutivo v4 (spec Fase 14): só usado em tipo=embriao — quando o embrião é de uma égua
   própria da cabanha (qualquer estágio, não só Cria), aponta pra ela. Null = embrião adquirido
   de fora, sem vínculo com animal cadastrado.';

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.fontes_cobertura add column if not exists doadora_animal_id uuid null references %I.animais(id)', r.schema_name, r.schema_name);
  end loop;
end $$;
