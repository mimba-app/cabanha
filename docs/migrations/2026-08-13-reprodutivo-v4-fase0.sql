-- Reprodutivo v4 — Fase 0: fundação de banco
-- docs/spec-reprodutivo-v4-saude-vet.md, seção 8 (Fase 0)
--
-- Resolve o único ponto técnico deixado em aberto na spec: `reproducao_estagios` referencia
-- `acasalamentos` (não `gestacoes`) — o funil do veterinário (Controle → Inseminação →
-- Ovuladas → DG precoce) acontece TODO antes de existir uma linha em `gestacoes` (que só nasce
-- confirmada, com `data_confirmacao not null`). `acasalamentos` já tem status
-- rascunho/simulado/aprovado/em_curso/confirmado/cancelado e `tipo_cobertura` — o campo
-- `tipo_cobertura` deixa de ser preenchido pelo criador na criação (spec 3.4, "marcar como
-- reprodutora" removida) e passa a ser decidido pelo veterinário no estágio Controle (spec 4.1),
-- por isso vira nullable aqui. Não duplicamos o campo em `reproducao_estagios` — é 1:1 com
-- `acasalamentos`, então o valor mora só lá.
--
-- Aplicar em: template public (passo 1) + todos os schemas cab_* existentes (passo 2).
-- MCP do Supabase é read-only pra writes — rodar este arquivo inteiro no SQL Editor.

begin;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 1 — Template `public`
-- ═══════════════════════════════════════════════════════════════════════════

-- Animais × Reprodutivo (spec seção 2, 3.3, 3.5)
alter table public.animais
  add column if not exists castrado boolean not null default false,
  add column if not exists qtd_coberturas_padrao integer not null default 120,
  add column if not exists receptora boolean not null default false;

alter table public.animais
  drop constraint if exists animais_qtd_coberturas_padrao_check;
alter table public.animais
  add constraint animais_qtd_coberturas_padrao_check check (qtd_coberturas_padrao >= 0);

comment on column public.animais.castrado is
  'Reprodutivo v4 (spec seção 2): macho castrado some do Plantel disponível e de seleção em '
  'planejamentos novos. Histórico (acasalamentos/coberturas já registrados) não é afetado.';
comment on column public.animais.qtd_coberturas_padrao is
  'Reprodutivo v4 (spec 3.3): saldo padrão sugerido pra fonte "Próprio" no planejador, por ciclo. '
  'Default 120 (limite regulatório ABCCC); editável no cadastro (muda o padrão) ou só pra diminuir '
  'dentro de um ciclo específico. Não substitui o teto de 240 pra Demérito (ver fontes_cobertura.demerito).';
comment on column public.animais.receptora is
  'Reprodutivo v4 (spec 3.5): flag estruturada de receptora de TE, substitui o texto livre que '
  'era digitado em Observações. UI deve exigir SBB preenchido antes de permitir marcar.';

-- Fontes de Cobertura → "Garanhões e Coberturas" (spec 3.3, 3.5): novos tipos.
alter table public.fontes_cobertura
  drop constraint if exists fontes_cobertura_tipo_check;
alter table public.fontes_cobertura
  add constraint fontes_cobertura_tipo_check
  check (tipo = any (array['proprio','cota','direito_uso','cobertura','embriao']));

-- Acasalamentos (spec 3.5, 4.1): vínculo com a receptora física (só relevante em TE) + tipo de
-- cobertura deixa de ser obrigatório na criação (passa a ser decidido pelo veterinário depois).
alter table public.acasalamentos
  add column if not exists receptora_animal_id uuid references public.animais(id);
alter table public.acasalamentos
  alter column tipo_cobertura drop not null;

comment on column public.acasalamentos.receptora_animal_id is
  'Reprodutivo v4 (spec 3.5): preenchido só quando tipo_cobertura = TE. A doadora do embrião '
  'continua sendo egua_id (dona do registro/da gestação) — este campo só identifica quem está '
  'gestando fisicamente, pra exibição ("Gestação X na receptora Y") e pra nunca virar mãe no '
  'registro de nascimento.';
comment on column public.acasalamentos.tipo_cobertura is
  'Reprodutivo v4 (spec 3.4/4.1): deixou de ser preenchido pelo criador na criação do '
  'acasalamento — agora é decidido pelo veterinário ao entrar no estágio "Controle" do funil '
  '(reproducao_estagios). Nullable enquanto aguarda essa decisão.';

-- Kanban do veterinário (spec 4): 1 linha por acasalamento que entrou no funil.
create table if not exists public.reproducao_estagios (
  id uuid primary key default gen_random_uuid(),
  acasalamento_id uuid not null unique references public.acasalamentos(id),
  estagio text not null default 'controle'
    check (estagio in ('controle','inseminacao','ovuladas','dg_precoce')),
  data_entrada_estagio timestamptz not null default now(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);
comment on table public.reproducao_estagios is
  'Reprodutivo v4 (spec 4.1): kanban do veterinário. 1:1 com acasalamentos — criada quando o '
  'criador libera o planejamento (acasalamentos.status vira aprovado/em_curso). estagio '
  'controle→inseminacao→ovuladas→dg_precoce; ao confirmar DG definitivo a linha some (ou vira '
  'histórico) e nasce a gestação real em public.gestacoes. data_entrada_estagio é a base dos '
  'alertas de janela (3-7d, 15-20d, ~45d, seção 4.1) — resetar a cada transição de estágio. O '
  'bloqueio visual de éguas com gestação ativa do ciclo atual (seção 3.1/4.1) é calculado em '
  'tempo de leitura (join com gestacoes abertas), não é uma coluna aqui — evita flag desatualizada.';

-- Atividades soltas do veterinário durante o funil (spec 4.2).
create table if not exists public.reproducao_atividades (
  id uuid primary key default gen_random_uuid(),
  acasalamento_id uuid not null references public.acasalamentos(id),
  tipo text not null check (tipo in ('medicacao','toque','ultrassom','comentario')),
  data date not null default current_date,
  obs text,
  criado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);
comment on table public.reproducao_atividades is
  'Reprodutivo v4 (spec 4.2): histórico de evolução (medicação/toque/ultrassom/comentário) '
  'registrado pelo veterinário em qualquer ponto do funil, do planejamento liberado até a '
  'confirmação de prenhez.';

-- Tratamentos (spec seção 5): nova categoria em Saúde & Vacinas, mesmo espírito de vermifugacoes.
create table if not exists public.tratamentos (
  id uuid primary key default gen_random_uuid(),
  animal_id uuid not null references public.animais(id),
  data_inicio date not null,
  data_fim date,
  descricao text not null,
  resp text,
  obs text,
  criado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios(id)
);
comment on table public.tratamentos is
  'Reprodutivo v4 (spec seção 5): machucados, medicação por período etc. — categoria nova em '
  'Saúde & Vacinas, ao lado de Vacinação/Vermifugação/Exames.';

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 2 — Replicar em todos os schemas cab_* já provisionados
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.animais add column if not exists castrado boolean not null default false', r.schema_name);
    execute format('alter table %I.animais add column if not exists qtd_coberturas_padrao integer not null default 120', r.schema_name);
    execute format('alter table %I.animais add column if not exists receptora boolean not null default false', r.schema_name);
    execute format('alter table %I.animais drop constraint if exists animais_qtd_coberturas_padrao_check', r.schema_name);
    execute format('alter table %I.animais add constraint animais_qtd_coberturas_padrao_check check (qtd_coberturas_padrao >= 0)', r.schema_name);

    execute format('alter table %I.fontes_cobertura drop constraint if exists fontes_cobertura_tipo_check', r.schema_name);
    execute format($f$alter table %I.fontes_cobertura add constraint fontes_cobertura_tipo_check check (tipo = any (array['proprio','cota','direito_uso','cobertura','embriao']))$f$, r.schema_name);

    execute format('alter table %I.acasalamentos add column if not exists receptora_animal_id uuid references %I.animais(id)', r.schema_name, r.schema_name);
    execute format('alter table %I.acasalamentos alter column tipo_cobertura drop not null', r.schema_name);

    execute format($f$
      create table if not exists %I.reproducao_estagios (
        id uuid primary key default gen_random_uuid(),
        acasalamento_id uuid not null unique references %I.acasalamentos(id),
        estagio text not null default 'controle'
          check (estagio in ('controle','inseminacao','ovuladas','dg_precoce')),
        data_entrada_estagio timestamptz not null default now(),
        criado_em timestamptz not null default now(),
        atualizado_em timestamptz not null default now(),
        criado_por uuid references %I.usuarios(id)
      )$f$, r.schema_name, r.schema_name, r.schema_name);

    execute format($f$
      create table if not exists %I.reproducao_atividades (
        id uuid primary key default gen_random_uuid(),
        acasalamento_id uuid not null references %I.acasalamentos(id),
        tipo text not null check (tipo in ('medicacao','toque','ultrassom','comentario')),
        data date not null default current_date,
        obs text,
        criado_em timestamptz not null default now(),
        criado_por uuid references %I.usuarios(id)
      )$f$, r.schema_name, r.schema_name, r.schema_name);

    execute format($f$
      create table if not exists %I.tratamentos (
        id uuid primary key default gen_random_uuid(),
        animal_id uuid not null references %I.animais(id),
        data_inicio date not null,
        data_fim date,
        descricao text not null,
        resp text,
        obs text,
        criado_em timestamptz not null default now(),
        criado_por uuid references %I.usuarios(id)
      )$f$, r.schema_name, r.schema_name, r.schema_name);

    -- RLS + grants nas 3 tabelas novas, replicando exatamente o padrão real já em uso nas
    -- demais tabelas operacionais do tenant (confirmado em cab_mae_de_deus.fontes_cobertura):
    -- 4 policies por tabela (select/insert/update/delete), cada uma com
    -- tem_acesso_tenant((select tenants.id from tenants where tenants.schema_name = '<literal>')),
    -- authenticated apenas — anon sem grant nenhum.
    declare
      tselect text := format(
        '(select public.tem_acesso_tenant((select tenants.id from tenants where tenants.schema_name = %L)))',
        r.schema_name
      );
    begin
      execute format('alter table %I.reproducao_estagios enable row level security', r.schema_name);
      execute format('alter table %I.reproducao_atividades enable row level security', r.schema_name);
      execute format('alter table %I.tratamentos enable row level security', r.schema_name);

      for r2 in select unnest(array['reproducao_estagios','reproducao_atividades','tratamentos']) as tabela loop
        execute format('drop policy if exists %I_select on %I.%I', r2.tabela, r.schema_name, r2.tabela);
        execute format('create policy %I_select on %I.%I for select to authenticated using (%s)',
          r2.tabela, r.schema_name, r2.tabela, tselect);
        execute format('drop policy if exists %I_insert on %I.%I', r2.tabela, r.schema_name, r2.tabela);
        execute format('create policy %I_insert on %I.%I for insert to authenticated with check (%s)',
          r2.tabela, r.schema_name, r2.tabela, tselect);
        execute format('drop policy if exists %I_update on %I.%I', r2.tabela, r.schema_name, r2.tabela);
        execute format('create policy %I_update on %I.%I for update to authenticated using (%s) with check (%s)',
          r2.tabela, r.schema_name, r2.tabela, tselect, tselect);
        execute format('drop policy if exists %I_delete on %I.%I', r2.tabela, r.schema_name, r2.tabela);
        execute format('create policy %I_delete on %I.%I for delete to authenticated using (%s)',
          r2.tabela, r.schema_name, r2.tabela, tselect);

        execute format('grant select, insert, update, delete on %I.%I to authenticated', r.schema_name, r2.tabela);
      end loop;
    end;
  end loop;
end $$;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASSO 3 — Atualizar o provisionamento (cabanhas NOVAS a partir de agora)
-- ═══════════════════════════════════════════════════════════════════════════
-- `create table (like public.X including all)` NÃO copia foreign keys entre schemas — só as 3
-- tabelas novas seriam criadas "soltas" (sem FK) numa cabanha provisionada a partir de agora,
-- se a RPC não fosse atualizada. Mesmo padrão de fix-up que já existia pra
-- gestacoes_protocolo_aplicado_id_fkey (única FK que a RPC já corrigia manualmente até aqui).
--
-- ⚠️ Achado no caminho, fora do escopo desta fase: os FKs de acasalamentos (egua_id,
-- fonte_cobertura_id, veterinario_id, aprovado_por, criado_por) também não são recriados pela
-- RPC pra tenants novos hoje — só existem nos tenants já provisionados porque foram corrigidos
-- por uma migration manual em algum momento do Reprodutivo v2/v3, sem nunca voltar pra cá. Não
-- mexido aqui (não é regressão desta fase, já era assim); registrado no HANDOFF.md pra alguém
-- revisar com calma depois.

create or replace function public.provisionar_schema_cabanha(p_schema text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_tenant  uuid;
  t         text;
  trg       record;
  v_tabelas text[] := array[
    'usuarios','animais','vacinacoes','exames','vermifugacoes','medidas',
    'fontes_cobertura','acasalamentos','tentativas','gestacoes',
    'protocolos_reproducao','protocolo_aplicado','coberturas_negociadas',
    'reproducao_estagios','reproducao_atividades','tratamentos',
    'eventos','eventos_animais','estoque_itens','estoque_movimentos',
    'lancamentos','pendencias','nutricao_itens','nutricao_projetos',
    'sangues_linhagem','animal_midia','audit_log'];
begin
  select id into v_tenant from public.tenants where schema_name = p_schema;
  if v_tenant is null then
    raise exception 'Tenant inexistente para o schema % (crie a linha em public.tenants antes)', p_schema;
  end if;

  execute format('create schema if not exists %I', p_schema);

  foreach t in array v_tabelas loop
    execute format('drop table if exists %I.%I cascade', p_schema, t);
    execute format('create table %I.%I (like public.%I including all)', p_schema, t, t);
    execute format('alter table %I.%I enable row level security', p_schema, t);
  end loop;

  execute format('alter table %I.gestacoes add constraint gestacoes_protocolo_aplicado_id_fkey foreign key (protocolo_aplicado_id) references %I.protocolo_aplicado(id)', p_schema, p_schema);

  -- Reprodutivo v4 (Fase 0): FKs novas que a cópia por LIKE não traz.
  execute format('alter table %I.acasalamentos add constraint acasalamentos_receptora_animal_id_fkey foreign key (receptora_animal_id) references %I.animais(id)', p_schema, p_schema);
  execute format('alter table %I.reproducao_estagios add constraint reproducao_estagios_acasalamento_id_fkey foreign key (acasalamento_id) references %I.acasalamentos(id)', p_schema, p_schema);
  execute format('alter table %I.reproducao_atividades add constraint reproducao_atividades_acasalamento_id_fkey foreign key (acasalamento_id) references %I.acasalamentos(id)', p_schema, p_schema);
  execute format('alter table %I.tratamentos add constraint tratamentos_animal_id_fkey foreign key (animal_id) references %I.animais(id)', p_schema, p_schema);

  execute format('create sequence if not exists %I.audit_log_id_seq owned by %I.audit_log.id', p_schema, p_schema);
  execute format('alter table %I.audit_log alter column id set default nextval(%L)', p_schema, p_schema || '.audit_log_id_seq');

  foreach t in array v_tabelas loop
    if t = 'audit_log' then
      execute format('create policy memb_read on %I.audit_log for select to authenticated using ((select public.tem_acesso_tenant(%L)))', p_schema, v_tenant);
      execute format('create policy memb_insert on %I.audit_log for insert to authenticated with check (false)', p_schema);
    else
      execute format('create policy memb_all on %I.%I for all to authenticated using ((select public.tem_acesso_tenant(%L))) with check ((select public.tem_acesso_tenant(%L)))', p_schema, t, v_tenant, v_tenant);
    end if;
  end loop;

  for trg in
    select c.relname as tabela, pg_get_triggerdef(tg.oid) as def
    from pg_trigger tg
    join pg_class c on c.oid = tg.tgrelid and c.relnamespace = 'public'::regnamespace
    where not tg.tgisinternal and c.relname = any(v_tabelas)
  loop
    execute replace(trg.def,
                    format(' ON public.%I ', trg.tabela),
                    format(' ON %I.%I ', p_schema, trg.tabela));
  end loop;

  execute format('grant usage on schema %I to authenticated', p_schema);
  execute format('grant select, insert, update, delete on all tables in schema %I to authenticated', p_schema);
  execute format('grant usage, select on all sequences in schema %I to authenticated', p_schema);
  execute format('revoke all privileges on all tables in schema %I from anon', p_schema);

  return jsonb_build_object('schema', p_schema, 'tenant_id', v_tenant,
                            'tabelas', array_length(v_tabelas,1), 'status', 'concluido');
exception when others then
  raise exception 'Erro ao provisionar %: %', p_schema, sqlerrm;
end;
$function$;
