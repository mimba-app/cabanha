-- ============================================================================
-- Área de Dados — Fase 2: importador do painel público da ABCCC + análises
-- ============================================================================
-- O painel https://www.cavalocrioulo.org.br/eventos/painel_resultados é um relatório
-- Power BI "publish-to-web". A tabela é virtualizada (carrega de 500 em 500 no DOM),
-- então em vez de raspar a tela replicamos a própria query `querydata` do relatório.
-- A resposta vem no formato DSR compactado do Power BI (dicionários de valores +
-- bitmask R = repete valor da linha anterior, Ø = nulo) — decodificado aqui embaixo.
--
-- Por que no banco e não numa Edge Function: pg_net já está instalado, a chamada não
-- precisa de segredo nenhum (a resource key é a que está no link de embed público da
-- ABCCC) e assim o "Atualizar" da tela é só uma RPC. pg_net é assíncrono e enfileira
-- na transação do chamador, então dispatch e coleta PRECISAM ser transações separadas:
-- daí o par disparar() / coletar().
-- ============================================================================

-- ─── Fonte externa: config da query do painel ───────────────────────────────
insert into public.dados_fontes_externas (chave, nome, url, headers, mapa_colunas, payload)
values (
  'abccc_painel_resultados',
  'ABCCC — Painel de resultados de provas',
  'https://wabi-brazil-south-b-primary-api.analysis.windows.net/public/reports/querydata?synchronous=true',
  jsonb_build_object('Content-Type','application/json',
                     'X-PowerBI-ResourceKey','7ae570a3-b838-4624-8535-13eb3059a593'),
  jsonb_build_object(
    'evtencerramento.sbb','SBB', 'abccc ANIMA_PR.DAD_DESCRI','Animal',
    'evtencerramento.SexoNome','Sexo', 'abccc ANIMA.DAD_DESCRI','Pai',
    'abccc ANIMA (2).DAD_DESCRI','Mãe', 'abccc PESSOAS.DAD_DESCRI','Criador',
    'evtencerramento.ciclo','Ciclo', 'evtencerramento.cidade','Cidade',
    'evtprova.descricao','Prova', 'evtclassificacao_inscrito.Premio_Generico','Colocação'),
  '{}'::jsonb  -- preenchido logo abaixo (payload grande)
)
on conflict (chave) do update set
  url = excluded.url, headers = excluded.headers,
  mapa_colunas = excluded.mapa_colunas, atualizado_em = now();

-- ─── Decodificação + coleta ─────────────────────────────────────────────────
-- Dispara a requisição (transação própria — pg_net só envia após o commit).
create or replace function public.abccc_importar_disparar(
  p_janela integer default 10000, p_restart jsonb default null, p_ciclo text default null
) returns bigint language plpgsql security definer set search_path to 'public' as $$
declare
  v_fonte public.dados_fontes_externas%rowtype;
  v_payload jsonb; v_janela jsonb; v_where jsonb; v_req bigint;
  v_caminho text[] := array['queries','0','Query','Commands','0','SemanticQueryDataShapeCommand'];
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;
  -- p_ciclo entra num literal da linguagem de query do Power BI; sem isso uma aspa
  -- no valor quebra o literal e monta uma query externa malformada.
  if p_ciclo is not null and p_ciclo !~ '^[0-9]{4}$' then
    raise exception 'ciclo invalido: % (esperado um ano com 4 digitos)', p_ciclo;
  end if;
  select * into v_fonte from public.dados_fontes_externas where chave='abccc_painel_resultados' and ativo;
  if not found then raise exception 'fonte abccc_painel_resultados nao configurada'; end if;

  v_payload := v_fonte.payload;
  v_janela := jsonb_build_object('Count', least(greatest(coalesce(p_janela,10000),1), 30000));
  if p_restart is not null then v_janela := v_janela || jsonb_build_object('RestartTokens', p_restart); end if;
  v_payload := jsonb_set(v_payload,
    v_caminho || array['Binding','DataReduction','Primary','Window'], v_janela, true);

  if p_ciclo is not null then
    v_where := coalesce(v_payload #> (v_caminho || array['Query','Where']), '[]'::jsonb)
      || jsonb_build_array(jsonb_build_object('Condition', jsonb_build_object('In',
           jsonb_build_object(
             'Expressions', jsonb_build_array(jsonb_build_object('Column', jsonb_build_object(
                'Expression', jsonb_build_object('SourceRef', jsonb_build_object('Source','e')),
                'Property','ciclo'))),
             'Values', jsonb_build_array(jsonb_build_array(jsonb_build_object('Literal',
                jsonb_build_object('Value', '''' || p_ciclo || ''''))))))));
    v_payload := jsonb_set(v_payload, v_caminho || array['Query','Where'], v_where, true);
  end if;

  select net.http_post(url := v_fonte.url, headers := v_fonte.headers,
                       body := v_payload, timeout_milliseconds := 120000) into v_req;
  return v_req;
end; $$;

-- Coleta a resposta, decodifica o DSR e grava as linhas.
-- p_continuacao = true quando a página veio de um RestartToken: nesse caso a primeira
-- linha da resposta REPETE a última linha da página anterior e precisa ser descartada.
create or replace function public.abccc_importar_coletar(
  p_dataset uuid, p_request_id bigint, p_continuacao boolean default false
) returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_status int; v_content text; v_err text;
  v_fonte public.dados_fontes_externas%rowtype;
  v_data jsonb; v_desc jsonb; v_ds jsonb; v_dicts jsonb; v_dm jsonb; v_sch jsonb; v_rt jsonb;
  v_nomes text[] := '{}'; v_dictn text[] := '{}'; v_ncols int;
  v_item jsonb; v_C jsonb; v_R bigint; v_NU bigint; v_ci int; v_idx int;
  v_prev text[]; v_val text; v_raw jsonb; v_obj jsonb; v_dn text; v_gname text; v_ref text;
  v_base int; v_n int := 0; j int; v_primeira boolean := true;
begin
  if not public.sou_staff_mimba() then raise exception 'acesso negado'; end if;

  select status_code, content, error_msg into v_status, v_content, v_err
    from net._http_response where id = p_request_id;
  if not found then return jsonb_build_object('estado','aguardando'); end if;
  if v_err is not null then raise exception 'falha na requisicao ABCCC: %', v_err; end if;
  if v_status <> 200 then raise exception 'ABCCC respondeu HTTP %', v_status; end if;

  select * into v_fonte from public.dados_fontes_externas where chave='abccc_painel_resultados';

  v_data  := (v_content::jsonb) #> '{results,0,result,data}';
  v_desc  := v_data -> 'descriptor' -> 'Select';
  v_ds    := v_data #> '{dsr,DS,0}';
  v_dicts := coalesce(v_ds -> 'ValueDicts', '{}'::jsonb);
  v_dm    := v_ds #> '{PH,0,DM0}';
  v_rt    := v_ds -> 'RT';

  select elem -> 'S' into v_sch from jsonb_array_elements(v_dm) elem where elem ? 'S' limit 1;
  if v_sch is null then return jsonb_build_object('estado','vazio','inseridas',0,'fim',true); end if;
  v_ncols := jsonb_array_length(v_sch);

  for j in 0 .. v_ncols-1 loop
    v_gname := v_sch -> j ->> 'N';
    select d ->> 'Name' into v_ref from jsonb_array_elements(v_desc) d where d->>'Value' = v_gname limit 1;
    v_nomes := v_nomes || coalesce(v_fonte.mapa_colunas ->> v_ref, v_ref, v_gname);
    v_dictn := v_dictn || coalesce(v_sch -> j ->> 'DN', '');
  end loop;

  if not p_continuacao then
    delete from public.dados_registros where dataset_id = p_dataset;
    update public.dados_datasets set total_linhas = 0, colunas = to_jsonb(v_nomes) where id = p_dataset;
  end if;
  select coalesce(max(linha),0) into v_base from public.dados_registros where dataset_id = p_dataset;

  v_prev := array_fill(null::text, array[v_ncols]);

  for v_item in select value from jsonb_array_elements(v_dm) loop
    v_C  := v_item -> 'C';
    v_R  := coalesce((v_item ->> 'R')::bigint, 0);
    v_NU := coalesce((v_item ->> 'Ø')::bigint, 0);
    if v_C is null and v_R = 0 and v_NU = 0 then continue; end if;
    v_ci := 0; v_obj := '{}'::jsonb;
    for j in 0 .. v_ncols-1 loop
      if (v_R >> j) & 1 = 1 then
        v_val := v_prev[j+1];
      elsif (v_NU >> j) & 1 = 1 then
        v_val := null;
      else
        v_raw := v_C -> v_ci; v_ci := v_ci + 1;
        v_dn := v_dictn[j+1];
        if v_dn <> '' and jsonb_typeof(v_raw) = 'number' then
          v_idx := (v_raw #>> '{}')::int;
          v_val := (v_dicts -> v_dn) ->> v_idx;
        else
          v_val := v_raw #>> '{}';
        end if;
      end if;
      v_prev[j+1] := v_val;
      v_obj := v_obj || jsonb_build_object(v_nomes[j+1], v_val);
    end loop;
    -- descarta a linha repetida do restart token
    if p_continuacao and v_primeira then v_primeira := false; continue; end if;
    v_primeira := false;
    v_n := v_n + 1;
    insert into public.dados_registros (dataset_id, linha, dados) values (p_dataset, v_base + v_n, v_obj);
  end loop;

  update public.dados_datasets set total_linhas = total_linhas + v_n where id = p_dataset;

  return jsonb_build_object('estado','ok', 'inseridas', v_n, 'restart', v_rt, 'fim', (v_rt is null));
end; $$;

revoke all on function public.abccc_importar_disparar(integer,jsonb,text) from public, anon;
revoke all on function public.abccc_importar_coletar(uuid,bigint,boolean) from public, anon;
grant execute on function public.abccc_importar_disparar(integer,jsonb,text) to authenticated;
grant execute on function public.abccc_importar_coletar(uuid,bigint,boolean) to authenticated;
