-- Achado do Supabase Security Advisor (get_advisors type=security), 2026-08-20 —
-- 9 funções SECURITY DEFINER em `public` chamáveis por `anon` via PostgREST
-- (/rest/v1/rpc/<nome>) porque o Postgres concede EXECUTE a PUBLIC por padrão em
-- toda função nova e nenhuma delas nunca teve REVOKE. Revisão de isolamento:
-- ver relatório do revisor-isolamento anexado ao PR/handoff desta data.
--
-- Substitui em escopo o rascunho anterior, mais estreito,
-- 2026-08-20-revoke-rpcs-perigosas.sql (3 funções). Esta migration cobre as 9
-- do advisor + `encerrar_ciclo_reproducao` (achada antes do incidente, ainda
-- não aplicada) + `rate_limit_log` (RLS desligada, achado #10 do advisor).
-- Não duplica a anterior: se ela já tiver sido aplicada, os REVOKEs abaixo são
-- idempotentes (revogar um privilégio que já não existe não é erro).
--
-- NÃO altera nenhuma policy, nenhum dado, nenhuma assinatura de função — só
-- ACL de EXECUTE (proacl) e, no item 10, liga RLS sem criar policy nenhuma
-- (default-deny; service_role, usado pelas Edge Functions, sempre ignora RLS).
--
-- Confirmado nos call sites do index.html (branches main/staging/recuperacao)
-- que o app SEMPRE chama estas RPCs autenticado — `_rpc()` manda
-- `Authorization: Bearer ${AUTH_TOKEN||SUPABASE_KEY}`, e os 3 pontos de
-- chamada (atualizar_tenant, revogar_acesso_usuario, carregar_dados_cabanha)
-- só são alcançáveis depois do login (bootstrap, tela de Conta/Usuários).
-- `vincular_usuario_cabanha` é chamada pela Edge Function `convidar-usuario`
-- (verify_jwt=true, só admin já autenticado — ver HANDOFF.md linhas 72-95,
-- 479-483); `provisionar_schema_cabanha` só pela Edge Function
-- `provisionar-cabanha` (exige Bearer service_role). `fn_registrar_login` não
-- tem nenhum call site no frontend (audit de login é feito por INSERT direto
-- na tabela `audit_log`, função helper `_auditLog`, ver index.html) — é
-- superfície morta, sem motivo pra estar exposta a ninguém fora do que a
-- criou. `fn_audit_trigger()` é função de trigger (`returns trigger`); o
-- Postgres já recusa chamá-la fora de contexto de trigger, e nenhum ROLE
-- precisa de EXECUTE nela pra o trigger disparar (triggers rodam
-- independente de grant na função). `tem_acesso_tenant` é usada dentro de
-- toda policy RLS de `cab_*` — precisa continuar executável por
-- `authenticated` (é quem roda as queries que a RLS avalia).
--
-- IMPORTANTE — verificação ANTES de aplicar (rodar e revisar o resultado):
--   select p.proname,
--          pg_get_function_identity_arguments(p.oid) as args,
--          p.prosecdef, p.proacl, pg_get_userbyid(p.proowner) as owner
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in (
--       'atualizar_tenant','carregar_dados_cabanha','fn_audit_trigger',
--       'fn_registrar_login','provisionar_schema_cabanha',
--       'revogar_acesso_usuario','tem_acesso_tenant','vincular_usuario_cabanha',
--       'encerrar_ciclo_reproducao')
--   order by 1, 2;
-- proacl nulo = EXECUTE ainda concedido a PUBLIC (o que inclui anon e
-- authenticated implicitamente). Confirmar que aparece isso ANTES de aplicar.

begin;

-- 1. atualizar_tenant — 2 overloads. Muda nome_exibicao/logo_url/cor_primaria
--    do tenant. Só a versão de 4 args é chamada pelo app (tela Conta),
--    sempre com JWT do usuário. A versão de 3 args (sem p_cor_primaria) não
--    tem call site nenhum encontrado no repo — provável resquício, mantido
--    aqui por segurança em vez de dropada (fora do escopo desta migration).
--    Sem o REVOKE, qualquer um com a anon key desfigura nome/logo/cor de
--    QUALQUER cabanha sabendo (ou adivinhando/enumerando) o tenant_id.
revoke all on function public.atualizar_tenant(uuid, text, text) from public, anon;
revoke all on function public.atualizar_tenant(uuid, text, text, text) from public, anon;
grant execute on function public.atualizar_tenant(uuid, text, text, text) to authenticated;

-- 2. carregar_dados_cabanha — bootstrap de login. Já tem guard interno
--    (`if not tem_acesso_tenant(...) then raise exception`), então não vaza
--    dado mesmo hoje — mas anon não tem motivo pra alcançar. Defesa em
--    profundidade (e reduz a chance de uma trigger/exception verbosa vazar
--    nome de schema/estrutura interna em mensagem de erro pra quem não devia
--    nem estar tentando).
revoke all on function public.carregar_dados_cabanha(uuid) from public, anon;
grant execute on function public.carregar_dados_cabanha(uuid) to authenticated;

-- 3. fn_audit_trigger — função de trigger (`returns trigger`), não precisa
--    de EXECUTE pra ninguém fora de quem a criou/mantém: o Postgres já
--    recusa `select fn_audit_trigger()` direto ("trigger functions can only
--    be called as triggers") e a invocação automática pelo executor de
--    triggers não depende de GRANT EXECUTE na função. Só reduz superfície
--    de ataque/enumeração via PostgREST RPC.
revoke all on function public.fn_audit_trigger() from public, anon, authenticated;

-- 4. fn_registrar_login — grava entrada de login/logout com parâmetros
--    livres (p_usuario_id, p_usuario_nome, p_acao, p_ip), sem call site no
--    frontend nem em nenhuma Edge Function encontrada no repo. Exposta a
--    anon: dá pra forjar entradas falsas de login/logout no log de qualquer
--    usuário/tenant (poluição de audit trail — pode mascarar acesso
--    indevido de verdade no meio de ruído forjado). Revoga de todo mundo:
--    se algo legítimo depender dela, precisa ser identificado e receber
--    grant explícito depois (não achado nenhum call site até aqui).
revoke all on function public.fn_registrar_login(uuid, text, text, text) from public, anon, authenticated;

-- 5. provisionar_schema_cabanha — já achada antes do incidente: faz
--    `drop table if exists %I.%I cascade` em loop nas ~26 tabelas do schema,
--    validando só que existe uma linha em public.tenants com aquele
--    schema_name. Com a anon key, dava pra apagar uma cabanha inteira de
--    fora chamando com p_schema='cab_<qualquer>'. Só a Edge Function
--    `provisionar-cabanha` (Bearer service_role) deve chamar isto.
revoke all on function public.provisionar_schema_cabanha(text) from public, anon, authenticated;

-- 6. revogar_acesso_usuario — marca tenant_memberships.ativo=false pro par
--    (tenant_id, auth_user_id) informado. Chamada pelo app só autenticado
--    (suspender/excluir usuário, tela de Usuários). Exposta a anon: risco de
--    DoS/lockout — um atacante que soubesse (ou enumerasse) um tenant_id e
--    um auth_user_id de admin de uma cabanha cliente pagante poderia
--    revogar o próprio acesso dele sem login nenhum. PRECISA DE CONFIRMAÇÃO
--    HUMANA: não temos o corpo da função neste ambiente (não há acesso MCP
--    ao banco vivo nesta revisão) pra confirmar se ela já valida
--    internamente que quem chama é admin do MESMO tenant (o texto do erro
--    no frontend, "Confira se você é administrador desta cabanha", sugere
--    que sim) — mas o REVOKE é a correção certa de qualquer forma: o app
--    nunca precisa que `anon` chame isto, então o custo de revogar é zero.
revoke all on function public.revogar_acesso_usuario(uuid, uuid) from public, anon;
grant execute on function public.revogar_acesso_usuario(uuid, uuid) to authenticated;

-- 7. tem_acesso_tenant — helper booleano usado dentro de toda policy RLS de
--    `cab_*` (`(select public.tem_acesso_tenant(<tenant_id>))`) — PRECISA
--    continuar executável por `authenticated` (é o role que roda as queries
--    avaliadas pela RLS). Chamada direta por anon hoje é inofensiva (sem
--    JWT, auth.uid() é null, retorna false, sem efeito colateral, sem vazar
--    linha nenhuma) — mas não há motivo pra deixar `anon` chamá-la como RPC.
revoke all on function public.tem_acesso_tenant(uuid) from public, anon;
grant execute on function public.tem_acesso_tenant(uuid) to authenticated;

-- 8. vincular_usuario_cabanha — o mais grave em potencial: liga um
--    auth_user_id a um schema/tenant com um perfil (upsert idempotente por
--    login, ver HANDOFF.md). Se exposta a `anon` sem nenhuma checagem de
--    quem está chamando, é o pior cenário de isolamento: um atacante com
--    QUALQUER conta Supabase Auth própria (ex.: se cadastra sozinho em
--    outro fluxo, ou já é usuário de uma cabanha) chama esta RPC direto com
--    a anon key passando p_schema='cab_<cabanha_alheia>', p_perfil='adm' e o
--    próprio auth_user_id — e ganha uma tenant_membership ativa nessa
--    cabanha, o que destrava acesso de verdade via RLS (tem_acesso_tenant
--    passa a retornar true pra ele). Isso é account-takeover / vazamento
--    cross-tenant, exatamente a regra de ouro do projeto. Só chamada hoje
--    pela Edge Function `convidar-usuario` (verify_jwt=true, exige já ser
--    admin autenticado de uma cabanha pra convidar). PRECISA DE CONFIRMAÇÃO
--    HUMANA do corpo da função (não verificável nesta revisão sem acesso ao
--    banco vivo) — mas o REVOKE é seguro e urgente independente do que o
--    corpo faz: `anon` nunca deveria alcançar isto.
revoke all on function public.vincular_usuario_cabanha(text, text, text, text, uuid) from public, anon;
grant execute on function public.vincular_usuario_cabanha(text, text, text, text, uuid) to authenticated;

-- 9. encerrar_ciclo_reproducao — achada antes do incidente (rascunho
--    2026-08-20-revoke-rpcs-perigosas.sql, nunca aplicada porque o banco
--    caiu no meio da sessão). Faz UPDATE em massa varrendo TODOS os tenants
--    — é job de cron (pg_cron roda como superuser, não afetado pelo
--    REVOKE), não ação de usuário via app.
revoke all on function public.encerrar_ciclo_reproducao() from public, anon, authenticated;

-- 10. rate_limit_log — achado à parte do advisor (RLS desligada, nível
--     ERROR). Sem call site nenhum no frontend (não é lida/escrita via
--     PostgREST pelo app) — presumível uso só por Edge Functions com
--     service_role, que ignora RLS sempre. Liga RLS sem criar NENHUMA
--     policy: vira default-deny pra anon/authenticated via PostgREST,
--     zero efeito em service_role/Edge Functions.
alter table if exists public.rate_limit_log enable row level security;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rodar depois de aplicar e conferir:
--   - proacl NÃO pode mais ser nulo (nulo = ainda aberto a PUBLIC) nas 9 +
--     encerrar_ciclo_reproducao;
--   - proacl não pode conter `anon=X/` em nenhuma delas;
--   - authenticated deve aparecer com X (execute) em: atualizar_tenant/4,
--     carregar_dados_cabanha, revogar_acesso_usuario, tem_acesso_tenant,
--     vincular_usuario_cabanha — e NÃO deve aparecer em: fn_audit_trigger,
--     fn_registrar_login, provisionar_schema_cabanha, encerrar_ciclo_reproducao,
--     nem em atualizar_tenant/3.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.proacl,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_pode_chamar,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_pode_chamar,
       has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_pode_chamar
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'atualizar_tenant','carregar_dados_cabanha','fn_audit_trigger',
    'fn_registrar_login','provisionar_schema_cabanha',
    'revogar_acesso_usuario','tem_acesso_tenant','vincular_usuario_cabanha',
    'encerrar_ciclo_reproducao')
order by 1, 2;

-- Checar também que service_role_pode_chamar = true em TODAS (Edge Functions
-- dependem disso). Se der false em alguma que a Edge Function usa
-- (provisionar_schema_cabanha, vincular_usuario_cabanha, encerrar_ciclo_reproducao),
-- rodar (fora desta migration, só se necessário):
--   grant execute on function public.<nome>(<args>) to service_role;

select relrowsecurity, relforcerowsecurity
from pg_class where oid = 'public.rate_limit_log'::regclass;

-- Teste funcional obrigatório após aplicar (o app não pode quebrar):
--   - login de um usuário normal → bootstrap (carregar_dados_cabanha) funciona;
--   - Conta → salvar nome/logo/cor da cabanha (atualizar_tenant) funciona;
--   - Conta → Usuários → suspender/excluir um usuário (revogar_acesso_usuario) funciona;
--   - Conta → Usuários → convidar um usuário novo (convidar-usuario → vincular_usuario_cabanha) funciona;
--   - provisionar uma cabanha de teste pela Edge Function (service_role) continua funcionando;
--   - com só a anon key (sem login), curl direto em cada uma das 9 RPCs deve
--     devolver 401/403 (ou PGRST/permission denied), nunca 200.
