-- Reorganização da jornada de compra (2026-08-29): checkout reduzido ao mínimo
-- (plano, nome da cabanha, email, CPF/CNPJ + cartão no trial) — responsável,
-- telefone e código ABCCC saem do checkout e passam a ser preenchidos dentro
-- do onboarding (etapa 1), que já existe e já pede afixo/cidade/UF.
--
-- Esta migration só adiciona p_abccc_codigo (opcional) na RPC existente
-- atualizar_tenant_onboarding, seguindo o mesmo padrão coalesce/nullif das
-- outras colunas -- nada é removido, só um parâmetro novo.

create or replace function public.atualizar_tenant_onboarding(
  p_tenant_id uuid,
  p_nome_cabanha text default null,
  p_afixo text default null,
  p_cidade text default null,
  p_uf text default null,
  p_foco_inicial text default null,
  p_onboarding_completo boolean default null,
  p_nome_exibicao text default null,
  p_abccc_codigo text default null
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (
    select 1 from public.tenant_memberships
    where user_id = auth.uid() and tenant_id = p_tenant_id and ativo and perfil = 'adm'
  ) then
    raise exception 'sem permissao para editar esta cabanha';
  end if;

  update public.tenants
  set nome_cabanha = coalesce(nullif(trim(p_nome_cabanha), ''), nome_cabanha),
      nome_exibicao = case
        when p_nome_exibicao is not null then nullif(trim(p_nome_exibicao), '')
        when p_nome_cabanha is not null then nullif(trim(p_nome_cabanha), '')
        else nome_exibicao
      end,
      afixo = case when p_afixo is not null then nullif(trim(p_afixo), '') else afixo end,
      cidade = case when p_cidade is not null then nullif(trim(p_cidade), '') else cidade end,
      uf = case when p_uf is not null then nullif(trim(p_uf), '') else uf end,
      abccc_codigo = case when p_abccc_codigo is not null then nullif(trim(p_abccc_codigo), '') else abccc_codigo end,
      foco_inicial = case when p_foco_inicial is not null then nullif(trim(p_foco_inicial), '') else foco_inicial end,
      onboarding_completo = coalesce(p_onboarding_completo, onboarding_completo),
      atualizado_em = now()
  where id = p_tenant_id;

  return true;
end;
$$;
