# 0005 — Onde mora a Área de Dados: projeto analítico separado + artefato estático para o app

**Status:** Aceito (2026-08-20). Substitui a decisão informal registrada no topo do
`HANDOFF-AREA-DADOS.md` ("refazer num projeto Supabase separado"), que resolvia só metade do
problema.

## Contexto

Em 19/08 a Área de Dados foi construída **dentro** do projeto Supabase de produção
(`fmjfvfufkqswweyasjyp`, plano FREE, CPU compartilhada) e derrubou as cabanhas pagantes: 83.778
linhas inseridas **uma a uma** num loop plpgsql, numa tabela com 4 índices de expressão sobre
jsonb, mais uma matview com outros 6 índices e `refresh` não-concorrente. CPU a 72%, checkpoint de
72s para 714 buffers, `statement timeout` no bootstrap do login, API em 522, e o projeto não
voltou nem depois do restart. Disco nunca foi problema (6%, 170 MB).

**A leitura que importa: o volume é irrelevante.** 84 mil linhas não é big data — cabem num
arquivo de 13 MB. O que matou foi o *padrão de escrita* somado à *colocação* junto do transacional
numa instância subdimensionada. Qualquer solução que volte a compartilhar CPU com as cabanhas
repete o incidente, mais cedo ou mais tarde.

O segundo fato decisivo é que a Área de Dados tem **dois consumidores com requisitos opostos**:

| | Exploração (staff Mimba) | Consumo pelo app (todas as cabanhas) |
|---|---|---|
| Quem | 2 pessoas | todo cliente logado |
| Quando | esporádico, horário comercial | no meio da ficha do animal |
| O que faz | escreve: upload de CSV/Excel, importa ABCCC, cria dataset | lê 1 registro por SBB |
| Precisa de | SQL ad-hoc, storage de arquivo, UI de carga | latência baixa e **disponibilidade total** |
| Tolera indisponibilidade? | sim (espera 2 min) | **não** |
| Dado é | tudo, inclusive rascunho | só referência pública da ABCCC, quase imutável |

Tratar esses dois como um sistema só é o que força escolhas ruins. Separados, cada um tem uma
resposta óbvia — e diferente.

Restrições em vigor (CLAUDE.md): frontend é um `index.html` único, sem framework/bundler/npm, em
GitHub Pages; edge functions em Deno; 2 pessoas, sem ops; sensível a custo. Precedente aceito:
carregar biblioteca de CDN sob demanda (SheetJS).

## Decisão

**Separar por consumidor.**

1. **Exploração de staff → segundo projeto Supabase**, em plano free, numa organização separada da
   de produção. As migrations `docs/migrations/2026-08-19-area-dados-fase1..3b.sql` são reaplicadas
   praticamente como estão, com as três correções já identificadas no handoff
   (`insert ... select` no lugar do loop; índice único + `refresh materialized view concurrently`;
   índices de expressão criados **depois** do load).

2. **Consumo pelo app → artefato estático publicado no GitHub Pages**, gerado a partir do projeto
   analítico e servido do mesmo host do `index.html`. As RPCs `ref_abccc_animal` /
   `ref_abccc_reprodutor` deixam de existir como chamada de rede a um banco e viram leitura de
   arquivo.

**Invariante que esta decisão institui, e que vale mais que os detalhes de implementação:**

> Nenhuma requisição originada de uma cabanha pode tocar o projeto analítico — nem direta, nem por
> proxy. Se o projeto analítico estiver pausado, morto ou inexistente, o app continua funcionando
> por inteiro.

Isso é o que fecha o buraco. "Mudar de instância" sozinho não fecha: se o app depende do projeto
analítico em tempo de request, a gente só trocou "analítico derruba produção por CPU" por
"analítico derruba produção por indisponibilidade".

### Formato do artefato (medido, não estimado)

Medido sobre o CSV real (`dados/abccc/painel-resultados-todos-ciclos.csv`, 83.778 linhas, 13 MB
cru / 1,5 MB gzip / 940 KB brotli; 26.121 SBBs e 21.583 reprodutores distintos):

| Nível | Conteúdo | Cru | gzip |
|---|---|---|---|
| **1 — resumo por SBB** | contagens, campeonatos, índice, pai/mãe/criador/sexo | 1,24 MB | **324 KB** |
| **1 — resumo por reprodutor** | filhos premiados, contagens, índice, `melhores_filhos` | 0,67 MB | **206 KB** |
| **1 — os dois juntos** | todo o contrato *numérico* das duas RPCs | 1,91 MB | **530 KB** |
| **2 — detalhe por animal** | `resultados: [{ciclo,cidade,prova,colocacao}]` de cada SBB | 9,56 MB | 1,57 MB |

Isso muda o desenho, e para melhor. **O nível 1 inteiro cabe em 530 KB gzipados** — menos que uma
foto de animal, que o app já baixa sem cerimônia. Não precisa de fatiamento: baixa-se **um arquivo,
uma vez por sessão**, e a partir daí toda consulta de animal e de reprodutor é um lookup em memória,
síncrono, com zero rede. É mais rápido do que qualquer RPC jamais foi.

O nível 2 é o que estoura (1,57 MB gz), e é o único pedaço que precisa de fatiamento por hash do SBB:

```
ref/abccc/manifest.json           { versao, gerado_em, ciclo_max, shards_detalhe: 100 }
ref/abccc/resumo.json             530 KB gz · carregado uma vez, na primeira consulta da sessão
ref/abccc/detalhe/NN.json         100 shards · ~98 KB cru / ~16 KB no fio · sob demanda
```

**Sobre o contrato da seção 5 do `HANDOFF-AREA-DADOS.md`: não é reduzido, é fatiado.** A lista
`resultados` continua sendo entregue — só deixa de vir junto do resumo. Na prática isso casa com o
uso real da tela: a ficha mostra primeiro "12 premiações, 3 campeonatos, índice 47" (nível 1) e só
precisa do histórico prova a prova quando o usuário expande. `_ref('animal', sbb)` devolve o resumo
imediatamente e busca o shard de detalhe em paralelo; `ref_abccc_reprodutor` fica **inteiramente** no
nível 1 e nunca faz uma segunda requisição.

- Servir `.json` puro (o Pages comprime texto no transporte; `.gz` commitado viraria download).
- `manifest.json` com `cache: no-cache`; `resumo.json` e shards com `?v=<versao>` e cache longo.
  Troca de temporada = novo `versao` = invalidação automática.
- Se um dia os 530 KB pesarem em rede móvel ruim, o resumo é fatiado pelo mesmo hash do nível 2 —
  mudança local, mesma função `_ref()`. Hoje seria complexidade sem dor.

### Publicação do artefato

Um exportador gera os shards a partir do projeto analítico e grava em `ref/` no repo do app;
commit → Pages publica. Frequência real: **~1× por temporada**. Não vale automação: um script Node
em `dados/` rodado à mão (o `extrair.mjs` já faz metade do trabalho) é suficiente e é uma peça a
menos para manter. O `versionar.yml` só observa `index.html`, então `ref/` não entra no arquivamento
de versões.

## Como o app alcança o dado (a pergunta em aberto do handoff)

Três caminhos possíveis, comparados:

| | Latência | Exposição de chave | Acoplamento | O que acontece se o analítico pausa |
|---|---|---|---|---|
| **2º client Supabase no front** | 1 RTT + query (~200–700 ms) | 2ª anon key no `index.html` (pública, ok) + **2º login** para todo cliente, ou RPC aberta a `anon` | app depende do projeto analítico em tempo de request | **quebra na cara do cliente** |
| **Edge function em produção fazendo proxy** | 2 RTTs (~400–1200 ms) | `service_role` do analítico guardado em produção — cruza a fronteira que a gente acabou de criar | pior: acopla **e** gasta invocação/CPU de produção | quebra, com timeout mais feio |
| **Artefato estático (escolhido)** | 530 KB uma vez por sessão (~200–400 ms), depois **lookup em memória, ~0 ms** | nenhuma | zero | **nada** |

O artefato não é só o mais seguro: é o **mais rápido dos três** e o único que não tem chave para
vazar. Também é o único que sobrevive a "esquecemos de pagar a fatura do projeto analítico".

O preço: o dado passa a estar atrás de uma URL, não de um login. Ver "o que estamos sacrificando".

## Como o staff autentica na área nova

`public.mimba_staff` e `sou_staff_mimba()` vivem no banco de produção e **ficam lá** (são
pré-existentes e usados por outras coisas — a migration de remoção preserva os dois de propósito).

**Decisão: o projeto analítico tem autenticação própria.** Recria-se lá uma tabela `mimba_staff` e
a função `sou_staff_mimba()` — o SQL das migrations fase 1–3 depende só delas e passa a rodar sem
alteração. Os 2 usuários são criados à mão no Auth do projeto analítico. A aba Dados do Painel
Mimba pede um login próprio (mesmo e-mail, sessão separada), e o `index.html` carrega um segundo
par `DADOS_URL` / `DADOS_ANON_KEY` — ambos públicos, sem segredo novo no repo.

Rejeitado: **compartilhar o JWT secret / JWKS entre os dois projetos** para que o token de produção
valha no analítico. Funciona tecnicamente, e é tentador porque elimina o segundo login. Mas cria um
raio de explosão comum entre produção e um projeto lateral, exatamente na dimensão que este ADR
existe para separar: um comprometimento do projeto analítico passaria a valer tokens de produção. O
custo evitado (dois logins para duas pessoas) não paga esse risco.

Rejeitado também: proxy por edge function com `service_role`. Para leitura pontual já era ruim;
para o fluxo de staff (upload, storage, DDL de dataset) seria reimplementar meio PostgREST à mão.

Gate de UI: a aba continua escondida por `sou_staff_mimba()` **de produção** (conveniência). A
barreira real é a RLS do projeto analítico. Nunca depender do gate de UI para autorização.

## Consequências

- (+) **O incidente fica impossível por construção.** A carga analítica não tem como consumir CPU
  de produção: não está lá, e nenhuma requisição de cabanha chega até ela.
- (+) O caminho de leitura do app fica **mais rápido** do que era com RPC — depois dos 530 KB
  iniciais, consultar um animal ou um reprodutor é lookup em memória, sem rede — e com
  disponibilidade igual à do próprio app (mesmo CDN: se o artefato cai, o `index.html` já caiu
  junto).
- (+) Custo marginal ≈ **R$ 0**. Nenhuma infra nova para operar, nenhum provedor novo para aprender.
- (+) Esforço de migração baixo: as migrations existentes rodam quase como estão; o trabalho novo é
  o exportador de shards (~150 linhas de Node) e o `_ref()` no front (~30 linhas).
- (+) O artefato é um contrato versionado e auditável. Dá para diffar entre temporadas e para
  reproduzir do zero a partir do `extrair.mjs`.
- (−) **O dado da ABCCC passa a ser publicamente acessível por URL**, sem login. Hoje as RPCs
  `ref_*` exigem usuário autenticado — mas o próprio handoff (seção 8b) já reconhece que enumerar a
  base em loop era trivial, e a fonte é um relatório *publish-to-web* sem autenticação nenhuma.
  Ainda assim, mirrorar o dataset de uma associação parceira num CDN público é diferente de
  consultá-lo; é uma conversa de relacionamento, não técnica. **Escape hatch definido**: se
  incomodar, os mesmos shards vão para um bucket privado no Storage **de produção** com leitura só
  para `authenticated` — muda só a URL dentro de `_ref()`, e a leitura de um objeto de 16 KB via
  Storage não tem relação com o padrão de escrita que causou o incidente.
- (−) **Dois logins para o staff**, e sincronização manual de 2 linhas de `mimba_staff` entre os
  projetos. Aceito conscientemente pelo raio de explosão (ver acima). Revisitar se a equipe passar
  de ~5 pessoas.
- (−) **O app fica com dado da temporada anterior até alguém publicar o artefato.** Para dado de
  resultado de exposição — que só muda quando um ciclo fecha — isso é irrelevante. Seria
  inaceitável para qualquer dado transacional; por isso o artefato é **só** para a base de
  referência da ABCCC, nunca para dado de tenant.
- (−) A publicação é **manual**. Consciente: 1× por temporada não justifica um pipeline.
- (−) 530 KB entram na sessão do cliente na primeira consulta de referência (~1,9 MB de objetos em
  memória depois do parse). Irrelevante em desktop, aceitável em celular; se um dia doer, fatia-se
  o resumo pelo mesmo hash do detalhe.
- (−) Existe agora um segundo lugar onde SQL mora. Regra: `docs/migrations/` continua sendo a fonte
  única; migrations do projeto analítico ganham prefixo `dados-` no nome do arquivo. A skill
  `nova-migration-tenant` **não se aplica** a elas — não há schema `cab_*` no projeto analítico.

## Alternativas consideradas

**A. Só o segundo projeto Supabase free, com o app consultando ele** — *rejeitada como solução
completa; aceita como metade da solução.*
Resolve a CPU, não resolve a disponibilidade. O plano free **pausa o projeto por inatividade**
(~1 semana sem requisição) e a volta é manual, pelo dashboard, com alguns minutos de espera. Uma
base consultada uma vez por semana por 2 pessoas vive na fronteira do pause. E o dia em que a ficha
de um animal chamar `ref_abccc_animal` contra um projeto pausado, o cliente vê erro por causa de
uma feature interna nossa. Dá para contornar com um ping de keep-alive por cron — mas aí a
disponibilidade das cabanhas passa a depender de um cronjob que ninguém monitora. **Isso é
eliminatório para o caminho do app e irrelevante para o caminho do staff** — que é exatamente por
que a decisão separa os dois. Nota de faturamento a conferir: o free tem limite de projetos ativos
por organização; se não couber, um compute Micro na org paga custa ~US$ 10/mês, o que continua
aceitável.

**B. Só artefato estático + DuckDB-WASM** — *rejeitada por deixar a ingestão e a exploração sem
casa; a metade da leitura foi aproveitada.*
Para o caminho do app é perfeito — e a medição confirma que a objeção do "baixar MBs para um lookup
pontual" não se sustenta: são 530 KB para **todo** o contrato, cacheados. O que não cabe é o resto.
(a) **Escrita:** "subir um CSV pela tela" viraria "rodar um script e dar git push" — só o Pedro
consegue, e joga fora a UI de carga já construída. (b) **Exploração:** ranking por dimensão
arbitrária, filtro de ciclo, busca livre é consulta ad-hoc de verdade e não sai de um artefato
agregado — precisaria do Parquet completo mais DuckDB-WASM no browser, ou seja, vários MB de WASM
para responder o que um Postgres que já temos responde de graça, e ainda sem resolver (a).
Consequência prática desta rejeição: **o artefato é JSON, não Parquet.** JSON é `fetch` +
`JSON.parse`, zero dependência; Parquet só se paga se houver DuckDB do outro lado. Se um dia o staff
quiser SQL ad-hoc no browser, gerar um Parquet adicional a partir do mesmo exportador é barato — mas
seria um segundo artefato, não a troca deste.

**C. Postgres em outro provedor (Neon free com scale-to-zero, similares)** — *rejeitada.*
Scale-to-zero é melhor que pause (volta sozinho, em ~centenas de ms). Mas Neon entrega Postgres
**puro**: sem PostgREST, sem Auth, sem Storage. Toda a Área de Dados — 13 RPCs chamadas por HTTP,
RLS por `sou_staff_mimba()`, bucket de arquivos originais, upload pela tela — teria que ser
reescrita contra uma camada HTTP que não existe, num frontend que não pode ter bundler. É trocar
"esforço baixo, tecnologia conhecida" por "esforço alto, terceiro provedor para operar", para
resolver um problema (pause) que a arquitetura escolhida já eliminou de outro jeito.

**D. Supabase pago com compute pequeno só para a analítica** — *não rejeitada, adiada.*
É a versão sem asteriscos da opção A: sem pause, sem keep-alive, ~US$ 10/mês de compute além dos
US$ 25 da org. Se em algum momento a analítica precisar rodar cargas pesadas ou o staff crescer,
**subir esse projeto de free para pago é a evolução natural desta decisão e não muda mais nada** —
o app não fala com ele nem hoje nem depois. Hoje não se paga porque não há dor: 84k linhas e 2
usuários cabem folgado no free. Registro à parte, fora do escopo deste ADR: **produção precisa sair
do free**, e isso é urgente independentemente da Área de Dados — o incidente aconteceu num plano
sem CPU garantida, atendendo clientes pagantes.

**E. Híbrido** — *escolhida.* Ver "Decisão".

**F. Artefato servido do Storage do projeto analítico (bucket público)** — *rejeitada.*
Parece equivalente ao Pages e é mais cômodo (a mesma tela que carrega publica). Mas um projeto
Supabase pausado não serve Storage. Reintroduziria exatamente a dependência que o artefato existe
para eliminar, de forma sutil o bastante para ninguém perceber até o dia da falha.

## Gatilhos de revisão

Rediscutir esta decisão (com novo ADR) se:
- a ABCCC se manifestar sobre o artefato público, ou entrar no artefato qualquer dado que **não**
  seja público na fonte → migrar para o escape hatch (bucket privado em produção);
- a base de referência passar a mudar mais de ~1×/mês → a publicação manual deixa de servir;
- entrar na Área de Dados algo que exija join com dado de tenant → o artefato estático deixa de
  ser aplicável por definição, e a decisão inteira precisa ser refeita **com o
  `revisor-isolamento`**;
- a equipe passar de ~5 pessoas → o login duplicado e o `mimba_staff` manual viram atrito real.

## Recomendação, sem menu

**Faça o híbrido (E), nesta ordem:**

1. Criar o segundo projeto Supabase (free, org separada), recriar `mimba_staff` +
   `sou_staff_mimba()` lá, e reaplicar as migrations `2026-08-19-area-dados-fase1..3b.sql` com as
   três correções de carga. É onde a equipe explora e sobe arquivo. **Ele nunca é chamado pelo app.**
2. Gerar `ref/abccc/resumo.json` (530 KB gz) + `ref/abccc/detalhe/NN.json` a partir dele, commitar
   no repo do app e trocar as chamadas `_rpc('ref_abccc_*')` por `_ref()`. É assim que as cabanhas
   leem o dado da ABCCC, agora e depois.
3. Tirar a **produção** do plano free. Não é parte deste ADR, é a lição dele.

**O que estamos deliberadamente sacrificando:**

- **O dado da ABCCC deixa de estar atrás de um login e passa a estar atrás de uma URL pública.**
  É o preço direto do isolamento total. Aceitável porque a fonte já é um relatório publish-to-web
  sem autenticação, e há escape hatch definido se a ABCCC pensar diferente.
- **Dois logins e duas listas de staff para manter na mão.** Escolhido em cima de compartilhar o
  JWT secret, que seria mais cômodo e reabriria o raio de explosão comum entre produção e o
  analítico.
- **O app passa a ler um retrato, não o banco.** A ficha do animal mostra o que foi publicado na
  última geração do artefato, não o que está no analítico neste segundo. Vale só porque o dado é de
  referência e muda 1× por temporada — e é exatamente por isso que **nenhum dado de tenant pode
  jamais entrar nesse artefato**.
- **Simplicidade de deploy em troca de um passo manual por temporada.** Não haverá pipeline de
  publicação enquanto a frequência for anual.

O que **não** está sendo sacrificado, e é o ponto inteiro da decisão: a partir daqui, nada que a
Área de Dados faça — carga errada, matview travada, projeto pausado, projeto deletado — consegue
tocar as cabanhas pagantes.
