-- Correcao de efeito colateral da migration 2026-08-27-novo-modelo-precos-planos.sql:
-- ao redefinir Potro/Arreio como as variantes "sem IA" (cota_ia_mensal=0), toda
-- cabanha que ja estava vinculada a esses planos perdeu acesso ao Agente Mimba
-- do dia pra noite -- mesmo cabanhas de teste que nunca deveriam ter esse
-- bloqueio. Descoberto quando o Luciano testou o agente na Cabanha Mae de Deus
-- e recebeu "limite de mensagens atingido (0)" sem nunca ter usado nenhuma.
--
-- Mae de Deus ja tinha sido corrigida manualmente antes desta migration (ver
-- HANDOFF). Esta aqui cobre as demais cabanhas de teste que ficaram na mesma
-- armadilha: 3 marcadas ambiente_teste=true + 2 cabanhas de teste do Pedro
-- (nome comeca com "Cabanha Pedro Teste", nunca teve assinatura Asaas real de
-- cliente pagante).
--
-- NAO mexe em nenhuma cabanha de cliente real pagante sem a variante "com IA"
-- (ex.: Cabanha Tupan, no plano Arreio puro) -- isso e o comportamento
-- correto do novo modelo de precos, nao um bug.

update public.tenants
set plano_id = (select id from public.planos where nome = 'Manada')
where nome_cabanha in (
  'Cabanha Santa Adelina', 'QA Isolamento', 'QA Segunda',
  'Cabanha Pedro Teste', 'Cabanha Pedro Teste Completo'
);

-- Verificacao pos-apply:
--   select t.nome_cabanha, p.nome, p.features->>'agente_ia', p.features->>'cota_ia_mensal'
--   from public.tenants t join public.planos p on p.id = t.plano_id
--   where t.nome_cabanha in ('Cabanha Santa Adelina','QA Isolamento','QA Segunda',
--     'Cabanha Pedro Teste','Cabanha Pedro Teste Completo');
