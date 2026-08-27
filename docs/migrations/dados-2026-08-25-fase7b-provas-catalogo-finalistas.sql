-- PROJETO ANALÍTICO (mimba-analytics) — Fase 7b: provas novas do catálogo de finalistas.
--
-- ⚠️ NÃO RODA EM PRODUÇÃO. Prefixo `dados-` = projeto analítico (ADR 0005).
--
-- O catálogo de finalistas 2020-2026 enviado pelo Luciano
-- (catalogos_animais_completo_3.csv, 3838 linhas) usa 2 nomes de prova que não
-- batem exatamente com `provas_tier` (join usado por `carregar_catalogo_genealogia`
-- e `analisar_cruzamento` é por igualdade de string, sensível a acento):
--
-- 1. "Marcha Anual de Resistência" (com acento) no CSV vs "Marcha Anual de
--    Resistencia" (sem acento) já cadastrado — mesma prova, variante gráfica.
--    Solução: cadastrar as duas grafias apontando pro mesmo tier/tipo.
-- 2. "Doma de Ouro" no CSV não tem correspondente exato — só existem "Final da
--    Doma de Ouro" e "Um Ano de Doma" (ambas tier 2/doma). Assumindo que
--    "Doma de Ouro" no catálogo de finalistas se refere à FINAL (não à edição
--    "Um Ano"), cadastrado como prova própria, mesmo tier/tipo da final.
--    ⚠️ Assunção registrada aqui — se o Luciano confirmar que é outra coisa,
--    ajustar/mesclar depois (linhas já carregadas com essa prova ficam fáceis de
--    achar: `where prova = 'Doma de Ouro' and fonte = 'catalogo_pdf'`).
insert into public.provas_tier (prova, tier, tipo) values
  ('Marcha Anual de Resistência', 2, 'resistencia'),
  ('Doma de Ouro',                2, 'doma')
on conflict (prova) do update set tier = excluded.tier, tipo = excluded.tipo;
