-- Reprodutivo v4 — Fase 8 (revisão pós-feedback): coluna "recorrente" em fontes_cobertura
-- docs/spec-reprodutivo-v4-saude-vet.md, ponto 4c
--
-- Fonte tipo "Direito de uso" ganha uma flag opcional: quando marcada, a mesma fonte (mesma
-- quantidade) nasce sozinha no próximo ciclo, sem precisar relançar manualmente — análogo ao que a
-- Fase 2 já fez pro tipo Próprio (nasce sozinha por ciclo a partir de qtd_coberturas_padrao), só
-- que aqui o "padrão" é o próprio valor da fonte recorrente no ciclo anterior (ver
-- renderPlanejadorReprodutivo() no index.html). Coluna simples, mesma tabela já coberta pelas
-- policies existentes (tem_acesso_tenant) — não precisou de revisão de RLS/isolamento
-- (revisor-isolamento): não há policy nova, grant novo, nem mudança de shape de acesso, mesmo
-- padrão de qtd_coberturas_padrao/castrado (Fase 0).

alter table public.fontes_cobertura add column if not exists recorrente boolean not null default false;
comment on column public.fontes_cobertura.recorrente is
  'Reprodutivo v4 (spec Fase 8, ponto 4c): só usada pra tipo=direito_uso — quando true, a fonte
   persiste automaticamente (mesma quantidade) pro próximo ciclo, sem relançamento manual.';

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.fontes_cobertura add column if not exists recorrente boolean not null default false', r.schema_name);
  end loop;
end $$;
