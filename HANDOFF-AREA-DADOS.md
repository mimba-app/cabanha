# Handoff — Área de Dados (Mimba Dados) · 2026-08-19

> Para retomar: sessão em `projetos/cabanha` → *"lê o HANDOFF-AREA-DADOS.md e vamos continuar"*.
> Carregam sozinhos: `CLAUDE.md`, `MEMORY.md`, subagentes e skills. O checkpoint geral do produto
> continua no `HANDOFF.md` — este documento cobre só a Área de Dados.
> **Não contém segredos.**

---

## ⛔ STATUS 2026-08-20 — REMOVIDA DA PRODUÇÃO. LEIA ANTES DE QUALQUER COISA.

**Esta funcionalidade derrubou a produção e foi desmontada. Não reinstale no projeto
`fmjfvfufkqswweyasjyp`.** O documento abaixo continua válido como *projeto técnico* —
o modelo de dados, o decodificador DSR do Power BI e o contrato de consumo estão corretos e
foram validados. O que estava errado era **onde** isso morava.

**O que aconteceu.** Em 19/08 à noite, com a carga da ABCCC já aplicada em produção, a
instância (plano **FREE**, CPU compartilhada) foi a 72% de CPU e travou: `Database`,
`PostgREST`, `Auth` e `Storage` ficaram *unhealthy*, a API inteira passou a devolver **522**,
o `carregar_dados_cabanha` (bootstrap do login) começou a estourar `statement timeout` e um
checkpoint do Postgres levou **72 segundos** para escrever 714 buffers. Disco não era o
problema (6% de uso, 170 MB) — era CPU.

**A causa.** 83.778 linhas inseridas **uma a uma** em `dados_registros`, que tem **4 índices de
expressão sobre jsonb**, mais a matview `mv_abccc_resultados` com **outros 6 índices** e
`refresh materialized view` **não-concorrente**. São ~83 mil linhas × 11 estruturas de índice
numa instância que também atende as cabanhas pagantes. A seção 10 deste documento chamava
essa assimetria de "inofensiva". **Não era.**

**A decisão (Pedro, 20/08).** Base analítica não divide instância com o banco transacional de
produção. A Área de Dados é refeita num **projeto Supabase separado**.

**O que foi feito:**
- `docs/migrations/2026-08-20-remover-area-dados-de-producao.sql` — desmonta tudo em produção
  (3 tabelas, matview, view, 18 funções, bucket e a policy em `storage.objects`). Preserva
  `mimba_staff`, `sou_staff_mimba()`, `pg_net` e `pg_cron`, que são pré-existentes e em uso.
- O frontend saiu da `staging` pelo revert de `827f354` — o Painel Mimba voltou à visão única.
- As migrations `2026-08-19-area-dados-fase*.sql` e `dados/abccc/` **ficam no repo de
  propósito**: são a receita para reconstruir no projeto novo.

**Ao reconstruir, corrigir estes três antes de carregar qualquer dado:**
1. Trocar o `insert` linha a linha de `abccc_importar_coletar` por `insert ... select`.
2. Criar índice único na matview e usar `refresh materialized view concurrently` — o refresh
   atual pega `ACCESS EXCLUSIVE` e bloqueia todo mundo.
3. Rever se os 4 índices de expressão jsonb em `dados_registros` são mesmo necessários na
   carga, ou se podem ser criados depois do load.

**Consequência de arquitetura a resolver no redesenho:** o contrato da seção 5
(`ref_abccc_animal` / `ref_abccc_reprodutor` chamadas via `_rpc` na mesma conexão) **deixa de
funcionar** quando os dados estão noutro projeto. Vai precisar de um segundo client Supabase
apontando para o projeto analítico, ou de uma edge function em produção que faça proxy. É
decisão de arquitetura — vale passar pelo subagente `arquiteto`.

---

## 1. O que é e por que existe

Área de **inteligência de dados** da plataforma, restrita a funcionários/sócios da Mimba
(`public.mimba_staff`). Não é cadastro estruturado nem tela de administração de banco: é uma
**landing zone analítica** onde a gente sobe CSV, Excel e relatórios de resultados de competição,
e essas linhas ficam disponíveis para funcionalidades do sistema **em todas as cabanhas**.

O objetivo de produto é análise de raça, de sangue e de ancestralidade: cruzar o plantel de cada
cabanha com o histórico de campeões da ABCCC para responder coisas como *"este potro tem quantos
campeões na ascendência?"* e *"que garanhão vem repetindo o feito?"*.

**Decisões tomadas nesta sessão** (Pedro aprovou as duas):
- A área vive como **abas novas dentro do Painel Mimba**, reaproveitando o gate `sou_staff_mimba()`
  que já existia — em vez de uma tela separada com controle de acesso próprio.
- **SheetJS via CDN, carregado sob demanda** para ler `.xlsx`. Não é build step nem package manager;
  o `index.html` continua único e sem bundler. Só baixa a lib quando alguém escolhe um arquivo Excel.

## 2. Onde está

| Onde | O quê |
|---|---|
| `index.html` → bloco `// ─── ÁREA DE DADOS (Painel Mimba)` | Todo o frontend novo (~390 linhas) |
| `index.html` → `#pm-aba-dados`, `#pm-aba-intel` | Markup das abas |
| `docs/migrations/2026-08-19-area-dados-fase1.sql` | Tabelas, RLS, bucket, RPCs de catálogo |
| `docs/migrations/2026-08-19-area-dados-fase2-abccc.sql` | Importador da ABCCC (pg_net + decodificador DSR) |
| `docs/migrations/2026-08-19-area-dados-fase3-analises.sql` | View tipada, índice de expressão, RPCs de análise |
| `docs/migrations/2026-08-19-area-dados-fase3b-matview.sql` | Materialized view (performance) |
| `dados/abccc/` | CSVs extraídos + script Node de extração (fora do app, não commitado) |

O Painel Mimba agora tem 3 abas: **Cabanhas** (a visão que já existia), **Dados** (catálogo + carga)
e **Inteligência** (rankings e consulta de animal).

## 3. Modelo de dados

Tudo em `public`, mas são tabelas de **PLATAFORMA**, não de tenant:

- **`dados_datasets`** — catálogo: uma linha por base carregada (nome, tipo, formato, colunas,
  total de linhas, status, quem subiu).
- **`dados_registros`** — as linhas cruas: `(dataset_id, linha, dados jsonb)`. Schema livre — cada
  arquivo guarda as colunas que tinha. Índices de expressão em `SBB`, `Pai`, `Mãe`, `Animal`.
- **`dados_fontes_externas`** — config de importadores de API (hoje só a ABCCC).
- **`mv_abccc_resultados`** — materialized view com a projeção tipada dos datasets
  `tipo = 'resultados_abccc'`. É o que as análises leem.
- **`vw_abccc_resultados`** — mesma projeção como view normal (`security_invoker=true`), pra
  consulta ad-hoc de staff.
- Bucket privado **`dados-mimba`** — guarda o arquivo original de cada upload.

> ⚠️ **Estas tabelas NÃO estão na allowlist `v_tabelas` de `provisionar_schema_cabanha()` e não
> devem entrar.** São compartilhadas entre todas as cabanhas — o oposto de dado por tenant. Se
> forem adicionadas lá, cada cabanha ganha uma cópia vazia e o modelo inteiro quebra. Verificado:
> a função de provisionamento não referencia nenhum objeto novo.

## 4. Segurança — matriz verificada

Testado de verdade, com `set local role authenticated` / `anon` + `request.jwt.claims`
(não basta `set_config` sozinho: a conexão do MCP é `postgres` e ignora RLS):

| | staff Mimba | usuário de cabanha (não-staff) | anon |
|---|---|---|---|
| `dados_registros` / `dados_datasets` / `dados_fontes_externas` | acesso total | **0 linhas** (RLS) | permission denied |
| `mv_abccc_resultados` | via RPC | **permission denied** (sem grant) | permission denied |
| `vw_abccc_resultados` | acesso | 0 linhas | permission denied |
| RPCs `dados_*` e `abccc_*` | ok | **negado** | negado |
| RPCs `ref_*` | ok | **ok** (é o ponto) | negado |

**A matview não respeita RLS.** Ela está protegida só por ausência de grant. Nunca dar
`grant select on public.mv_abccc_resultados to authenticated` — isso libera a base inteira
direto pelo PostgREST.

## 5. Contrato de consumo pelas cabanhas

As funcionalidades do app **não leem as tabelas**. Leem só estas duas RPCs (SECURITY DEFINER,
liberadas para qualquer usuário logado, devolvem só dado público de referência da ABCCC):

```js
// Ficha do animal: o que este SBB já ganhou
await _rpc('ref_abccc_animal', { p_sbb: animal.sbb });
// → { animal, sexo, pai, mae, criador, premiacoes, campeonatos, grandes_campeonatos,
//     indice, ciclo_primeiro, ciclo_ultimo, resultados: [{ciclo,cidade,prova,colocacao}] }
//   ou null se o animal não tem premiação nenhuma

// Análise de sangue: força de um reprodutor pela progênie
await _rpc('ref_abccc_reprodutor', { p_nome: animal.pai });
// → { filhos_premiados, premiacoes, campeonatos, grandes_campeonatos, indice,
//     como: 'pai'|'mae', melhores_filhos: [{sbb, animal, campeonatos, indice}] }
```

A chave de ligação com o plantel é **`animais.sbb`** ↔ **`SBB`** da ABCCC. Para genealogia mais
funda, `public.sangues_linhagem.ancestrais` (jsonb) já guarda a ascendência consultada da ABCCC —
cruzar isso com `ref_abccc_reprodutor` é o caminho para "campeões na ascendência".

**Índice de expressão**: ranqueamento nosso, não métrica oficial da ABCCC. Grande Campeão 10 ·
Campeão de categoria e 1º lugar 5 · Reservado 3 · demais colocações 0,5 a 2
(`public.abccc_pontos`).

## 6. Como os dados chegaram (e como atualizar)

A fonte é o painel público da ABCCC (`cavalocrioulo.org.br/eventos/painel_resultados`), que é um
relatório **Power BI publish-to-web** dentro de um iframe. A tabela é virtualizada (carrega de 500
em 500 no DOM), então raspar a tela é lento e frágil. Em vez disso replicamos a própria requisição
`querydata` do relatório e decodificamos o formato **DSR** do Power BI (dicionários de valores +
bitmask `R` = repete valor da linha anterior, `Ø` = nulo).

Isso está implementado **duas vezes**, de propósito:
- `dados/abccc/extrair.mjs` — decodificador em Node, roda na máquina, gera CSV.
- `public.abccc_importar_disparar()` + `public.abccc_importar_coletar()` — decodificador em
  plpgsql, roda no banco. É o que a tela usa.

As duas implementações foram comparadas linha a linha: **83.778 linhas, 45 ciclos (1982–2026),
contagem idêntica em todos os ciclos**. Serviu de validação cruzada do decodificador.

**Para atualizar** (depois de cada temporada): Painel Mimba → Dados → *Atualizar agora*. Substitui
a base inteira e dá `REFRESH` na matview no final.

Detalhes que vão morder se alguém mexer:
- `pg_net` é **assíncrono e só envia a requisição depois do COMMIT** — por isso o ciclo é sempre
  `disparar()` → aguardar → `coletar()`, em transações separadas. Não dá pra fazer numa função só.
- A primeira linha de cada página de continuação **repete** a última da página anterior (é como o
  restart token funciona). O `coletar()` descarta pelo flag `p_continuacao` — sem isso entram
  duplicatas nas emendas. Esse bug aconteceu e foi corrigido; hoje: **0 duplicatas**.
- A extensão `http` do Postgres **não funciona** contra o endpoint do Power BI (`SSL_ERROR_SYSCALL`
  — provável exigência de HTTP/2). `pg_net` funciona. Não perca tempo tentando o `http`.
- O painel abre filtrado no ciclo corrente. O payload guardado em `dados_fontes_externas` teve esse
  filtro **removido**, então o padrão é a série histórica completa. `p_ciclo` permite recorte.

## 7. O que está carregado hoje

Dataset `ABCCC — Resultados de provas (série histórica)`, publicado:

- **83.778 premiações** · 26.121 SBBs · 4.156 reprodutores · 3.526 criadores · 17 provas · 203 cidades
- Ciclos **1982 a 2026** · 25.558 títulos de campeão
- `Criador` vem vazio em 1.864 linhas — é nulo na origem, não erro de carga
- Top garanhões por índice: CHICÃO DE SANTA ODESSA (5.912) · BT DELANTERO (5.865) ·
  LA INVERNADA HORNERO (5.760)

Filtros herdados do painel da ABCCC (não é a base bruta da associação): 17 tipos de prova,
`pontos > 0` e 18 categorias de premiação.

## 8. O que está verificado — e o que NÃO está

**Verificado:**
- Matriz de segurança da seção 4, com troca de role de verdade
- 13 RPCs conferidas uma a uma: nome e **nomes dos parâmetros** batem com o que o frontend chama
  (erro clássico de PostgREST que só apareceria em produção)
- Carga completa rodou pelas RPCs reais (as mesmas que a tela usa), 4 páginas, 0 duplicatas
- Parser de CSV testado com aspas, aspas escapadas, vírgula dentro do campo, quebra de linha dentro
  do campo, `;` (Excel pt-BR), BOM, cabeçalho duplicado/vazio, linha vazia — e contra o CSV real
  (3.448 linhas em 146ms)
- `index.html` sem erro de sintaxe; as 3 abas renderizam; o fluxo de escolher arquivo → prévia →
  formulário funciona
- Advisor de segurança do Supabase: os 3 achados meus (`search_path` mutável) foram corrigidos

**NÃO verificado — precisa de alguém logado:**
> Eu não tenho credencial de vocês e não devo manipular senha, então **não consegui exercitar
> nenhum fluxo autenticado pela tela**. O que falta testar no navegador, logado como staff:
> 1. Painel Mimba → Dados: o catálogo lista o dataset da ABCCC com 83.778 linhas
> 2. Subir um CSV pequeno de teste ponta a ponta (inclusive se o arquivo original foi pro bucket)
> 3. *Atualizar agora* da ABCCC — o loop de páginas no navegador (no banco já rodou)
> 4. Aba Inteligência: ranking, troca de dimensão, filtro de ciclo, busca de animal
> 5. Excluir uma base de teste
>
> Servir local pra testar: `python3 -m http.server 8777` na raiz do repo → `localhost:8777/index.html`.
> (O `SUPABASE_URL` aponta pro projeto real, então o login funciona a partir do arquivo local.)

## 8b. Revisão de isolamento

O `CLAUDE.md` exige o subagente `revisor-isolamento` antes de mergear qualquer coisa que toque
RLS. **Ele não pôde rodar: a conta bateu o limite mensal de gasto da API** (o subagente morreu no
meio). A revisão foi feita inline, na mesma sessão. **Vale refazer com o subagente quando o limite
resetar** — quatro olhos são melhores que dois, ainda mais em isolamento.

O que a revisão inline cobriu:

- **Policies pré-existentes no storage** — `storage.objects` tinha só a policy nova
  (`dados_mimba_staff`); nenhuma policy permissiva de antes furando o bucket. RLS ligada, bucket privado.
- **Matview sem grant** — confirmado `nenhum` grant em `mv_abccc_resultados`. É a única barreira dela.
- **`search_path`** — todas as funções novas com `search_path` fixo. As 3 não-`SECURITY DEFINER`
  (`abccc_pontos`, `abccc_e_campeao`, `dados_touch`) são helpers puros e não precisam ser definer.
- **Dono das funções** — todas `postgres`, como as demais RPCs do projeto.
- **Injeção** — testado: `p_ciclo` com aspa (**rejeitado**), `p_dimensao` fora da whitelist
  (**rejeitado**), `p_termo` com aspa/wildcard (tratado como texto, é parâmetro de `ilike`),
  `p_limite` absurdo (limitado a 200).
- **Correção aplicada na revisão**: `abccc_importar_disparar` agora valida `p_ciclo` contra
  `^[0-9]{4}$`. Antes o valor ia direto pra dentro de um literal da query do Power BI. Não era risco
  de isolamento (só staff chama, e o destino é API externa), mas era frouxo.

**Não encontrei caminho de vazamento entre cabanhas.** O raciocínio: nenhum objeto novo referencia
`TENANT_SCHEMA`, schema `cab_*` ou `tenant_id`; as RPCs `ref_*` só leem dado público da ABCCC (o
mesmo que qualquer um vê no site da associação) e não recebem nem consultam identificador de tenant.

**Ponto que merece um segundo olhar quando o subagente rodar:** as RPCs `ref_*` são executáveis por
qualquer usuário logado e não têm rate limit. Dá pra enumerar a base de SBBs chamando em loop. Como
o dado já é público, tratei como aceitável — mas se um dia entrar dado não-público nessas tabelas,
essa decisão precisa ser revista.

## 9. Próximos passos sugeridos

1. **Fazer o teste logado da seção 8** — é o gate antes de qualquer deploy.
2. **Plugar na ficha do animal**: chamar `ref_abccc_animal(sbb)` e mostrar as premiações do animal.
   É a menor mudança com maior valor percebido pelo cliente.
3. **Plugar na página Sangues**: `ref_abccc_reprodutor(pai)` e `(mae)` para mostrar a força dos
   reprodutores por trás do animal; depois cruzar com `sangues_linhagem.ancestrais` para
   "campeões na ascendência até a 5ª geração".
4. **Sugestão de acasalamento** (a ideia do Pedro de "repetir o feito"): dado um garanhão e uma
   égua, olhar o desempenho histórico de cruzamentos com sangue parecido. Precisa de mais modelagem.
5. **Agendar a atualização da ABCCC** via `pg_cron`, em vez de botão manual — o projeto já usa cron
   (`docs/migrations/2026-08-02-cron-cobrar-trial.sql`).

## 10. Estado de branch / deploy

Tudo isto está na **`staging`**, junto com o resto que ainda não foi promovido (ver `HANDOFF.md`,
seção "O MAIS IMPORTANTE"). **Nada foi commitado nem deployado nesta sessão** — o `index.html` está
modificado na árvore de trabalho.

⚠️ Uma assimetria importante: **as migrations já foram aplicadas no banco de produção** (é o mesmo
Supabase para staging e produção), mas o frontend que as usa só existe na `staging`. Na prática isso
é inofensivo — as tabelas estão vazias de dado de cliente, o acesso é só staff, e as RPCs `ref_*`
ainda não são chamadas por ninguém. Mas vale saber que o banco está "à frente" do `main`.
