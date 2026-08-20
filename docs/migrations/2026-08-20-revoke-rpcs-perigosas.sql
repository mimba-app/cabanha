-- Incidente 2026-08-19/20 — fecha o EXECUTE público de RPCs SECURITY DEFINER perigosas.
--
-- Achado do revisor-isolamento durante o incidente. O Postgres concede EXECUTE a PUBLIC
-- por padrão em toda função nova, e o PostgREST expõe tudo que está no schema `public`.
-- As migrations da Área de Dados fazem o REVOKE certo; estas três nunca fizeram.
--
-- provisionar_schema_cabanha é o caso grave: ela faz `drop table if exists %I.%I cascade`
-- em loop sobre as 28 tabelas do schema, e só valida que existe uma linha em public.tenants
-- com aquele schema_name. Ou seja, qualquer um com a anon key (que é pública, está no
-- index.html) poderia chamá-la com p_schema = 'cab_mae_de_deus' e apagar a cabanha inteira.
-- O CLAUDE.md diz que a porta de entrada é a Edge Function com Bearer service_role — a RPC
-- não deveria estar acessível direto pelo PostgREST.
--
-- NÃO altera nenhuma policy, nenhum dado e nenhuma assinatura de função: só tira o EXECUTE
-- de quem nunca deveria ter tido. Idempotente.
--
-- ANTES de aplicar, confirmar o estado atual (proacl nulo = EXECUTE para PUBLIC):
--   select p.proname, p.prosecdef, p.proacl, pg_get_userbyid(p.proowner) as owner
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in ('provisionar_schema_cabanha','encerrar_ciclo_reproducao',
--                       'carregar_dados_cabanha','tem_acesso_tenant','minhas_cabanhas',
--                       'sou_staff_mimba');

-- 1. Provisionamento: só service_role (Edge Function) e postgres. Destrutivo se exposto.
revoke all on function public.provisionar_schema_cabanha(text) from public, anon, authenticated;

-- 2. Encerramento de ciclo: roda UPDATE em massa em TODOS os tenants (loop sobre
--    public.tenants). É job de cron, não ação de usuário. pg_cron roda como superuser.
revoke all on function public.encerrar_ciclo_reproducao() from public, anon, authenticated;

-- 3. Bootstrap da cabanha: já tem guard interno de tem_acesso_tenant(), então não vaza
--    dado — mas anon não tem motivo nenhum pra alcançar. Defesa em profundidade.
revoke all on function public.carregar_dados_cabanha(uuid) from public, anon;
grant execute on function public.carregar_dados_cabanha(uuid) to authenticated;

-- DEPOIS de aplicar, reconferir com a mesma query do topo: proacl não pode mais ser nulo,
-- e não pode aparecer nem `=X/` (PUBLIC) nem `anon=X/` para as duas primeiras.
--
-- Teste funcional obrigatório após aplicar (o app não pode quebrar):
--   - login de um usuário normal → o bootstrap (carregar_dados_cabanha) tem que funcionar;
--   - o cron de encerrar_ciclo_reproducao continua rodando (roda como superuser, não é afetado);
--   - provisionar uma cabanha de teste pela Edge Function (service_role) continua funcionando.
