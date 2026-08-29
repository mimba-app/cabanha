-- Complemento da migration 2026-08-29-onboarding-abccc-e-perfil-publico.sql:
-- minhas_cabanhas() não devolvia abccc_codigo, então TENANT_INFO nunca carregava
-- esse dado pro onboarding poder pré-preencher o campo ao reabrir. Só adiciona
-- a coluna na projeção, mesmo padrão de afixo/cidade/uf já existentes -- sem
-- mudar WHERE/JOIN/checagem de acesso. Revisado por revisor-isolamento (aprovado).

create or replace function public.minhas_cabanhas()
returns table(
  tenant_id uuid, schema_name text, nome_cabanha text, nome_exibicao text,
  logo_url text, cor_primaria text, perfil text, ambiente_teste boolean,
  status text, trial_fim timestamptz, plano_id uuid, plano_features jsonb,
  onboarding_completo boolean, afixo text, cidade text, uf text, foco_inicial text,
  abccc_codigo text
)
language sql
stable security definer
set search_path to 'public'
as $$
  select t.id, t.schema_name, t.nome_cabanha, t.nome_exibicao,
         t.logo_url, t.cor_primaria, m.perfil, t.ambiente_teste, t.status, t.trial_fim, t.plano_id,
         p.features, t.onboarding_completo, t.afixo, t.cidade, t.uf, t.foco_inicial,
         t.abccc_codigo
  from public.tenant_memberships m
  join public.tenants t on t.id = m.tenant_id
  left join public.planos p on p.id = t.plano_id
  where m.user_id = auth.uid()
    and m.ativo
    and t.status in ('ativo', 'trial', 'bloqueado', 'cancelado')
    and t.provisionado = true
  order by t.nome_cabanha;
$$;
