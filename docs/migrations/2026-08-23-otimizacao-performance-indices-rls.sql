-- Otimização de performance (achado ao investigar o banco ficar "unhealthy"
-- com literalmente 2 pessoas testando/desenvolvendo — nada a ver com volume
-- de clientes real ainda). Rodei os performance advisors do Supabase depois
-- de já ter corrigido o timeout pontual de carregar_dados_cabanha e achei um
-- padrão sistêmico: 251 achados de "unindexed_foreign_keys" (que colapsam em
-- ~53 colunas de FK sem índice, repetidas em `public` + nas 8 cabanhas já
-- provisionadas) e 7 achados de "auth_rls_initplan" (policy reavaliando
-- auth.role()/auth.uid() por LINHA em vez de uma vez por query). Nenhum dos
-- dois é a causa direta do timeout que já corrigimos, mas os dois pioram
-- CADA query que filtra/junta por essas colunas — exatamente o tipo de coisa
-- que passa despercebido com poucos dados e vira gargalo real assim que o
-- volume cresce um pouco. Corrigindo agora, antes de ter clientes de verdade
-- sentindo isso.
--
-- 1) Índices em colunas de FK sem cobertura — sem índice, toda vez que o
--    Postgres verifica um FK (em INSERT/UPDATE/DELETE da tabela referenciada,
--    ex.: apagar um animal força varredura de animais_id em cada tabela que
--    referencia animal_id) ou que uma query filtra/junta por essas colunas
--    (ex.: "todas as vacinações deste animal"), ele faz sequential scan na
--    tabela inteira em vez de usar índice. Aplicado no template `public` (pra
--    cabanhas novas já nascerem com os índices) e replicado em cada cabanha
--    já provisionada (nova-migration-tenant) — índices não são herdados
--    retroativamente pelo LIKE INCLUDING ALL do provisionamento, só no
--    momento em que uma cabanha nova é clonada a partir do template.
create index if not exists idx_acasalamentos_aprovado_por on public.acasalamentos(aprovado_por);
create index if not exists idx_acasalamentos_criado_por on public.acasalamentos(criado_por);
create index if not exists idx_acasalamentos_egua_id on public.acasalamentos(egua_id);
create index if not exists idx_acasalamentos_fonte_cobertura_id on public.acasalamentos(fonte_cobertura_id);
create index if not exists idx_acasalamentos_receptora_animal_id on public.acasalamentos(receptora_animal_id);
create index if not exists idx_acasalamentos_veterinario_id on public.acasalamentos(veterinario_id);
create index if not exists idx_animais_criado_por on public.animais(criado_por);
create index if not exists idx_animais_piquete_id on public.animais(piquete_id);
create index if not exists idx_animal_midia_criado_por on public.animal_midia(criado_por);
create index if not exists idx_coberturas_negociadas_comprador_tenant_id on public.coberturas_negociadas(comprador_tenant_id);
create index if not exists idx_coberturas_negociadas_criado_por on public.coberturas_negociadas(criado_por);
create index if not exists idx_coberturas_negociadas_fonte_cobertura_id on public.coberturas_negociadas(fonte_cobertura_id);
create index if not exists idx_coberturas_negociadas_lancamento_id on public.coberturas_negociadas(lancamento_id);
create index if not exists idx_estoque_movimentos_animal_id on public.estoque_movimentos(animal_id);
create index if not exists idx_estoque_movimentos_criado_por on public.estoque_movimentos(criado_por);
create index if not exists idx_eventos_criado_por on public.eventos(criado_por);
create index if not exists idx_eventos_animais_animal_id on public.eventos_animais(animal_id);
create index if not exists idx_eventos_animais_evento_id on public.eventos_animais(evento_id);
create index if not exists idx_exames_criado_por on public.exames(criado_por);
create index if not exists idx_fontes_cobertura_criado_por on public.fontes_cobertura(criado_por);
create index if not exists idx_fontes_cobertura_doadora_animal_id on public.fontes_cobertura(doadora_animal_id);
create index if not exists idx_gestacoes_criado_por on public.gestacoes(criado_por);
create index if not exists idx_gestacoes_egua_id on public.gestacoes(egua_id);
create index if not exists idx_gestacoes_protocolo_aplicado_id on public.gestacoes(protocolo_aplicado_id);
create index if not exists idx_lancamentos_animal_id on public.lancamentos(animal_id);
create index if not exists idx_lancamentos_criado_por on public.lancamentos(criado_por);
create index if not exists idx_medidas_animal_id on public.medidas(animal_id);
create index if not exists idx_medidas_criado_por on public.medidas(criado_por);
create index if not exists idx_nutricao_projeto_itens_projeto_id on public.nutricao_projeto_itens(projeto_id);
create index if not exists idx_nutricao_projetos_criado_por on public.nutricao_projetos(criado_por);
create index if not exists idx_nutricao_projetos_template_origem_id on public.nutricao_projetos(template_origem_id);
create index if not exists idx_nutricao_template_itens_template_id on public.nutricao_template_itens(template_id);
create index if not exists idx_nutricao_templates_criado_por on public.nutricao_templates(criado_por);
create index if not exists idx_pendencias_animal_id on public.pendencias(animal_id);
create index if not exists idx_pendencias_resolvida_por on public.pendencias(resolvida_por);
create index if not exists idx_protocolo_aplicado_criado_por on public.protocolo_aplicado(criado_por);
create index if not exists idx_protocolo_aplicado_protocolo_id on public.protocolo_aplicado(protocolo_id);
create index if not exists idx_protocolos_reproducao_criado_por on public.protocolos_reproducao(criado_por);
create index if not exists idx_reproducao_atividades_acasalamento_id on public.reproducao_atividades(acasalamento_id);
create index if not exists idx_reproducao_atividades_criado_por on public.reproducao_atividades(criado_por);
create index if not exists idx_reproducao_estagios_criado_por on public.reproducao_estagios(criado_por);
create index if not exists idx_tentativas_acasalamento_id on public.tentativas(acasalamento_id);
create index if not exists idx_tentativas_criado_por on public.tentativas(criado_por);
create index if not exists idx_tentativas_veterinario_id on public.tentativas(veterinario_id);
create index if not exists idx_tratamentos_animal_id on public.tratamentos(animal_id);
create index if not exists idx_tratamentos_criado_por on public.tratamentos(criado_por);
create index if not exists idx_vacinacoes_criado_por on public.vacinacoes(criado_por);
create index if not exists idx_vermifugacoes_animal_id on public.vermifugacoes(animal_id);
create index if not exists idx_vermifugacoes_criado_por on public.vermifugacoes(criado_por);

-- Tabelas de controle (só existem em `public`, não são clonadas por cabanha).
create index if not exists idx_signups_plano_id on public.signups(plano_id);
create index if not exists idx_signups_tenant_id on public.signups(tenant_id);
create index if not exists idx_tenant_memberships_tenant_id on public.tenant_memberships(tenant_id);
create index if not exists idx_tenants_plano_id on public.tenants(plano_id);
create index if not exists idx_webhook_log_tenant_id on public.webhook_log(tenant_id);

-- Replica os mesmos índices em cada cabanha já provisionada (padrão da skill
-- nova-migration-tenant) — cabanhas provisionadas a partir de agora já nascem
-- com eles via LIKE INCLUDING ALL, mas as já existentes precisam do backfill.
do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'acasalamentos') then
      execute format('create index if not exists idx_acasalamentos_aprovado_por on %I.acasalamentos(aprovado_por)', r.schema_name);
      execute format('create index if not exists idx_acasalamentos_criado_por on %I.acasalamentos(criado_por)', r.schema_name);
      execute format('create index if not exists idx_acasalamentos_egua_id on %I.acasalamentos(egua_id)', r.schema_name);
      execute format('create index if not exists idx_acasalamentos_fonte_cobertura_id on %I.acasalamentos(fonte_cobertura_id)', r.schema_name);
      execute format('create index if not exists idx_acasalamentos_receptora_animal_id on %I.acasalamentos(receptora_animal_id)', r.schema_name);
      execute format('create index if not exists idx_acasalamentos_veterinario_id on %I.acasalamentos(veterinario_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'animais') then
      execute format('create index if not exists idx_animais_criado_por on %I.animais(criado_por)', r.schema_name);
      execute format('create index if not exists idx_animais_piquete_id on %I.animais(piquete_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'animal_midia') then
      execute format('create index if not exists idx_animal_midia_criado_por on %I.animal_midia(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'coberturas_negociadas') then
      execute format('create index if not exists idx_coberturas_negociadas_comprador_tenant_id on %I.coberturas_negociadas(comprador_tenant_id)', r.schema_name);
      execute format('create index if not exists idx_coberturas_negociadas_criado_por on %I.coberturas_negociadas(criado_por)', r.schema_name);
      execute format('create index if not exists idx_coberturas_negociadas_fonte_cobertura_id on %I.coberturas_negociadas(fonte_cobertura_id)', r.schema_name);
      execute format('create index if not exists idx_coberturas_negociadas_lancamento_id on %I.coberturas_negociadas(lancamento_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'estoque_movimentos') then
      execute format('create index if not exists idx_estoque_movimentos_animal_id on %I.estoque_movimentos(animal_id)', r.schema_name);
      execute format('create index if not exists idx_estoque_movimentos_criado_por on %I.estoque_movimentos(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'eventos') then
      execute format('create index if not exists idx_eventos_criado_por on %I.eventos(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'eventos_animais') then
      execute format('create index if not exists idx_eventos_animais_animal_id on %I.eventos_animais(animal_id)', r.schema_name);
      execute format('create index if not exists idx_eventos_animais_evento_id on %I.eventos_animais(evento_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'exames') then
      execute format('create index if not exists idx_exames_criado_por on %I.exames(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'fontes_cobertura') then
      execute format('create index if not exists idx_fontes_cobertura_criado_por on %I.fontes_cobertura(criado_por)', r.schema_name);
      execute format('create index if not exists idx_fontes_cobertura_doadora_animal_id on %I.fontes_cobertura(doadora_animal_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'gestacoes') then
      execute format('create index if not exists idx_gestacoes_criado_por on %I.gestacoes(criado_por)', r.schema_name);
      execute format('create index if not exists idx_gestacoes_egua_id on %I.gestacoes(egua_id)', r.schema_name);
      execute format('create index if not exists idx_gestacoes_protocolo_aplicado_id on %I.gestacoes(protocolo_aplicado_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'lancamentos') then
      execute format('create index if not exists idx_lancamentos_animal_id on %I.lancamentos(animal_id)', r.schema_name);
      execute format('create index if not exists idx_lancamentos_criado_por on %I.lancamentos(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'medidas') then
      execute format('create index if not exists idx_medidas_animal_id on %I.medidas(animal_id)', r.schema_name);
      execute format('create index if not exists idx_medidas_criado_por on %I.medidas(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'nutricao_projeto_itens') then
      execute format('create index if not exists idx_nutricao_projeto_itens_projeto_id on %I.nutricao_projeto_itens(projeto_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'nutricao_projetos') then
      execute format('create index if not exists idx_nutricao_projetos_criado_por on %I.nutricao_projetos(criado_por)', r.schema_name);
      execute format('create index if not exists idx_nutricao_projetos_template_origem_id on %I.nutricao_projetos(template_origem_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'nutricao_template_itens') then
      execute format('create index if not exists idx_nutricao_template_itens_template_id on %I.nutricao_template_itens(template_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'nutricao_templates') then
      execute format('create index if not exists idx_nutricao_templates_criado_por on %I.nutricao_templates(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'pendencias') then
      execute format('create index if not exists idx_pendencias_animal_id on %I.pendencias(animal_id)', r.schema_name);
      execute format('create index if not exists idx_pendencias_resolvida_por on %I.pendencias(resolvida_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'protocolo_aplicado') then
      execute format('create index if not exists idx_protocolo_aplicado_criado_por on %I.protocolo_aplicado(criado_por)', r.schema_name);
      execute format('create index if not exists idx_protocolo_aplicado_protocolo_id on %I.protocolo_aplicado(protocolo_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'protocolos_reproducao') then
      execute format('create index if not exists idx_protocolos_reproducao_criado_por on %I.protocolos_reproducao(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'reproducao_atividades') then
      execute format('create index if not exists idx_reproducao_atividades_acasalamento_id on %I.reproducao_atividades(acasalamento_id)', r.schema_name);
      execute format('create index if not exists idx_reproducao_atividades_criado_por on %I.reproducao_atividades(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'reproducao_estagios') then
      execute format('create index if not exists idx_reproducao_estagios_criado_por on %I.reproducao_estagios(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'tentativas') then
      execute format('create index if not exists idx_tentativas_acasalamento_id on %I.tentativas(acasalamento_id)', r.schema_name);
      execute format('create index if not exists idx_tentativas_criado_por on %I.tentativas(criado_por)', r.schema_name);
      execute format('create index if not exists idx_tentativas_veterinario_id on %I.tentativas(veterinario_id)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'tratamentos') then
      execute format('create index if not exists idx_tratamentos_animal_id on %I.tratamentos(animal_id)', r.schema_name);
      execute format('create index if not exists idx_tratamentos_criado_por on %I.tratamentos(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'vacinacoes') then
      execute format('create index if not exists idx_vacinacoes_criado_por on %I.vacinacoes(criado_por)', r.schema_name);
    end if;
    if exists (select 1 from information_schema.tables where table_schema = r.schema_name and table_name = 'vermifugacoes') then
      execute format('create index if not exists idx_vermifugacoes_animal_id on %I.vermifugacoes(animal_id)', r.schema_name);
      execute format('create index if not exists idx_vermifugacoes_criado_por on %I.vermifugacoes(criado_por)', r.schema_name);
    end if;
  end loop;
end $$;

-- 2) RLS reavaliando auth.role()/auth.uid() por linha em vez de uma vez por
--    query (achado "auth_rls_initplan") — todas em tabelas de controle
--    (`public`, nunca clonadas por cabanha, então não precisa de loop).
--    Troca auth.<fn>() por (select auth.<fn>()): o Postgres passa a tratar
--    como um valor estável (InitPlan), calculado uma vez, em vez de reavaliar
--    pra cada linha da tabela. Mesmo resultado, mais rápido em tabela grande.
alter policy "service_role only" on public.planos          using ((select auth.role()) = 'service_role');
alter policy "service_role only" on public.tenants          using ((select auth.role()) = 'service_role');
alter policy "service_role only" on public.assinaturas      using ((select auth.role()) = 'service_role');
alter policy "service_role only" on public.usuarios_master  using ((select auth.role()) = 'service_role');
alter policy "service_role only" on public.webhook_log      using ((select auth.role()) = 'service_role');
alter policy "service_role only" on public.provision_log    using ((select auth.role()) = 'service_role');
alter policy memb_self_select    on public.tenant_memberships using (user_id = (select auth.uid()));
