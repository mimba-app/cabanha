-- Autopreencher veterinário (nome + CRMV) ao registrar vacina/exame/AIE, em vez
-- de digitar toda vez. O app já tem `usuarios.especialidade_reproducao` como
-- precedente de campo específico de veterinário nessa mesma tabela — `crmv`
-- segue o mesmo padrão, mas esse aqui é editável pelo próprio usuário em "Meu
-- Perfil" (especialidade_reproducao continua só editável via SQL Editor).
--
-- Fica em `usuarios` (por cabanha), não em `usuarios_master` (identidade global):
-- é o único dos dois que já é carregado de verdade em `usuarioAtual` no login
-- (`_entrarCabanha`, index.html) — usuarios_master tem campos parecidos (cargo,
-- telefone_pessoal) que nunca são buscados do banco nessa função, só refletidos
-- localmente depois de salvos na mesma sessão. Usar esse caminho já confiável
-- em vez de estender o que já está quebrado.

-- 1) Template `public`
alter table public.usuarios add column if not exists crmv text;

-- 2) Replicar em todas as cabanhas já provisionadas
do $$
declare r record;
begin
  for r in select schema_name from public.tenants
           where provisionado = true
             and exists (select 1 from pg_namespace where nspname = schema_name)
  loop
    execute format('alter table %I.usuarios add column if not exists crmv text', r.schema_name);
  end loop;
end $$;

-- Nenhuma policy/trigger/grant novo — coluna simples, texto livre, sem
-- constraint (formato de CRMV varia por estado/conselho). Cabanhas novas já
-- nascem com a coluna via LIKE INCLUDING ALL do provisionamento.
