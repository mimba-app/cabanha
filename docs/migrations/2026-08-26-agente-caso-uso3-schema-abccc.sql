-- Agente Mimba, caso de uso 3 (especialista ABCCC) — ADR 0009 + ADR 0010.
--
-- Duas tabelas novas em produção (fmjfvfufkqswweyasjyp), alimentadas por um job
-- de sincronização periódica que roda FORA do caminho de requisição de
-- qualquer cabanha (lê do Mimba Lab com credencial própria, escreve aqui).
-- Preserva literalmente a invariante da ADR 0010: nenhuma requisição de
-- cabanha toca o projeto analítico, nem direta nem por proxy.
--
-- Nenhuma das duas entra na lista `v_tabelas` de `provisionar_schema_cabanha()`
-- (hardcoded, conferido antes de escrever esta migration) — não são dado de
-- tenant, não devem existir dentro de nenhum schema cab_*, mesmo padrão de
-- `planos`/`preferencias_sistema`.

-- 1. Resumo por SBB, pronto pra narrativa do agente (linha alta/baixa,
--    participações, produção de finalistas, árvore crua de 5 gerações).
create table public.abccc_estatisticas_animal (
  sbb text primary key,
  nome text not null,
  sexo text,
  sbb_pai text,
  sbb_mae text,
  linha_alta text,
  linha_baixa text,
  ancestrais_pos jsonb,
  participacoes jsonb not null default '[]'::jsonb,
  finalistas_produzidos jsonb not null default '{}'::jsonb,
  sincronizado_em timestamptz not null default now()
);

comment on table public.abccc_estatisticas_animal is
  'Resumo estatistico/genealogico por SBB, sincronizado periodicamente do Mimba Lab '
  '(njynlsugmvtuvcczmuld). Nao pertence a nenhum tenant -- NAO incluir na lista '
  'v_tabelas de provisionar_schema_cabanha(). Ver ADR 0009 e ADR 0010.';
comment on column public.abccc_estatisticas_animal.linha_alta is
  'Nome do pai direto (garanhao). Formato pronto pro system prompt do agente.';
comment on column public.abccc_estatisticas_animal.linha_baixa is
  'Formato fixo "[mae] que vem a ser [avo materno]" -- ver docs/agente-ia-base-conhecimento-abccc.md secao 1.';
comment on column public.abccc_estatisticas_animal.ancestrais_pos is
  'Arvore crua de 5 geracoes, mesmo formato de animais_genealogia.ancestrais_pos no Lab '
  '(sem SELECT/JOIN adicional no Lab por consulta do agente).';
comment on column public.abccc_estatisticas_animal.participacoes is
  'Array [{prova, tier, ciclo, colocacao, peso}] -- peso calculado na sincronizacao '
  'a partir da hierarquia de colocacao (ver ADR 0009 / base de conhecimento secao 6).';
comment on column public.abccc_estatisticas_animal.finalistas_produzidos is
  'Objeto {prova: contagem} de descendentes distintos que apareceram como finalistas '
  'daquele garanhao/egua, por prova -- evidencia citavel (base de conhecimento secao 4.2).';

alter table public.abccc_estatisticas_animal enable row level security;

create policy "abccc_estatisticas_leitura" on public.abccc_estatisticas_animal
  for select to authenticated using (true);

create policy "abccc_estatisticas_service_role" on public.abccc_estatisticas_animal
  for all to service_role using (true) with check (true);

-- 2. Ranking de linhagens em alta -- dado derivado, recalculado a cada
--    sincronizacao (nao editado a mao, nunca hardcoded -- base de conhecimento
--    secao 4.3).
create table public.abccc_linhagens_em_alta (
  id bigint generated always as identity primary key,
  prova text not null,
  janela text not null,
  sbb_ancestral text,
  nome_ancestral text not null,
  contagem_finalistas integer not null,
  posicao_ranking integer not null,
  sincronizado_em timestamptz not null default now(),
  unique (prova, janela, nome_ancestral)
);

comment on table public.abccc_linhagens_em_alta is
  'Ranking de recorrencia de ancestrais na 5a geracao dos finalistas/campeoes recentes, '
  'por prova principal. Recalculado inteiro a cada job de sincronizacao (substitui as '
  'linhas da mesma prova/janela). Ver ADR 0009 secao 4.3.';
comment on column public.abccc_linhagens_em_alta.janela is
  'Descricao do recorte usado no calculo (ex.: "Morfologia Expointer 2026, 252 finalistas") '
  '-- nao um enum fixo, o job decide o recorte a cada rodada.';

create index abccc_linhagens_em_alta_prova_janela_idx
  on public.abccc_linhagens_em_alta (prova, janela, posicao_ranking);

alter table public.abccc_linhagens_em_alta enable row level security;

create policy "abccc_linhagens_leitura" on public.abccc_linhagens_em_alta
  for select to authenticated using (true);

create policy "abccc_linhagens_service_role" on public.abccc_linhagens_em_alta
  for all to service_role using (true) with check (true);

revoke all on public.abccc_estatisticas_animal from anon;
revoke all on public.abccc_linhagens_em_alta from anon;
