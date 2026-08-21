-- Corrige um bug real: editar o perfil de um usuário na tela Conta > Usuários
-- só fazia PATCH em cab_<slug>.usuarios.perfil (_dbSalvarUsuario, index.html) —
-- nunca em public.tenant_memberships.perfil, que é o valor que _entrarCabanha()
-- usa (com prioridade sobre o do schema — ver `const perfil = cab.perfil ||
-- u?.perfil || 'cab';`) toda vez que a pessoa loga de novo. Resultado: rebaixar
-- alguém de admin pra cabanheiro (ou promover) parecia funcionar na hora (a UI
-- atualiza o estado local otimisticamente), mas revertia sozinho no próximo
-- login — a badge da sidebar e as permissões reais continuavam com o perfil
-- antigo, porque vinham de tenant_memberships, nunca tocado.
--
-- Achado pelo Pedro (2026-08-22): rebaixou a própria conta de teste pra
-- cabanheiro, a UI mostrou a mudança, mas a sidebar continuou "Administrador".
--
-- Esta RPC dá o caminho certo pra fazer as duas atualizações juntas (schema +
-- tenant_memberships). O index.html é atualizado em seguida pra chamá-la.

begin;

create or replace function public.atualizar_perfil_membership(
  p_tenant_id uuid,
  p_auth_user_id uuid,
  p_perfil text
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if p_perfil not in ('adm','vet','cab') then
    raise exception 'perfil invalido: %', p_perfil;
  end if;

  -- Mesma regra de autorização de revogar_acesso_usuario: só admin ativo desta
  -- cabanha pode alterar perfil de membership (o próprio ou de outro membro).
  if not exists (
    select 1 from public.tenant_memberships
    where user_id = auth.uid() and tenant_id = p_tenant_id and ativo and perfil = 'adm'
  ) then
    raise exception 'sem permissao para alterar perfil nesta cabanha';
  end if;

  -- Nunca deixar a cabanha sem nenhum admin ativo — mesma trava que já existia
  -- só no cliente (excluirUsuario, index.html), agora garantida no servidor.
  if p_perfil <> 'adm' and exists (
    select 1 from public.tenant_memberships
    where tenant_id = p_tenant_id and user_id = p_auth_user_id and ativo and perfil = 'adm'
  ) and (
    select count(*) from public.tenant_memberships
    where tenant_id = p_tenant_id and ativo and perfil = 'adm'
  ) <= 1 then
    raise exception 'nao e possivel remover o unico administrador ativo da cabanha';
  end if;

  update public.tenant_memberships
  set perfil = p_perfil
  where tenant_id = p_tenant_id and user_id = p_auth_user_id and ativo;

  -- Sem isso, um p_auth_user_id errado (id trocado, membership já revogada) faz a
  -- função "ter sucesso" sem alterar nada — exatamente a categoria de bug que
  -- motivou esta migration (mudança que parece ter funcionado e não teve efeito).
  if not found then
    raise exception 'usuario nao e membro ativo desta cabanha';
  end if;

  return true;
end;
$function$;

revoke all on function public.atualizar_perfil_membership(uuid, uuid, text) from public, anon;
grant execute on function public.atualizar_perfil_membership(uuid, uuid, text) to authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rodar depois de aplicar:
--   select has_function_privilege('anon', 'public.atualizar_perfil_membership(uuid,uuid,text)', 'execute');       -- false
--   select has_function_privilege('authenticated', 'public.atualizar_perfil_membership(uuid,uuid,text)', 'execute'); -- true
--
-- Teste funcional (como admin de uma cabanha de teste):
--   1. Editar o perfil de outro usuário (não você) de adm pra cab na tela Usuários.
--   2. Conferir: select perfil from tenant_memberships where tenant_id=... and user_id=...
--      (deve refletir o novo valor, não só o da tabela usuarios do schema).
--   3. Esse usuário desloga e loga de novo — badge da sidebar deve mostrar o
--      perfil novo, não o antigo.
--   4. Tentar rebaixar o único admin ativo — deve falhar com a mensagem de erro.
-- ═══════════════════════════════════════════════════════════════════════════
