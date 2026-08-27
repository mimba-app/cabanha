# ADRs — Architecture Decision Records (Mimba)

Registro curto das decisões de arquitetura: contexto, decisão e consequências. **Decisão registrada não se rediscute** sem um novo ADR que a substitua.

## Formato
Cada ADR: `NNNN-titulo-em-kebab.md`, com:
- **Status:** Proposto / Aceito / Substituído por NNNN / Descontinuado
- **Contexto:** o problema e as forças em jogo
- **Decisão:** o que foi decidido
- **Consequências:** o que ganhamos, o que abrimos mão, dívidas
- **Alternativas consideradas**

Um ADR é curto (~1 página). Escreva quando a decisão for difícil de reverter, afetar isolamento/segurança, ou definir uma direção estrutural. Quem escreve/atualiza é o subagente `arquiteto`.

## Índice
- [0001](0001-multi-tenant-por-schema.md) — Multi-tenant por schema Postgres
- [0002](0002-auth-identity-first.md) — Auth identity-first (Supabase Auth + membership + RLS)
- [0003](0003-provisionamento-por-clone-do-template.md) — Provisionamento por clone do template
- [0004](0004-captura-de-cartao-trial-sem-tokenizacao-client-side.md) — Captura de cartão no trial sem tokenização client-side
- [0005](0005-empacotamento-mobile-em-3-fases.md) — Empacotamento mobile em 3 fases (Capacitor primeiro, nativo depois)
- [0006](0006-agente-de-ia-interno-arquitetura.md) — Agente de IA interno: orquestração, ferramentas seguras e custo
- [0007](0007-agente-ia-especialista-abccc-adiado.md) — Agente de IA, caso de uso 3 (especialista ABCCC): adiar, não decidir acoplamento agora
- [0008](0008-perfil-pessoal-do-usuario-em-tabela-global.md) — Perfil pessoal do usuário: tabela global em `public`, não `usuarios_master`
- [0009](0009-especialista-abccc-destravado-sincronizacao-periodica.md) — Agente de IA, caso de uso 3 (especialista ABCCC): destravado via sincronização periódica pra produção (renumerada de 0008 — colidia com a ADR acima)
- [0010](0010-onde-mora-a-area-de-dados.md) — Onde mora a Área de Dados: projeto analítico (Mimba Lab) separado + invariante de isolamento produção↔Lab (trazida da branch `recuperacao/area-dados-fora-de-producao` em 2026-08-26, renumerada de 0005 — colidia com a ADR de empacotamento mobile)

_Próximo ADR provável: como quebrar o `index.html` (mono-arquivo) preservando o deploy leve._
