-- Fase 7c: grants faltantes para o scraper de 5 geração (Mimba Lab)
--
-- O scraper (dados/genealogia/scraper-5geracoes.mjs) fala com a REST API do
-- Lab usando a LAB_SERVICE_ROLE_KEY (papel `service_role`). Descobrimos ao
-- rodar em lote que `service_role` não tinha nenhum GRANT de SELECT/INSERT/
-- UPDATE em animais_genealogia (só tinha REFERENCES/TRIGGER/TRUNCATE, que não
-- servem pra nada aqui) — provável resquício de como essas tabelas analíticas
-- foram criadas fora do fluxo normal de provisionamento (que clona o `public`
-- com LIKE INCLUDING ALL + grants). Erro visto: "permission denied for table
-- animais_genealogia" (42501).
--
-- Este projeto é o Mimba Lab (analítico), isolado de produção — não mexe em
-- nenhum schema cab_* nem no template de provisionamento.

grant select, insert, update on public.animais_genealogia to service_role;
grant select, insert, update on public.resultados_competitivos to service_role;
grant select on public.provas_tier to service_role;
grant execute on function public.genealogia_atualizar_posicoes() to service_role;
