-- ============================================================================
-- Área de Dados (Mimba Dados) — Fase 1: catálogo, registros e storage
-- ============================================================================
-- Área de inteligência de dados restrita a staff da Mimba (public.mimba_staff).
-- É uma LANDING ZONE analítica, não um cadastro estruturado: cada arquivo vira um
-- "dataset" (metadado) + N linhas em jsonb. O schema de cada arquivo é livre.
--
-- ⚠️ ESTAS TABELAS NÃO FAZEM PARTE DO TEMPLATE DE PROVISIONAMENTO.
-- provisionar_schema_cabanha() clona só as tabelas da allowlist v_tabelas; nenhuma
-- tabela criada aqui está lá e NENHUMA deve ser adicionada. São dados de PLATAFORMA,
-- compartilhados entre todas as cabanhas — o oposto de dado por tenant.
--
-- Isolamento: RLS libera apenas para staff. Cabanhas NÃO leem estas tabelas
-- diretamente — o consumo é só via RPCs `ref_*` (SECURITY DEFINER), na fase 2.
-- ============================================================================

-- ─── 1. Catálogo de datasets ────────────────────────────────────────────────
create table if not exists public.dados_datasets (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  tipo          text not null default 'generico',   -- 'resultados_abccc' | 'generico' | ...
  descricao     text,
  fonte         text,                                -- de onde veio (URL, órgão, planilha)
  arquivo_nome  text,
  formato       text,                                -- csv | tsv | xlsx | api
  storage_path  text,                                -- caminho no bucket 'dados-mimba'
  colunas       jsonb  not null default '[]'::jsonb, -- nomes das colunas, na ordem
  total_linhas  integer not null default 0,
  status        text   not null default 'processando',
  erro          text,
  enviado_por   uuid,                                -- auth.users.id de quem subiu
  enviado_em    timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint dados_datasets_status_chk
    check (status in ('processando','publicado','erro','arquivado'))
);

comment on table public.dados_datasets is
  'Catálogo da Área de Dados (staff Mimba). NÃO clonar para schemas cab_* — é dado de plataforma.';

-- ─── 2. Linhas dos datasets (schema livre, jsonb) ───────────────────────────
create table if not exists public.dados_registros (
  id         bigint generated always as identity primary key,
  dataset_id uuid    not null references public.dados_datasets(id) on delete cascade,
  linha      integer not null,
  dados      jsonb   not null
);

comment on table public.dados_registros is
  'Linhas cruas dos datasets, uma por registro, schema livre em jsonb. NÃO clonar para cab_*.';

create index if not exists dados_registros_dataset_idx on public.dados_registros(dataset_id);
-- Índices de expressão nas chaves que as análises da ABCCC realmente consultam.
create index if not exists dados_registros_sbb_idx    on public.dados_registros((dados->>'SBB'));
create index if not exists dados_registros_pai_idx    on public.dados_registros((dados->>'Pai'));
create index if not exists dados_registros_mae_idx    on public.dados_registros((dados->>'Mãe'));
create index if not exists dados_registros_animal_idx on public.dados_registros((dados->>'Animal'));

-- ─── 3. Fontes externas (config de importadores de API) ─────────────────────
create table if not exists public.dados_fontes_externas (
  chave         text primary key,
  nome          text not null,
  url           text not null,
  headers       jsonb not null default '{}'::jsonb,
  payload       jsonb not null,                       -- corpo base da requisição
  mapa_colunas  jsonb not null default '{}'::jsonb,   -- ref da query -> rótulo amigável
  ativo         boolean not null default true,
  atualizado_em timestamptz not null default now()
);

comment on table public.dados_fontes_externas is
  'Config de importadores externos (ex.: painel público da ABCCC no Power BI). NÃO clonar para cab_*.';

-- ─── 4. touch de atualizado_em ──────────────────────────────────────────────
create or replace function public.dados_touch() returns trigger
language plpgsql as $$
begin new.atualizado_em := now(); return new; end;
$$;

drop trigger if exists trg_dados_datasets_touch on public.dados_datasets;
create trigger trg_dados_datasets_touch before update on public.dados_datasets
  for each row execute function public.dados_touch();

-- ─── 5. RLS — só staff Mimba ────────────────────────────────────────────────
alter table public.dados_datasets        enable row level security;
alter table public.dados_registros       enable row level security;
alter table public.dados_fontes_externas enable row level security;

drop policy if exists staff_all on public.dados_datasets;
create policy staff_all on public.dados_datasets for all to authenticated
  using ((select public.sou_staff_mimba())) with check ((select public.sou_staff_mimba()));

drop policy if exists staff_all on public.dados_registros;
create policy staff_all on public.dados_registros for all to authenticated
  using ((select public.sou_staff_mimba())) with check ((select public.sou_staff_mimba()));

drop policy if exists staff_all on public.dados_fontes_externas;
create policy staff_all on public.dados_fontes_externas for all to authenticated
  using ((select public.sou_staff_mimba())) with check ((select public.sou_staff_mimba()));

grant select, insert, update, delete on public.dados_datasets        to authenticated;
grant select, insert, update, delete on public.dados_registros       to authenticated;
grant select, insert, update, delete on public.dados_fontes_externas to authenticated;

revoke all on public.dados_datasets        from anon;
revoke all on public.dados_registros       from anon;
revoke all on public.dados_fontes_externas from anon;

-- ─── 6. Bucket privado para os arquivos originais ───────────────────────────
insert into storage.buckets (id, name, public, file_size_limit)
values ('dados-mimba', 'dados-mimba', false, 52428800)
on conflict (id) do nothing;

drop policy if exists dados_mimba_staff on storage.objects;
create policy dados_mimba_staff on storage.objects for all to authenticated
  using  (bucket_id = 'dados-mimba' and (select public.sou_staff_mimba()))
  with check (bucket_id = 'dados-mimba' and (select public.sou_staff_mimba()));

-- ─── 7. RPCs de catálogo (staff) ────────────────────────────────────────────
create or replace function public.dados_criar_dataset(
  p_nome text, p_tipo text default 'generico', p_descricao text default null,
  p_fonte text default null, p_arquivo_nome text default null,
  p_formato text default null, p_colunas jsonb default '[]'::jsonb,
  p_storage_path text default null
) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  insert into public.dados_datasets (nome, tipo, descricao, fonte, arquivo_nome, formato, colunas, storage_path, enviado_por)
  values (p_nome, coalesce(p_tipo,'generico'), p_descricao, p_fonte, p_arquivo_nome, p_formato,
          coalesce(p_colunas,'[]'::jsonb), p_storage_path, auth.uid())
  returning id into v_id;
  return v_id;
end; $$;

-- Insere um lote de linhas. p_linhas = array jsonb de objetos.
create or replace function public.dados_inserir_lote(p_dataset uuid, p_linhas jsonb)
returns integer language plpgsql security definer set search_path to 'public' as $$
declare v_base integer; v_n integer;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  if jsonb_typeof(p_linhas) <> 'array' then raise exception 'p_linhas deve ser um array jsonb'; end if;
  select coalesce(max(linha),0) into v_base from public.dados_registros where dataset_id = p_dataset;
  insert into public.dados_registros (dataset_id, linha, dados)
  select p_dataset, v_base + ord, valor
  from jsonb_array_elements(p_linhas) with ordinality as t(valor, ord);
  get diagnostics v_n = row_count;
  update public.dados_datasets set total_linhas = total_linhas + v_n where id = p_dataset;
  return v_n;
end; $$;

create or replace function public.dados_finalizar_dataset(
  p_dataset uuid, p_status text default 'publicado', p_erro text default null
) returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  update public.dados_datasets set status = p_status, erro = p_erro where id = p_dataset;
end; $$;

create or replace function public.dados_excluir_dataset(p_dataset uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  delete from public.dados_datasets where id = p_dataset;  -- registros caem por cascade
end; $$;

create or replace function public.dados_listar_datasets()
returns table (
  id uuid, nome text, tipo text, descricao text, fonte text, arquivo_nome text,
  formato text, storage_path text, colunas jsonb, total_linhas integer,
  status text, erro text, enviado_em timestamptz, atualizado_em timestamptz, enviado_por_nome text
) language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  return query
    select d.id, d.nome, d.tipo, d.descricao, d.fonte, d.arquivo_nome, d.formato, d.storage_path,
           d.colunas, d.total_linhas, d.status, d.erro, d.enviado_em, d.atualizado_em,
           s.nome
    from public.dados_datasets d
    left join public.mimba_staff s on s.user_id = d.enviado_por
    order by d.enviado_em desc;
end; $$;

-- Amostra das primeiras linhas — pra prévia na tela.
create or replace function public.dados_amostra(p_dataset uuid, p_limite integer default 20)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  select coalesce(jsonb_agg(dados order by linha), '[]'::jsonb) into v
  from (select linha, dados from public.dados_registros
        where dataset_id = p_dataset order by linha limit least(coalesce(p_limite,20), 200)) t;
  return v;
end; $$;

create or replace function public.dados_resumo()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  select jsonb_build_object(
    'datasets',   (select count(*) from public.dados_datasets),
    'publicados', (select count(*) from public.dados_datasets where status = 'publicado'),
    'registros',  (select count(*) from public.dados_registros),
    'ultimo_envio', (select max(enviado_em) from public.dados_datasets)
  ) into v;
  return v;
end; $$;

revoke all on function public.dados_criar_dataset(text,text,text,text,text,text,jsonb,text) from public, anon;
revoke all on function public.dados_inserir_lote(uuid,jsonb)                                from public, anon;
revoke all on function public.dados_finalizar_dataset(uuid,text,text)                       from public, anon;
revoke all on function public.dados_excluir_dataset(uuid)                                   from public, anon;
revoke all on function public.dados_listar_datasets()                                       from public, anon;
revoke all on function public.dados_amostra(uuid,integer)                                   from public, anon;
revoke all on function public.dados_resumo()                                                from public, anon;

grant execute on function public.dados_criar_dataset(text,text,text,text,text,text,jsonb,text) to authenticated;
grant execute on function public.dados_inserir_lote(uuid,jsonb)                                to authenticated;
grant execute on function public.dados_finalizar_dataset(uuid,text,text)                       to authenticated;
grant execute on function public.dados_excluir_dataset(uuid)                                   to authenticated;
grant execute on function public.dados_listar_datasets()                                       to authenticated;
grant execute on function public.dados_amostra(uuid,integer)                                   to authenticated;
grant execute on function public.dados_resumo()                                                to authenticated;
