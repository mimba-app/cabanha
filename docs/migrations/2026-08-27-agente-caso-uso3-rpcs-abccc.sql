-- RPCs abccc_* pro agente de IA (caso de uso 3, ADR 0009) consultar o resumo
-- sincronizado do Mimba Lab. Nenhuma delas toca schema de tenant (cab_*) --
-- por isso NAO precisam de tem_acesso_tenant nem SECURITY DEFINER. A ponte com
-- o animal da propria cabanha do usuario acontece em duas chamadas de
-- ferramenta separadas do modelo (cab_buscar_animal pra achar o SBB, depois
-- estas RPCs com esse SBB) -- nunca um JOIN cross-schema dentro da RPC, exatamente
-- a recomendacao do revisor-isolamento na revisao do schema (2026-08-26).

create or replace function public.abccc_resumo_animal(p_sbb text)
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'sbb', sbb,
    'nome', nome,
    'sexo', sexo,
    'linha_alta', linha_alta,
    'linha_baixa', linha_baixa,
    'participacoes', participacoes,
    'finalistas_produzidos', finalistas_produzidos,
    'ancestrais_pos', ancestrais_pos
  )
  from public.abccc_estatisticas_animal
  where sbb = upper(trim(p_sbb));
$$;

comment on function public.abccc_resumo_animal is
  'RPC read-only pro agente de IA (caso de uso 3, ADR 0009): resumo narrativo por SBB '
  '(linha alta/baixa, participacoes com peso, finalistas produzidos, arvore de 5 geracoes). '
  'Nao depende de tenant -- dado agregado da raca, sincronizado do Mimba Lab, nao pertence '
  'a nenhuma cabanha especifica. Retorna null se o SBB nao estiver sincronizado.';

create or replace function public.abccc_ranking_linhagens(p_prova text default null, p_limite int default 5)
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  -- LIMIT flat depois de "order by prova, posicao_ranking" estouraria o limite
  -- inteiro na primeira prova em ordem alfabetica quando p_prova e null (bug
  -- encontrado em 2026-08-27 testando com p_prova=null: "Doma de Ouro" vinha
  -- antes de "Final Freio de Ouro"/"Morfologia Expointer" alfabeticamente e
  -- tomava as 6 vagas sozinho). row_number() particionado por prova garante
  -- o top de CADA prova, nao so da primeira.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'prova', prova, 'janela', janela, 'sbb_ancestral', sbb_ancestral,
        'nome_ancestral', nome_ancestral, 'contagem_finalistas', contagem_finalistas,
        'posicao_ranking', posicao_ranking
      )
      order by prova, posicao_ranking
    ),
    '[]'::jsonb
  )
  from (
    select prova, janela, sbb_ancestral, nome_ancestral, contagem_finalistas, posicao_ranking,
           row_number() over (partition by prova order by posicao_ranking) as rn
    from public.abccc_linhagens_em_alta
    where p_prova is null or prova = p_prova
  ) x
  where rn <= least(greatest(p_limite, 1), 50);
$$;

comment on function public.abccc_ranking_linhagens is
  'RPC read-only pro agente de IA (caso de uso 3, ADR 0009): ranking dos garanhoes que mais '
  'produziram finalistas no ciclo mais recente de cada prova principal (Morfologia Expointer, '
  'Final Freio de Ouro, Doma de Ouro). Sem p_prova, devolve o top de cada uma das 3 provas.';

-- Mesmo padrao de docs/migrations/2026-08-20-revoke-rpcs-anon.sql: Postgres da
-- EXECUTE a PUBLIC por padrao em funcao nova -- fechar pra anon explicitamente.
revoke execute on function public.abccc_resumo_animal(text) from public, anon;
revoke execute on function public.abccc_ranking_linhagens(text, int) from public, anon;

grant execute on function public.abccc_resumo_animal(text) to authenticated;
grant execute on function public.abccc_ranking_linhagens(text, int) to authenticated;
