# Mimba — contexto do projeto

> Contexto sempre carregado. Para retomar o estado atual e o roadmap, veja `HANDOFF.md`.

## O que é
**Mimba** — SaaS multi-tenant de gestão para cabanhas de cavalo crioulo, integrado à ABCCC. Marca: Mimba (razão social: Mimba Tech; posicionamento v1: "Gestão Crioulos"). Domínios: **mimba.com.br** (landing) e **app.mimba.com.br** (sistema). Cada cabanha assinante tem seus dados isolados no banco.

## Arquitetura
- **Frontend:** `index.html` único, sem framework/bundler/`package.json`, hospedado no **GitHub Pages**. Escolha deliberada pra deploy leve. Marca Mimba via variáveis CSS (paleta verde-oliva/creme neutro — skin oficial recuperada de uma versão de referência em 2026-08-12, ver `HANDOFF.md`; fontes DM Sans + Playfair + DM Mono).
- **Backend:** Supabase (projeto `fmjfvfufkqswweyasjyp`) — Postgres + Edge Functions (Deno) + Auth. anon key é pública (está no index.html).
- **Multi-tenant por schema Postgres:** cada cabanha = schema `cab_<slug>`. **`public` é o template** (tabelas operacionais vazias). Control-plane em `public` (tenants, signups, tenant_memberships, planos, usuarios_master).
- **Identidade/login (identity-first):** Supabase Auth (email+senha, JWT). `tenant_memberships` liga uma identidade a N cabanhas (perfil adm/vet/cab por cabanha). Login: email → JWT → RPC `minhas_cabanhas()` → 1 entra direto, N abre seletor. O app usa o **JWT do usuário** (não a anon key).
- **Isolamento (RLS):** policies só `authenticated` via `tem_acesso_tenant(<tenant_id>)`, envolto em `(select ...)`. `anon` não tem grant/USAGE nos schemas de cabanha.
- **Provisionamento:** `signups` → Edge Function `asaas-webhook` (valida token Asaas) → Edge Function `provisionar-cabanha` (exige `Bearer service_role`) → RPC `provisionar_schema_cabanha(p_schema)` (clona o `public` via `LIKE INCLUDING ALL` + RLS + grants + triggers) → cria admin no `auth.users` + membership → expõe o schema via Management API (`SB_MGMT_TOKEN`).

## Convenções
- **Frontend sem framework/bundler** — **não sugerir React, build step ou package manager sem confirmar antes.**
- Edge Functions rodam em **Deno**, não Node.
- **Banco:** o MCP do Supabase **permite write** via `apply_migration` (confirmado em 2026-08-13 — antes achávamos que era read-only e pedíamos pro usuário rodar no SQL Editor; não é mais o caso). Pode aplicar migration/função/policy direto pelo MCP. Mesmo assim, sempre gerar o SQL como arquivo em `docs/migrations/` primeiro (revisável, versionado) antes de aplicar — e mudanças em auth/RLS/provisionamento passam pelo `revisor-isolamento` antes.
- **Deploy:** push na `main` → GitHub Pages publica; o workflow `versionar.yml` arquiva as últimas 10 versões em `versions/`. Sempre commitar só o `index.html` (conferir o staged).
- Commits terminam com `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## Regras que nunca podem ser quebradas
- **Isolamento entre cabanhas.** Nenhuma query pode vazar dados entre schemas. Toda mudança em **auth, provisionamento, RLS ou queries cross-schema** exige revisão com o subagente **`revisor-isolamento`** antes de mergear.
- **Provisionamento clona do `public` (LIKE) — nunca DDL à mão.** DDL manual foi o bug original que gerava schema "torto".
- **Não dropar as tabelas do `public`** (é o template do provisionamento).
- **Migration que altera o template `public` precisa refletir em todos os schemas `cab_*` existentes** — siga a skill **`nova-migration-tenant`** em vez de aplicar solto.
- **Nunca commitar segredos** (service_role, PATs, tokens do Asaas). A anon key é pública/ok.
- Nunca aplicar migration direto em produção sem testar num schema isolado.

## Fluxo de trabalho
- Branch por pessoa/worktree; PR antes de mergear na `main`.
- Rodar a revisão de isolamento (`revisor-isolamento`) antes de qualquer PR que toque provisionamento, auth ou RLS.

## Extensões deste projeto (`.claude/`)
- **Subagentes** (`.claude/agents/`): `revisor-isolamento` (revisão de isolamento multi-tenant). *(Planejados: `arquiteto` p/ decisões de escala, `engenheiro-frontend` p/ o refactor do index.html.)*
- **Skills** (`.claude/skills/`): `nova-migration-tenant` (migration que reflete em todos os tenants). *(Planejadas: `deploy`, `testar-provisionamento`.)*

## Estado e continuidade
`HANDOFF.md` = checkpoint atual (o que está feito/pendente). Memória do projeto (carregada automaticamente): `MEMORY.md` e arquivos ligados.
