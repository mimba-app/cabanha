-- Corrige o cron encerrar_ciclo_reproducao() (bug real, achado investigando garanhões
-- "fantasma" na aba Acasalamentos da Cabanha Mãe de Deus) + limpa o dado já sujo.
--
-- Sintoma reportado: em ciclo 26/27, a tela de match de acasalamento (Fase 8, ponto 3b)
-- listava LEOPARDO DA GAP SÃO PEDRO-TE, LAS GURIZAS FOGONERO e ÍNDIO DO BOEIRO como fonte
-- "Próprio" com 120 coberturas disponíveis — mas nenhum dos três é um animal cadastrado na
-- Cabanha Mãe de Deus (são padrillos externos usados via IA antes do Reprodutivo v3).
--
-- Causa raiz: o cron `encerramento-ciclo-reproducao` (pg_cron, "0 3 1 8 *", roda 1x/ano em
-- 01/08 chamando public.encerrar_ciclo_reproducao()) tinha um passo que clonava QUALQUER
-- fontes_cobertura tipo='proprio' do ciclo anterior pro ciclo novo, só batendo nome/SBB —
-- sem checar se o garanhão ainda é um animal cadastrado/ativo. Isso é redundante desde a
-- Fase 2 do Reprodutivo v4 (2026-08-13): renderPlanejadorReprodutivo() já cria a fonte
-- "Próprio" do ciclo automaticamente no client, sempre validada contra o cadastro real de
-- Animais (macho, na cabanha, não castrado, ≥20 meses). O passo do cron nunca foi atualizado
-- depois da Fase 2 — ficou clonando fantasmas pra sempre, todo santo ano.
--
-- Verificado (2026-08-19) que só a Cabanha Mãe de Deus tinha fontes 'proprio' órfãs (sem
-- animal cadastrado correspondente) — os outros 6 tenants provisionados estavam limpos.

-- 1) Limpa as 7 linhas fantasma na Mãe de Deus (3 do ciclo 26/27 recém-clonadas pelo cron +
--    4 duplicatas 'vencida' acumuladas de ciclos anteriores). Verificado antes que nenhum
--    acasalamento/negociação de cobertura referenciava essas linhas — DELETE direto, seguro.
--    As fontes tipo='cobertura' desses mesmos 3 garanhões (representando a cobertura histórica
--    real, criadas ao migrar as 4 gestações legadas, ver 2026-08-19-remove-legado-coberturas.sql)
--    NÃO são afetadas.
delete from cab_mae_de_deus.fontes_cobertura
where tipo = 'proprio' and garanhao_sbb in ('B231887','B645697','B546223');

-- 2) Remove o passo 3 (clonagem de "próprio" sem validação) do cron. Os outros 3 passos
--    (vencer fontes 'proprio' com saldo>0, cancelar acasalamentos 'em_curso' no fim do ciclo,
--    vencer cota/direito_uso com vigência expirada) continuam intactos.
create or replace function public.encerrar_ciclo_reproducao()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  r record;
  v_ciclo_novo text := public._calc_ciclo_texto(current_date);
  v_vencidas int; v_cancelados int; v_cota_vencidas int;
  v_total_vencidas int := 0; v_total_cancelados int := 0; v_total_cota int := 0;
begin
  for r in select id as tenant_id, schema_name, nome_exibicao
           from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    -- 1. Fontes de garanhão próprio com saldo > 0: vencem
    execute format($f$
      update %I.fontes_cobertura f set status = 'vencida', atualizado_em = now()
      where f.tipo = 'proprio' and f.status = 'ativa'
        and (
          f.quantidade_adquirida
          - coalesce((select count(*) from %I.acasalamentos a where a.fonte_cobertura_id = f.id and a.status = 'confirmado'), 0)
          - coalesce((select sum(n.quantidade) from %I.coberturas_negociadas n where n.fonte_cobertura_id = f.id and n.status in ('aceito','quitado')), 0)
        ) > 0
    $f$, r.schema_name, r.schema_name, r.schema_name);
    get diagnostics v_vencidas = row_count;

    -- 2. Acasalamentos em_curso sem confirmação: cancelados por encerramento de ciclo
    execute format($f$
      update %I.acasalamentos set status = 'cancelado', motivo_cancelamento = 'Encerramento de ciclo', atualizado_em = now()
      where status = 'em_curso'
    $f$, r.schema_name);
    get diagnostics v_cancelados = row_count;

    -- 3. (Removido) Recriação automática de fontes "próprio" — Fase 2 do Reprodutivo v4 já
    -- faz isso no client, validado contra o cadastro real de Animais. Manter aqui duplicava
    -- a lógica e não validava se o garanhão ainda é um animal cadastrado/ativo.

    -- 4. Cota / direito de uso com vigência expirada: vencem
    execute format($f$
      update %I.fontes_cobertura set status = 'vencida', atualizado_em = now()
      where tipo in ('cota','direito_uso') and status = 'ativa'
        and vigencia_fim is not null and vigencia_fim < current_date
    $f$, r.schema_name);
    get diagnostics v_cota_vencidas = row_count;

    insert into public.webhook_log (evento, tenant_id, payload, processado)
    values ('encerramento_ciclo_reproducao', r.tenant_id,
      jsonb_build_object('ciclo_novo', v_ciclo_novo, 'fontes_vencidas', v_vencidas,
                          'acasalamentos_cancelados', v_cancelados,
                          'cota_direito_uso_vencidas', v_cota_vencidas),
      true);

    v_total_vencidas := v_total_vencidas + v_vencidas;
    v_total_cancelados := v_total_cancelados + v_cancelados;
    v_total_cota := v_total_cota + v_cota_vencidas;
  end loop;

  return jsonb_build_object(
    'ciclo_novo', v_ciclo_novo, 'tenants_processados',
    (select count(*) from public.tenants where provisionado = true),
    'total_fontes_vencidas', v_total_vencidas, 'total_acasalamentos_cancelados', v_total_cancelados,
    'total_cota_direito_uso_vencidas', v_total_cota
  );
end;
$function$;
