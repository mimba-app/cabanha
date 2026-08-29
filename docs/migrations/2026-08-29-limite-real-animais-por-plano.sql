-- Lacuna achada revisando os limites de plano pro lançamento (2026-08-29):
-- planos.max_animais e max_usuarios eram só texto de marketing na landing/checkout --
-- nenhum trigger ou RPC checava isso antes de cadastrar. Um cliente do plano Potro
-- ("até 15 animais") podia cadastrar quantos quisesse, sem nenhum bloqueio técnico.
--
-- Esta migration cobre max_animais (trigger no banco, dispara pra qualquer caminho de
-- insert: form normal, onboarding, importação em lote). max_usuarios é tratado
-- separadamente na Edge Function convidar-usuario (não faz sentido como trigger de
-- banco, porque o convite cria linha em auth.users + tenant_memberships antes de
-- qualquer linha em schema de tenant).
--
-- Conta como "animal do plano" a mesma definição já usada em cab_resumo_geral pro
-- card "Na cabanha" do Dashboard: situacao in ('NA CABANHA','EMPRESTIMO') -- animal
-- vendido/morto/transferido não ocupa vaga do plano.

-- SECURITY DEFINER (revisão pós-revisor-isolamento, 2026-08-29): tenants/planos têm RLS
-- "service_role only" -- authenticated não enxerga nenhuma linha lá. Sem DEFINER, a
-- consulta abaixo sempre voltaria vazia sob RLS normal (fail-open: v_max ficaria null e
-- NUNCA bloquearia nada, silenciosamente). TG_TABLE_SCHEMA é preenchido pelo próprio
-- trigger manager do Postgres a partir da relação-base real (não é parâmetro de função,
-- não é resolvido por search_path, não pode ser adulterado por quem chama) -- confirmado
-- na revisão de isolamento como seguro pra esse uso, então elevar aqui é o mesmo padrão
-- já usado em toda função cross-schema deste projeto (tem_acesso_tenant, cab_resumo_geral
-- etc.), não uma exceção.
create or replace function public.fn_checar_limite_animais()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_max int4;
  v_count int4;
begin
  -- Só conta contra o limite quem está entrando (ou voltando) como ativo na cabanha.
  -- FIX URGENTE (2026-08-29, achado testando ao vivo): situacao é enum
  -- (situacao_animal), não text -- coalesce(new.situacao, '') sem cast falhava a
  -- comparação de tipo em TODO insert/update de animais do sistema inteiro (erro
  -- 22P02), independente do valor real. Cast explícito pra text resolve.
  if coalesce(new.situacao::text, '') not in ('NA CABANHA', 'EMPRESTIMO') then
    return new;
  end if;

  select p.max_animais into v_max
  from public.tenants t
  join public.planos p on p.id = t.plano_id
  where t.schema_name = TG_TABLE_SCHEMA;

  -- -1/null = ilimitado, ou tenant/plano não resolvido (não bloqueia por segurança
  -- num caso que não deveria acontecer em produção, só logaria confusão).
  if v_max is null or v_max < 0 then
    return new;
  end if;

  execute format(
    'select count(*) from %I.animais where situacao in (''NA CABANHA'',''EMPRESTIMO'')',
    TG_TABLE_SCHEMA
  ) into v_count;

  if v_count >= v_max then
    raise exception 'limite_plano_animais: seu plano permite no máximo % animais na cabanha (você já tem %). Faça upgrade de plano pra cadastrar mais.', v_max, v_count
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

-- Template (public) -- toda cabanha provisionada DAQUI PRA FRENTE já nasce com o trigger.
drop trigger if exists trg_limite_animais on public.animais;
create trigger trg_limite_animais
  before insert or update of situacao on public.animais
  for each row execute function public.fn_checar_limite_animais();

-- Propaga pro cab_* já provisionados (skill nova-migration-tenant) -- sem isso, só
-- cabanhas novas ganhariam a trava, e as já existentes ficariam sem.
do $$
declare
  r record;
begin
  for r in select schema_name from public.tenants where provisionado = true loop
    execute format('drop trigger if exists trg_limite_animais on %I.animais', r.schema_name);
    execute format(
      'create trigger trg_limite_animais before insert or update of situacao on %I.animais for each row execute function public.fn_checar_limite_animais()',
      r.schema_name
    );
  end loop;
end $$;
