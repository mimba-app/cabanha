-- BUG CRÍTICO achado testando o onboarding ao vivo, de ponta a ponta (2026-08-29):
-- a migration 2026-08-29-onboarding-abccc-e-perfil-publico.sql usou `create or
-- replace function` pra adicionar o parâmetro p_abccc_codigo, mas como isso muda a
-- assinatura, o Postgres CRIOU UMA SEGUNDA função sobreposta em vez de substituir a
-- original -- o mesmo erro de padrão já cometido (e corrigido corretamente via
-- DROP+CREATE) em minhas_cabanhas() horas antes, só que não repeti o mesmo cuidado
-- aqui.
--
-- Efeito real: com duas assinaturas compatíveis coexistindo, o PostgREST não
-- consegue decidir qual chamar sempre que a chamada não inclui p_abccc_codigo
-- (erro PGRST203, HTTP 300 Multiple Choices). _onbSalvarCabanha() (etapa 1) sempre
-- manda p_abccc_codigo, então não quebrava -- mas _onbFinalizar() (fecha o
-- onboarding, grava foco_inicial + onboarding_completo=true) NUNCA manda
-- p_abccc_codigo, e falhava silenciosamente: a função `_rpc()` no frontend não
-- verifica o retorno antes de continuar, então a pessoa via a tela de "Ativação
-- concluída" e caía no app normalmente, sem nenhum erro visível -- só que
-- tenants.onboarding_completo nunca virava true. Resultado: TODA cabanha nova
-- provisionada depois dessa migration veria o onboarding de novo a cada login,
-- pra sempre, sem nunca conseguir "terminar" de verdade.
--
-- Checado: nenhum cliente real caiu nessa janela (só a cabanha de teste
-- "Cabanha Pedro Teste Onboarding", criada e corrigida no mesmo dia).

drop function if exists public.atualizar_tenant_onboarding(uuid,text,text,text,text,text,boolean,text);

revoke all on function public.atualizar_tenant_onboarding(uuid,text,text,text,text,text,boolean,text,text) from public, anon;
grant execute on function public.atualizar_tenant_onboarding(uuid,text,text,text,text,text,boolean,text,text) to authenticated;
