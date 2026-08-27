-- Novo modelo de precos da landing redesenhada (Luciano) -- 3 niveis, 2 com
-- opcao "sem IA" / "com Agente Mimba" (Potro, Arreio) e 1 so com IA incluida
-- (Manada, ex-Tropilha).
--
-- IMPORTANTE -- por que isso NAO reprecifica clientes ja pagantes: a Edge
-- Function criar-checkout le planos.preco_mensal só no momento em que uma
-- NOVA assinatura e criada no Asaas (`value: Number(plano.preco_mensal)`) --
-- o valor fica fixado no objeto de assinatura do lado do Asaas dali pra
-- frente, sem reler nosso banco nos ciclos seguintes. Ha 3 cabanhas reais
-- hoje (Mae de Deus e Tupan em Arreio, Santa Enoema em Tropilha) cujas
-- assinaturas no Asaas continuam cobrando o valor antigo normalmente --
-- so o NOME/PRECO que aparece no nosso proprio sistema (admin, etc.) muda.
-- Se quiser migrar essas 3 pro valor novo de verdade, isso e uma acao
-- separada e deliberada na propria assinatura do Asaas (nao coberta aqui).

begin;

-- Potro: vira a opcao "sem IA" do novo modelo.
update public.planos
set preco_mensal = 59.90,
    features = features || jsonb_build_object('agente_ia', false, 'cota_ia_mensal', 0)
where nome = 'Potro';

-- Arreio: vira a opcao "sem IA" do novo modelo.
update public.planos
set preco_mensal = 119.90,
    features = features || jsonb_build_object('agente_ia', false, 'cota_ia_mensal', 0)
where nome = 'Arreio';

-- Tropilha renomeia pra Manada -- ja inclui Agente Mimba, sem variante "sem IA".
-- Cota: copy do Luciano fala em "50 mensagens por dia" -- convertido pra
-- equivalente mensal (50*30) porque o mecanismo de cota hoje
-- (agente_ia_registrar_uso) e mensal, nao diario. Fica registrado como
-- decisao a revisar: mudar o enforcement pra diario, ou ajustar a copy
-- de marketing pra "por mes", depois do lancamento -- nao bloqueia hoje
-- porque o agente ainda depende de credito da Anthropic pra funcionar.
update public.planos
set nome = 'Manada', slug = 'manada', preco_mensal = 397.90,
    features = features || jsonb_build_object('agente_ia', true, 'cota_ia_mensal', 1500)
where nome = 'Tropilha';

-- Novo: Potro + Agente Mimba (reaproveita as features do Potro atualizado).
insert into public.planos (nome, slug, preco_mensal, max_animais, ativo, features)
select 'Potro + Agente Mimba', 'potro-ia', 79.90, max_animais, true,
       features || jsonb_build_object('agente_ia', true, 'cota_ia_mensal', 600)
from public.planos where nome = 'Potro';

-- Novo: Arreio + Agente Mimba (reaproveita as features do Arreio atualizado).
insert into public.planos (nome, slug, preco_mensal, max_animais, ativo, features)
select 'Arreio + Agente Mimba', 'arreio-ia', 159.90, max_animais, true,
       features || jsonb_build_object('agente_ia', true, 'cota_ia_mensal', 900)
from public.planos where nome = 'Arreio';

commit;

-- Verificacao pos-apply:
--   select nome, slug, preco_mensal, max_animais, features->>'agente_ia' as agente_ia,
--          features->>'cota_ia_mensal' as cota_ia_mensal
--   from public.planos order by preco_mensal;
