-- Reprodutivo v4 — Fase 13: flag "receptora_externa" no cadastro de Animais.
-- docs/spec-reprodutivo-v4-saude-vet.md, seção 8 (Fase 13)
--
-- Diferente do papel "receptora" ephemeral por ciclo (Fase 8b, derivado de
-- acasalamentos.receptora_animal_id — não persiste no cadastro), esta é uma flag
-- PERMANENTE de origem/propósito do cadastro: marca que o animal não é do plantel da
-- cabanha, foi cadastrado só pra receber um embrião via TE e fica sob cuidado
-- temporário enquanto estiver gestante. Usada pra: (1) mostrar um selo visual bem
-- claro em toda listagem/ficha, diferenciando de um animal "de verdade" da cabanha;
-- (2) quando a gestação em que ela é receptora encerra (parto/aborto/perda), mudar a
-- situação dela sozinho pra "TRANSFERIDO" (ela "some" das listagens de "Na Cabanha").

alter table public.animais add column if not exists receptora_externa boolean not null default false;
comment on column public.animais.receptora_externa is
  'Reprodutivo v4 (spec Fase 13): true = animal cadastrado só pra servir de receptora de
   embrião (TE), não é do plantel da cabanha — sai sozinho (situacao=TRANSFERIDO) quando a
   gestação em que ela é receptora encerra (parto/aborto/perda).';

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.animais add column if not exists receptora_externa boolean not null default false', r.schema_name);
  end loop;
end $$;
