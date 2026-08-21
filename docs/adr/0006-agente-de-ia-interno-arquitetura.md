# 0006 — Agente de IA interno: orquestração, ferramentas seguras e custo

**Status:** Aceito (2026-08-22). Escopo de produto fechado por Pedro e Luciano (2026-08-22); esta é a decisão de arquitetura sobre como construir.

## Contexto

Pedro e Luciano decidiram construir um agente de IA interno de apoio, acessível via chat flutuante em qualquer tela do `index.html`, cobrindo 4 casos de uso já fechados (não rediscutidos aqui):

1. Perguntas sobre o dado da própria cabanha logada (schema `cab_<slug>`, projeto de produção `fmjfvfufkqswweyasjyp`).
2. Sugestão/análise de manejo e cruzamento, apoiada no ranking do Conselho (jornada de acasalamento — `docs/spec-acasalamento-jornada-tres-direcoes.md`).
3. Especialista ABCCC (genealogia, campeões, ancestralidade), reaproveitando o `mimba-analytics` (projeto Supabase separado, org "Mimba Lab", `njynlsugmvtuvcczmuld`, publicado hoje em `app.mimba.com.br/lab/`) — RPCs `analisar_cruzamento(sbb_garanhao, sbb_egua, objetivo)` e `genealogia_resumo()`.
4. Ajuda de uso do sistema (onboarding/suporte embutido).

Três forças em jogo, na ordem de prioridade do projeto:

- **Isolamento multi-tenant é inegociável.** O agente nunca pode montar SQL livre nem vazar dado de uma cabanha para outra. Toda leitura de dado de cabanha precisa passar pelo mesmo modelo de autorização já usado no resto do app (`tem_acesso_tenant`, RLS, JWT do usuário).
- **`mimba-analytics` já foi deliberadamente separado do banco de produção** (decisão anterior de arquitetura). Esse limite não muda: o agente lê de lá como dado agregado/público, nunca escreve, e nunca mistura com dado de cabanha na mesma chamada de forma que pareça a mesma fonte.
- **Frontend sem framework/bundler.** O chat flutuante é JS simples no `index.html`, chamando uma Edge Function via `fetch`, no mesmo padrão de `_rpc()`/`_ja*` já existente. Nenhuma dependência client-side nova.

## Decisão

### 1. Modelo e orquestração

- **LLM: Claude (Anthropic API)**, chamado a partir de uma Edge Function Deno nova, `agente-ia` (nome provisório — decidir na implementação), seguindo o mesmo padrão de `convidar-usuario`/`buscar-abccc`/`analise-sangues`: `verify_jwt=true`, roda com o JWT do usuário autenticado (nunca `service_role`; o agente só precisa do que o próprio usuário já pode ver).
  - Justificativa: tool use (function calling) maduro e é exatamente o mecanismo que resolve o requisito de segurança do item 2 (ferramentas restritas, nunca SQL livre). Suporte a streaming nativo (SSE) encaixa direto no padrão `fetch`/`ReadableStream` do frontend atual, sem biblioteca cliente. Não há razão de negócio para múltiplos provedores agora — multi-modelo é complexidade antecipada, ver "Alternativas".
- **Streaming:** a Edge Function abre a conexão com a API da Claude em modo streaming e repassa os chunks (SSE) direto para o chat via `ReadableStream` — sem buffer completo no meio. O frontend consome com `fetch` + leitura incremental do body, sem lib nova.
- **Modelo único por ora** (ex.: Claude Sonnet corrente) para os 4 casos de uso. Roteamento entre modelos (mais barato para "ajuda de uso", mais caro para análise de cruzamento) é otimização de custo real, mas antecipada — só decidir se o custo observado em produção justificar (ver seção de custo).
- **Segredo:** `ANTHROPIC_API_KEY` vive como variável de ambiente/secret da Edge Function, nunca no `index.html` (diferente da anon key do Supabase, que é pública por desenho). O mesmo vale para a credencial do projeto `mimba-analytics` usada pela Edge Function (ver item 2).

### 2. Ferramentas (tool use) — o ponto crítico

**Princípio de design, não negociável:** toda ferramenta exposta ao agente é uma chamada a uma RPC já existente e segura, **ou** uma RPC nova read-only, criada com o mesmo padrão já estabelecido no projeto (`SECURITY DEFINER`, `search_path` fixo, `tem_acesso_tenant(<tenant_id>)`, grant explícito só para `authenticated`, nunca `anon`). **O agente nunca recebe acesso a montar ou executar SQL livre — nem via ferramenta "genérica de consulta".** Isso não é uma escolha de conveniência, é a mesma regra de ouro que já vale para todo o resto do app.

A Edge Function é quem decide quais ferramentas oferecer à Claude API em cada chamada (não há descoberta dinâmica de schema pelo modelo) e quem **executa** a ferramenta chamando a RPC com o JWT do usuário — a autorização real acontece no Postgres via RLS/`tem_acesso_tenant`, exatamente como qualquer outra chamada do app. A Edge Function nunca eleva privilégio para satisfazer uma ferramenta.

Superfície de ferramentas proposta (nomeada por prefixo de domínio, para reforçar a separação do item 3):

| Ferramenta | Domínio | Fonte |
|---|---|---|
| `cab_buscar_animal(nome_ou_sbb)` | Cabanha | RPC existente ou nova, read-only, `cab_<slug>` |
| `cab_listar_gestacoes_ativas()` | Cabanha | RPC nova, read-only |
| `cab_resumo_periodo(data_inicio, data_fim)` | Cabanha | RPC nova, read-only (base do "resumo da semana") |
| `abccc_analisar_cruzamento(sbb_garanhao, sbb_egua, objetivo)` | ABCCC/Lab | RPC já existente em `mimba-analytics` |
| `abccc_genealogia_resumo(sbb)` | ABCCC/Lab | RPC já existente em `mimba-analytics` |
| `ajuda_sistema(topico)` | Suporte | **não é RPC** — busca numa base de conhecimento estática (ver item 3) |

Fora do escopo desta ADR (decidir na implementação, com `revisor-isolamento` no loop): assinatura exata, nomes finais e SQL de cada RPC nova.

**Caso especial — ranking do Conselho (caso de uso 2):** hoje o score de consanguinidade/diversidade/saldo (`_jaConsanguinidade`, `_jaScoreConsang` etc.) é calculado **no cliente** (`index.html`), não em RPC. Duas opções:

- (A) Fase 1 — mais simples: quando o usuário abre o chat estando na tela do Conselho, o frontend anexa o ranking já computado na tela como contexto da mensagem (dado que o próprio usuário já está vendo, sem chamada nova nenhuma). O agente comenta/raciocina sobre esse contexto, mas não tem uma ferramenta para recalcular o ranking sob demanda fora dessa tela.
- (B) Promover o cálculo para uma RPC server-side (`cab_consultar_ranking_conselho`), única fonte de verdade, chamável como ferramenta em qualquer tela.

**Decisão: começar pela opção (A).** Duplicar a lógica de score numa RPC agora é antecipar uma necessidade (o agente "puxar" o ranking fora do contexto da tela) que ainda não foi validada como caso real de uso. Se o uso mostrar que os usuários pedem análise de cruzamento pelo chat fora da tela do Conselho, isso vira uma proposta de RPC nova nesta mesma trilha (RPC read-only + `revisor-isolamento`), promovendo a lógica para (B) e eliminando a duplicação.

### 3. Como combinar os 3 domínios sem confundir o usuário

Três fontes, e o agente precisa deixar claro qual é qual:

- **Dado da cabanha** (produção, `cab_<slug>`) — privado, tenant-scoped.
- **Dado ABCCC/`mimba-analytics`** — agregado/público, cross-tenant por natureza (genealogia e resultados de competição não pertencem a uma cabanha).
- **Conhecimento de uso do sistema** — não é dado de banco nenhum. Vira uma **base de conhecimento estática** (markdown/texto curado, versionado no repo, ex. `docs/agente-ia-base-conhecimento.md`) injetada no system prompt ou recuperada por busca simples de texto — não é uma RPC, não toca banco.

Para não misturar de forma enganosa:

- Cada resultado de ferramenta volta para o modelo com um envelope estruturado que inclui a fonte (`{"fonte": "cabanha" | "abccc_lab" | "sistema", ...}`), **atribuído pela Edge Function, nunca pelo modelo** — a Edge Function sabe qual ferramenta chamou, então sabe a fonte real; o modelo não pode alegar uma fonte diferente da que efetivamente respondeu.
- O system prompt instrui explicitamente: sempre que a resposta combinar mais de uma fonte, dizer isso ao usuário (ex.: "na sua cabanha..." vs "segundo os registros da ABCCC..."), e nunca apresentar dado agregado do Lab como se fosse específico da cabanha do usuário, nem o contrário.
- Isso é hoje uma instrução de prompt (mais simples, ajustável sem migration). Se a instrução não bastar na prática (o modelo confundir fontes em produção), o próximo passo é fazer a UI do chat renderizar um badge de fonte por trecho — mas isso é UX, fora do escopo desta ADR, e só vira necessário se o prompt sozinho não resolver.

### 4. Modelo de custo

Chamada de LLM tem custo por token, direto proporcional a uso — isso **precisa entrar na precificação por plano**, não é só custo de infraestrutura fixo como o restante do Supabase. Abordagem recomendada, sem fixar preço final:

- **Rate limit técnico por tenant, configurável por plano**, aplicado na Edge Function antes de chamar a API da Claude: cada tenant tem uma cota de mensagens/mês (ou de tokens, mensagens é mais simples de comunicar ao cliente). A cota fica associada ao plano do tenant (tabela `planos`, control-plane em `public` — adicionar uma coluna/config de limite, na implementação).
- **Uso registrado** numa tabela de controle no `public` (ex. `uso_ia_mensal(tenant_id, mes, contagem)`), incrementada pela Edge Function a cada chamada concluída — mesmo padrão de auditoria já usado (`audit_log`).
- Ao atingir a cota: bloquear com mensagem clara (não degradar silenciosamente para uma resposta pior) e, futuramente, oferecer upgrade — mas o mecanismo de upsell não é desta ADR.
- **Não decidir aqui:** o número exato de mensagens por plano, se é feature paga à parte ou incluída em todos os planos com limite, e se plano trial tem acesso. Isso é decisão de precificação de produto (Pedro/Luciano), não de arquitetura — só registrar que a arquitetura já nasce com o hook técnico (rate limit por tenant) pronto para receber esse número.

## Consequências

- (+) Reaproveita 100% do padrão de segurança já validado no projeto (RLS, `tem_acesso_tenant`, `SECURITY DEFINER`, Edge Function com JWT do usuário) — não inventa um mecanismo de autorização paralelo para o agente.
- (+) Superfície de ataque contida: o agente nunca tem mais alcance de dado do que o próprio usuário já tem via RPCs existentes — não pode vazar entre cabanhas, porque as ferramentas rodam com o JWT do usuário e a RLS já resolve isso.
- (+) Streaming reaproveita o padrão `fetch` do `index.html`, sem framework/bundler novo no frontend.
- (+) A separação de domínio (`cab_*`, `abccc_*`, base estática) fica explícita já na nomenclatura das ferramentas, reduzindo confusão de fonte tanto para o modelo quanto para quem for revisar/depurar depois.
- (−) Cada RPC nova (`cab_listar_gestacoes_ativas`, `cab_resumo_periodo` etc.) é trabalho de implementação real que passa por `revisor-isolamento` antes de existir — este ADR não os cria, só desenha a superfície esperada.
- (−) Opção (A) para o ranking do Conselho é uma dívida consciente: o agente só "vê" o ranking quando o usuário já está na tela certa. Se isso frustrar o caso de uso 2 na prática, vira trabalho novo (RPC + revisão de isolamento) para promover a (B).
- (−) Custo por token é uma variável nova na precificação que a equipe de produto ainda precisa fechar (número da cota por plano) — a arquitetura só entrega o hook técnico, não a decisão de preço.
- (?) Modelo único (sem roteamento por caso de uso) pode não ser o mais barato a longo prazo; fica como possível otimização futura, não compromisso.

## Alternativas consideradas

- **Function calling com acesso a schema/SQL genérico ("dê ao modelo uma ferramenta `executar_query_readonly`"):** rejeitada — viola diretamente a regra de ouro de isolamento. Mesmo limitando a `SELECT`, um modelo pode ser induzido (prompt injection, erro de geração) a construir uma query que atravessa tenant, ou a RLS pode não cobrir 100% dos casos de uma query arbitrária da forma como cobre RPCs desenhadas a dedo. Ferramenta = RPC nomeada e revisada, sempre.
- **Orquestração no frontend (chamar a API da Claude direto do `index.html`):** rejeitada — exigiria expor a `ANTHROPIC_API_KEY` no cliente (como a anon key), mas essa chave, ao contrário da anon key, não tem RLS nenhuma te protegendo do lado do provedor — quem a tiver gasta o orçamento de IA da Mimba inteira. Orquestração fica na Edge Function, com a chave só no ambiente do servidor.
- **Múltiplos provedores de LLM (Claude + OpenAI, roteamento por caso de uso) já na v1:** rejeitada por ora — complexidade e superfície de manutenção antecipadas sem necessidade validada; um único provedor resolve os 4 casos de uso hoje.
- **Promover já o ranking do Conselho para uma RPC (opção B) na v1:** rejeitada por ora — ver item 2, é antecipar uso não validado; opção (A) é o menor passo que valida a direção.
- **Sem rate limit técnico, confiar só em alerta de custo manual:** rejeitada — custo por token escala com uso de forma imprevisível por tenant; um único tenant "conversador" pode estourar o orçamento de IA de todos os outros sem um limite técnico por tenant.

## Próximos passos (fora desta ADR)

- Qualquer RPC nova (`cab_buscar_animal`, `cab_listar_gestacoes_ativas`, `cab_resumo_periodo`, e a eventual `cab_consultar_ranking_conselho` se a opção B for acionada) passa por `revisor-isolamento` **antes** de ser implementada — são leitura de dado de cabanha, entram na regra de "toda mudança em auth/RLS/queries cross-schema exige revisão".
- Decisão de precificação (cota por plano) fica com Pedro/Luciano — arquitetura só entrega o hook técnico (rate limit por tenant).
- Base de conhecimento estática de uso do sistema (`docs/agente-ia-base-conhecimento.md` ou equivalente) é conteúdo a escrever, não decisão de arquitetura — pode ser feito em paralelo.
