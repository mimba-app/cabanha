-- ═══════════════════════════════════════════════════════════════════════════
-- Nutrição — refactor Fase 0 (schema)
-- Spec: docs/spec-nutricao-refactor.md
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Achado ao investigar antes de aplicar: já existiam tabelas `nutricao_itens` e
-- `nutricao_projetos` em `public` e em todos os 8 schemas de tenant (vindas do
-- `provisionar_schema_cabanha`), mas o frontend (`index.html`) NUNCA leu nem
-- escreveu nelas — zero referência no código. Formato incompleto pro que o
-- produto precisa hoje: `nutricao_itens.animal_id` era direto (sem conceito de
-- "projeto"/versão), sem tabela de templates. `cab_mae_de_deus.nutricao_itens`
-- tinha 17 linhas órfãs, todas idênticas ("Aveia", 2x ao dia, sem quantidade),
-- datadas de 2026-03-31 — resíduo de uma tentativa anterior abandonada, mesmo
-- espírito do achado de "garanhões fantasma" (ver HANDOFF.md, 2026-08-19). Sem
-- FK formal pra `animais` (confirmado via pg_constraint) — seguro migrar/
-- derrubar sem cascade em dado de terceiros.
--
-- Ordem desta migration: (1) captura as 17 linhas órfãs numa tabela de estágio
-- temporária, (2) derruba as tabelas antigas, (3) cria a estrutura nova
-- (templates + projetos, ambos com tabela de itens 1:N) no template `public`,
-- (4) replica pros 8 tenants já provisionados, (5) semeia os 7 templates que
-- hoje são a constante JS `NUT_TEMPLATES` como dados reais em cada tenant,
-- (6) migra a Mãe de Deus da tabela de estágio pra estrutura nova, (7)
-- atualiza `provisionar_schema_cabanha` (cabanhas novas) e
-- `carregar_dados_cabanha` (bootstrap de login).

begin;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 1 — Capturar o dado órfão antes de derrubar a tabela antiga
-- ═══════════════════════════════════════════════════════════════════════════

create temp table _nut_migracao_temp as
select animal_id, tipo, produto, frequencia, criado_em
from cab_mae_de_deus.nutricao_itens;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 2 — Derrubar a estrutura antiga (nunca usada pelo frontend)
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('drop table if exists %I.nutricao_itens cascade', r.schema_name);
    execute format('drop table if exists %I.nutricao_projetos cascade', r.schema_name);
  end loop;
end $$;

drop table if exists public.nutricao_itens cascade;
drop table if exists public.nutricao_projetos cascade;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 3 — Criar a estrutura nova no template `public`
-- ═══════════════════════════════════════════════════════════════════════════

create table public.nutricao_templates (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  estagio_vinculado text,
  obs text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);
comment on table public.nutricao_templates is
  'Refactor de Nutrição (spec docs/spec-nutricao-refactor.md): templates configuráveis pelo '
  'usuário, substituem a constante JS NUT_TEMPLATES. estagio_vinculado é sugestão opcional '
  '(mesmo enum de animais.estagio), não obrigatório nem único.';

create table public.nutricao_template_itens (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.nutricao_templates(id) on delete cascade,
  tipo text not null,
  produto text,
  marca text,
  quantidade text,
  frequencia text,
  periodo text,
  obs text,
  ordem integer not null default 0,
  criado_em timestamptz not null default now()
);
comment on table public.nutricao_template_itens is
  'Itens de um template nutricional — lista, não campos fixos, permite N itens do mesmo tipo '
  '(ex.: dois tipos de ração).';

create table public.nutricao_projetos (
  id uuid primary key default gen_random_uuid(),
  animal_id uuid not null references public.animais(id),
  dt_inicio date,
  dt_fim date,
  status text not null default 'ativo' check (status in ('ativo','finalizado')),
  obs_projeto text,
  template_origem_id uuid references public.nutricao_templates(id),
  med_inicial jsonb,
  med_final jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);
comment on table public.nutricao_projetos is
  'Refactor de Nutrição — substitui a tabela antiga do mesmo nome (nunca usada pelo frontend). '
  'Projeto nutricional por animal, com histórico real: ao finalizar um projeto e iniciar outro, '
  'o antigo continua consultável (status=finalizado) em vez de ser sobrescrito.';

create table public.nutricao_projeto_itens (
  id uuid primary key default gen_random_uuid(),
  projeto_id uuid not null references public.nutricao_projetos(id) on delete cascade,
  tipo text not null,
  produto text,
  marca text,
  quantidade text,
  frequencia text,
  periodo text,
  obs text,
  ordem integer not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
comment on table public.nutricao_projeto_itens is
  'Itens de um projeto nutricional — mesma ideia de nutricao_template_itens, mas por projeto de '
  'animal. Suplementos deixam de ser um array à parte e viram tipo=suplemento aqui.';

alter table public.nutricao_templates enable row level security;
alter table public.nutricao_template_itens enable row level security;
alter table public.nutricao_projetos enable row level security;
alter table public.nutricao_projeto_itens enable row level security;
revoke all privileges on public.nutricao_templates from anon;
revoke all privileges on public.nutricao_template_itens from anon;
revoke all privileges on public.nutricao_projetos from anon;
revoke all privileges on public.nutricao_projeto_itens from anon;

-- índice único parcial: no máximo 1 projeto "ativo" por animal (histórico continua permitindo
-- N projetos "finalizado" no mesmo animal)
create unique index nutricao_projetos_um_ativo_por_animal
  on public.nutricao_projetos (animal_id) where status = 'ativo';

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 4 — Replicar a estrutura nas 8 cabanhas já provisionadas
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare
  r record;
  v_tenant uuid;
  tselect text;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('create table %I.nutricao_templates (like public.nutricao_templates including all)', r.schema_name);
    execute format('create table %I.nutricao_template_itens (like public.nutricao_template_itens including all)', r.schema_name);
    execute format('create table %I.nutricao_projetos (like public.nutricao_projetos including all)', r.schema_name);
    execute format('create table %I.nutricao_projeto_itens (like public.nutricao_projeto_itens including all)', r.schema_name);

    execute format('alter table %I.nutricao_template_itens add constraint nutricao_template_itens_template_id_fkey foreign key (template_id) references %I.nutricao_templates(id) on delete cascade', r.schema_name, r.schema_name);
    execute format('alter table %I.nutricao_projetos add constraint nutricao_projetos_animal_id_fkey foreign key (animal_id) references %I.animais(id)', r.schema_name, r.schema_name);
    execute format('alter table %I.nutricao_projetos add constraint nutricao_projetos_template_origem_id_fkey foreign key (template_origem_id) references %I.nutricao_templates(id)', r.schema_name, r.schema_name);
    execute format('alter table %I.nutricao_projetos add constraint nutricao_projetos_criado_por_fkey foreign key (criado_por) references %I.usuarios(id)', r.schema_name, r.schema_name);
    execute format('alter table %I.nutricao_projeto_itens add constraint nutricao_projeto_itens_projeto_id_fkey foreign key (projeto_id) references %I.nutricao_projetos(id) on delete cascade', r.schema_name, r.schema_name);
    execute format('alter table %I.nutricao_templates add constraint nutricao_templates_criado_por_fkey foreign key (criado_por) references %I.usuarios(id)', r.schema_name, r.schema_name);

    select id into v_tenant from public.tenants where schema_name = r.schema_name;
    tselect := format('(select public.tem_acesso_tenant(%L))', v_tenant);

    execute format('alter table %I.nutricao_templates enable row level security', r.schema_name);
    execute format('alter table %I.nutricao_template_itens enable row level security', r.schema_name);
    execute format('alter table %I.nutricao_projetos enable row level security', r.schema_name);
    execute format('alter table %I.nutricao_projeto_itens enable row level security', r.schema_name);

    execute format('create policy memb_all on %I.nutricao_templates for all to authenticated using (%s) with check (%s)', r.schema_name, tselect, tselect);
    execute format('create policy memb_all on %I.nutricao_template_itens for all to authenticated using (%s) with check (%s)', r.schema_name, tselect, tselect);
    execute format('create policy memb_all on %I.nutricao_projetos for all to authenticated using (%s) with check (%s)', r.schema_name, tselect, tselect);
    execute format('create policy memb_all on %I.nutricao_projeto_itens for all to authenticated using (%s) with check (%s)', r.schema_name, tselect, tselect);

    execute format('grant select, insert, update, delete on %I.nutricao_templates to authenticated', r.schema_name);
    execute format('grant select, insert, update, delete on %I.nutricao_template_itens to authenticated', r.schema_name);
    execute format('grant select, insert, update, delete on %I.nutricao_projetos to authenticated', r.schema_name);
    execute format('grant select, insert, update, delete on %I.nutricao_projeto_itens to authenticated', r.schema_name);
    execute format('revoke all privileges on %I.nutricao_templates from anon', r.schema_name);
    execute format('revoke all privileges on %I.nutricao_template_itens from anon', r.schema_name);
    execute format('revoke all privileges on %I.nutricao_projetos from anon', r.schema_name);
    execute format('revoke all privileges on %I.nutricao_projeto_itens from anon', r.schema_name);
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 5 — Semear os 7 templates que hoje são NUT_TEMPLATES (JS) em cada tenant
-- ═══════════════════════════════════════════════════════════════════════════
-- Valores idênticos aos que já estavam calibrados na constante JS (index.html,
-- ~linha 7392) — ninguém perde o que já estava certo, só migra de lugar.

do $$
declare
  v_seed jsonb := '[
    {"nome":"CAMPO","estagio":"CAMPO","itens":[
      {"tipo":"racao","produto":"Ração crescimento","quantidade":"2 kg/dia","frequencia":"2x ao dia","obs":"Dividir manhã e tarde"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"0,5 kg/dia","frequencia":"1x ao dia","obs":""},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"0,5 kg/dia","frequencia":"1x ao dia","obs":"Feno de boa qualidade"},
      {"tipo":"verde","produto":"Azevém / Tifton / Aveia preta","quantidade":"À vontade","frequencia":"Conforme disponível","obs":"Pasto rotacionado, sazonal"},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":"Coccho coberto"}
    ]},
    {"nome":"PISTA MORFOLOGIA","estagio":"PISTA MORFOLOGIA","itens":[
      {"tipo":"racao","produto":"Ração performance","quantidade":"3 kg/dia","frequencia":"2x ao dia","obs":"Alta energia, dividido em 2 tratos"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"1 kg/dia","frequencia":"2x ao dia","obs":"0,5 kg por trato"},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"1 kg/dia","frequencia":"2x ao dia","obs":"Fornecer antes da ração"},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"Conforme disponível","obs":"Complementar ao feno"},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":"Coccho coberto"}
    ]},
    {"nome":"PISTA FUNCIONAL","estagio":"PISTA FUNCIONAL","itens":[
      {"tipo":"racao","produto":"Ração performance / trabalho","quantidade":"4 kg/dia","frequencia":"2x ao dia","obs":"Aumentar em período de provas"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"1,5 kg/dia","frequencia":"2x ao dia","obs":"0,75 kg por trato"},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"1,5 kg/dia","frequencia":"2x ao dia","obs":"Fornecer antes da ração"},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"Conforme disponível","obs":"Complementar ao feno"},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":"Coccho coberto"}
    ]},
    {"nome":"ARREIO CABANHA","estagio":"ARREIO CABANHA","itens":[
      {"tipo":"racao","produto":"Ração manutenção / performance","quantidade":"3 kg/dia","frequencia":"2x ao dia","obs":"Ajustar conforme uso"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"1 kg/dia","frequencia":"2x ao dia","obs":""},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"1 kg/dia","frequencia":"1x ao dia","obs":""},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"Conforme disponível","obs":""},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":""}
    ]},
    {"nome":"LAÇO","estagio":"LAÇO","itens":[
      {"tipo":"racao","produto":"Ração performance","quantidade":"4 kg/dia","frequencia":"2x ao dia","obs":"Alta demanda energética"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"1,5 kg/dia","frequencia":"2x ao dia","obs":""},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"1,5 kg/dia","frequencia":"2x ao dia","obs":""},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"Conforme disponível","obs":""},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":""}
    ]},
    {"nome":"DOMA","estagio":"DOMA","itens":[
      {"tipo":"racao","produto":"Ração manutenção","quantidade":"2,5 kg/dia","frequencia":"2x ao dia","obs":"Aumentar com progressão do treino"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"0,8 kg/dia","frequencia":"2x ao dia","obs":""},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"0,8 kg/dia","frequencia":"1x ao dia","obs":""},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"Conforme disponível","obs":""},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":""}
    ]},
    {"nome":"CRIA","estagio":"CRIA","itens":[
      {"tipo":"racao","produto":"Ração égua lactante","quantidade":"4 kg/dia","frequencia":"2x ao dia","obs":"Maior demanda na lactação"},
      {"tipo":"aveia","produto":"Aveia grão","quantidade":"1 kg/dia","frequencia":"2x ao dia","obs":""},
      {"tipo":"alfafa","produto":"Alfafa feno","quantidade":"2 kg/dia","frequencia":"2x ao dia","obs":"Alta proteína para produção de leite"},
      {"tipo":"verde","produto":"Azevém / Tifton","quantidade":"À vontade","frequencia":"À vontade","obs":"Pasto de qualidade"},
      {"tipo":"sal","produto":"Sal mineral equino","quantidade":"À vontade","frequencia":"À vontade","obs":""}
    ]}
  ]';
  r_tenant record;
  v_tmpl jsonb;
  v_item jsonb;
  v_tmpl_id uuid;
  v_ordem int;
begin
  for r_tenant in select schema_name from public.tenants
                  where provisionado = true
                    and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    for v_tmpl in select * from jsonb_array_elements(v_seed) loop
      v_tmpl_id := gen_random_uuid();
      execute format('insert into %I.nutricao_templates (id, nome, estagio_vinculado) values (%L, %L, %L)',
        r_tenant.schema_name, v_tmpl_id, v_tmpl->>'nome', v_tmpl->>'estagio');
      v_ordem := 0;
      for v_item in select * from jsonb_array_elements(v_tmpl->'itens') loop
        execute format('insert into %I.nutricao_template_itens (template_id, tipo, produto, quantidade, frequencia, obs, ordem) values (%L,%L,%L,%L,%L,%L,%L)',
          r_tenant.schema_name, v_tmpl_id, v_item->>'tipo', v_item->>'produto', v_item->>'quantidade', v_item->>'frequencia', v_item->>'obs', v_ordem);
        v_ordem := v_ordem + 1;
      end loop;
    end loop;
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 6 — Migrar o dado órfão capturado no Passo 1 (só cab_mae_de_deus tinha linhas)
-- ═══════════════════════════════════════════════════════════════════════════
-- Um projeto "ativo" por animal, com o item que já existia preservado (tipo=aveia).

do $$
declare rec record; v_proj_id uuid; v_item record; v_ordem int;
begin
  for rec in select animal_id, min(criado_em) as criado_em
             from _nut_migracao_temp group by animal_id
  loop
    insert into cab_mae_de_deus.nutricao_projetos (animal_id, status, criado_em)
    values (rec.animal_id, 'ativo', rec.criado_em)
    returning id into v_proj_id;

    v_ordem := 0;
    for v_item in select tipo, produto, frequencia
                  from _nut_migracao_temp where animal_id = rec.animal_id
    loop
      insert into cab_mae_de_deus.nutricao_projeto_itens (projeto_id, tipo, produto, frequencia, ordem)
      values (v_proj_id, v_item.tipo, v_item.produto, v_item.frequencia, v_ordem);
      v_ordem := v_ordem + 1;
    end loop;
  end loop;
end $$;

drop table _nut_migracao_temp;

commit;
