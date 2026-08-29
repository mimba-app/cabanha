-- Inconsistência achada auditando a jornada de compra pro lançamento (2026-08-28):
-- a landing (mimba-landing/assinar/index.html) anuncia "Arreio: até 50 animais",
-- mas o plano no banco tinha max_animais=40. Não é limite tecnicamente aplicado
-- (nenhum trigger bloqueia cadastro acima disso -- só é usado como informação em
-- listar_planos_ativos/verificar_troca_plano), mas é uma promessa ao cliente que
-- não batia com a configuração. Pedro confirmou: o valor certo é 50 (ajustar o
-- banco, não a landing).

update public.planos set max_animais = 50 where nome in ('Arreio', 'Arreio + Agente Mimba');
