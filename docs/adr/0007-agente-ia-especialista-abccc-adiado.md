# 0007 — Agente de IA, caso de uso 3 (especialista ABCCC): adiar, não decidir acoplamento agora

**Status:** Aceito (2026-08-23).

## Contexto

O ADR 0006 fechou a arquitetura geral do agente de IA interno e listou 4 casos de uso, incluindo
o caso de uso 3 ("especialista ABCCC" — genealogia/cruzamento, ferramentas planejadas
`abccc_analisar_cruzamento`/`abccc_genealogia_resumo`), com a ressalva explícita de que esses
nomes ainda não existem no banco e que a forma de conectar produção ao `mimba-analytics` ("Mimba
Lab", projeto Supabase separado, `njynlsugmvtuvcczmuld`) nunca foi decidida.

O Pedro escolheu começar a implementação pelo caso de uso 3, não pelo mais simples (caso de uso
1, dado da própria cabanha, que não depende de nenhuma decisão cross-projeto).

Três fatores relevantes, todos levantados em `docs/handoff-mimba-lab-cruzamentos.md`:

1. **O acoplamento entre produção e o Mimba Lab foi deliberadamente cortado depois de um
   incidente grave.** Em 19/08/2026, uma carga malfeita no que então era um único projeto
   Supabase levou a CPU (plano free, compartilhada com produção) a 72%, causando 522 na API e
   derrubando o login de todas as cabanhas pagantes por minutos. O ADR que registrou a resposta
   (`0010-onde-mora-a-area-de-dados.md` — trazido para a `main` em 2026-08-26 e renumerado de
   0005 para 0010 nessa mesma ocasião, pra não colidir com `0005-empacotamento-mobile-em-3-fases.md`;
   até então só existia na branch `recuperacao/area-dados-fora-de-producao`, apesar de já ser
   citado neste ADR) instituiu uma invariante explícita, que o próprio texto marca como valendo
   mais que qualquer detalhe de implementação: *"nenhuma requisição originada de uma cabanha pode
   tocar o projeto analítico — nem direta, nem por proxy. Se o projeto analítico estiver pausado,
   morto ou inexistente, o app continua funcionando por inteiro."* Aquele ADR também comparou
   explicitamente "edge function em produção fazendo proxy" contra o artefato estático e rejeitou
   o proxy por reabrir exatamente esse acoplamento — com o agravante de usar `service_role` do
   projeto analítico a partir de produção.
2. **`analisar_cruzamento` é uma consulta paramétrica sob demanda** (par específico
   garanhão×égua escolhido na hora pelo usuário via chat), não um resumo agregado. O caminho que
   o ADR 0010 desenhou para "consumo pelo app" — artefato estático publicado ~1×/temporada — foi
   pensado para dado agregado que muda pouco (ex. resumo de resultados ABCCC por SBB) e **não
   serve para esse tipo de consulta**: não dá para pré-computar em lote todos os pares possíveis
   sem explodir combinatoriamente.
3. **Cobertura de genealogia real no Lab hoje é baixíssima**: ~836 de ~26.000 SBBs conhecidos
   têm pedigree real carregado (`dados/genealogia/catalogos_animais.csv`). Mesmo resolvendo o
   acesso técnico, `analisar_cruzamento` só responde bem para uma fração pequena do plantel de
   cada cabanha — a maioria das perguntas reais do chat ("compare este garanhão com esta égua")
   cairia fora da cobertura.

Nenhuma variação de acoplamento (proxy com allowlist rígida, cache com TTL, circuit breaker)
resolve o fator 3, e todas as variações que envolvem chamada de rede de produção para o Lab
tensionam diretamente a invariante do ADR 0010 — que só deveria ser reaberta por necessidade real
validada, não para destravar um caso de uso ainda sem usuário esperando por ele.

## Decisão

**Adiar o caso de uso 3 (especialista ABCCC) do agente de IA.** Não escolher entre artefato
estático (A) e proxy de produção (B) agora — nenhuma das duas é uma boa resposta hoje, pelas
razões acima, e forçar uma escolha seria complexidade antecipada sem necessidade validada.

Recomendação concreta: **começar a implementação do agente pelo caso de uso 1** (perguntas sobre
o dado da própria cabanha, ferramentas `cab_*` do ADR 0006), que:

- não depende de nenhuma decisão de acoplamento cross-projeto;
- reaproveita 100% do padrão de segurança já validado (RLS, `tem_acesso_tenant`, JWT do usuário);
- entrega valor real e testável desde a primeira versão do agente;
- é o menor passo que valida a direção geral do agente (orquestração, streaming, tool use,
  rate limit de custo) antes de somar a complexidade extra de uma segunda fonte de dado.

O caso de uso 3 fica **explicitamente fora de escopo** até que pelo menos uma das duas condições
abaixo se torne verdadeira — o que evita reabrir esta decisão sem motivo, mas também deixa claro
o que destravaria:

- **Demanda validada**: uso real do agente (casos 1, 2 e 4 em produção) mostra que usuários
  pedem análise de genealogia/cruzamento pelo chat com frequência que justifique o investimento
  de reabrir a discussão de acoplamento do ADR 0010.
- **Cobertura de genealogia sobe substancialmente** (hoje 836/26.000 SBBs) — sem isso, mesmo
  resolvendo o acesso, a resposta mais comum do agente seria "não tenho pedigree carregado para
  este animal", o que é uma experiência ruim para o primeiro contato do usuário com essa
  ferramenta.

Quando (e se) o caso de uso 3 for retomado, as opções a avaliar continuam sendo as já mapeadas em
`docs/handoff-mimba-lab-cruzamentos.md` (seção 4), nenhuma delas aceita sem revisão adicional:

- **(A) Artefato estático** — descartado para consulta paramétrica sob demanda (par específico),
  mas continua válido se o produto decidir por uma versão mais simples do especialista ABCCC que
  só exiba `genealogia_resumo()` (dado agregado, muda pouco) sem `analisar_cruzamento` sob
  demanda — isso seria um caso de uso 3 reduzido, uma decisão de produto separada desta ADR.
- **(B) Proxy de produção** (Edge Function dedicada, allowlist rígida das duas RPCs, credencial
  restrita por RLS a só essas RPCs read-only, timeout curto com fallback gracioso, rate
  limit/circuit breaker para proteger o Lab no plano free) — só é aceitável **substituindo
  explicitamente a invariante do ADR 0010** para este caso específico, com `revisor-isolamento`
  no loop antes de implementar, e apenas depois que a demanda validada (acima) justificar reabrir
  esse acoplamento.

## Consequências

- (+) O agente de IA sai do papel mais rápido: caso de uso 1 não tem nenhuma pendência de
  arquitetura, só implementação (RPCs `cab_*` + `revisor-isolamento`, já previsto no ADR 0006).
- (+) Preserva intacta a invariante do ADR 0010 (nenhuma requisição de cabanha toca o projeto
  analítico) — não é reaberta sem necessidade real, honrando o motivo pelo qual foi criada.
- (+) Evita investir em uma ferramenta (`abccc_analisar_cruzamento` via chat) cuja cobertura de
  dado (3% dos SBBs conhecidos) tornaria a experiência inicial frustrante para a maioria das
  perguntas.
- (−) O Pedro havia escolhido começar pelo caso de uso 3; esta decisão contraria essa preferência
  de sequenciamento e recomenda inverter para o caso de uso 1 primeiro. Fica registrado como
  divergência explícita para ele decidir se aceita o adiamento ou pede para seguir mesmo assim
  (nesse caso, a decisão mínima viável seria (B) com todas as guardas listadas acima, aceitando
  reabrir o acoplamento do ADR 0010 conscientemente).
- (−) Casos de uso 2 (Conselho) e 4 (ajuda de uso) também ficam represados atrás da priorização
  de produto, mas nenhum dos dois tem uma pendência de arquitetura como o caso de uso 3 — podem
  ser sequenciados livremente depois do caso de uso 1.
- (?) Se a ABCCC ou outra fonte disponibilizar pai/mãe por SBB (não só por nome) no futuro, a
  cobertura de genealogia pode subir rápido e mudar o cálculo — vale revisitar quando isso
  acontecer, não é uma aposta desta ADR.

## Atualização (2026-08-23): Pedro confirmou o "caso de uso 3 reduzido"

Pedro queria começar pelo caso de uso 3 porque, na visão dele, o agente precisa deter o
conhecimento geral do Lab/ABCCC desde o início, cruzando com o dado específico da cabanha em
qualquer sessão — não só ficar restrito ao caso de uso 1. Apresentada a distinção que este ADR já
previa na seção "Decisão" (conhecimento agregado via artefato estático vs. score sob demanda por
par), Pedro confirmou explicitamente a versão reduzida:

- **Entra já, na primeira versão do agente**: conhecimento geral/agregado do Lab (ranking,
  metodologia de pontos, estatísticas da raça, `genealogia_resumo()`) via artefato estático
  gerado fora do caminho de requisição de qualquer tenant — cruzado, na mesma conversa, com o
  dado específico da cabanha logada (ferramentas `cab_*` do ADR 0006). Isso não reabre a
  invariante do ADR 0010: a geração do artefato é manutenção periódica nossa, não uma chamada
  originada por uma cabanha.
- **Continua adiado**: `analisar_cruzamento` sob demanda pra um par garanhão×égua específico
  escolhido no chat — é exatamente o pedaço parametrizado que não cabe em artefato estático e que
  exigiria reabrir o acoplamento (opção B) sem cobertura de dado suficiente, como já registrado
  acima.

Isso não contradiz a decisão original desta ADR — é a "versão reduzida" que a seção de Decisão já
havia deixado como caminho válido, agora confirmada como escopo de produto real em vez de
hipótese.

## Alternativas consideradas

- **Escolher (A) artefato estático já agora**: rejeitada como resposta para o caso de uso 3 tal
  como especificado no ADR 0006 (par garanhão×égua escolhido livremente no chat) — não é
  pré-computável em lote sem explosão combinatória. Continua disponível como opção para uma
  versão reduzida do especialista ABCCC (só `genealogia_resumo`), mas isso é decisão de produto,
  não desta ADR.
- **Escolher (B) proxy de produção já agora, com todas as guardas (allowlist, timeout, circuit
  breaker)**: tecnicamente viável, mas rejeitada por ora — reabre uma invariante de segurança
  criada em resposta direta a um incidente que derrubou produção, para atender um caso de uso
  cuja cobertura de dado (836/26.000 SBBs) ainda não justifica o risco. Fica documentada como o
  caminho técnico se a demanda validada justificar retomar.
- **Cache com TTL curto em produção para reduzir chamadas repetidas ao Lab**: mitigaria custo/
  carga de uma eventual opção (B), mas não resolve nenhum dos dois problemas centrais (a
  invariante do ADR 0010 e a cobertura de dado) — é um detalhe de implementação de (B), não uma
  alternativa a ela.
- **Seguir a ordem original do Pedro (caso de uso 3 primeiro) mesmo com as pendências**: seria
  possível, mas obrigaria a decidir (B) sem uma demanda validada que a justifique — trocaria
  "simples primeiro" por "resolver o caso mais difícil primeiro sem necessidade comprovada",
  contra a filosofia do projeto.
