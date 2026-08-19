# Spec — Reprodutivo v4 + Saúde & Vacinas (revisão pós-reunião com o sócio)

> **Status: ✅ TODAS AS 8 FASES + FASE 8b APLICADAS, MIGRATIONS RODADAS, PROMOVIDO PRA `main` (2026-08-13).**
> Revisada por Pedro, Thiago e Luciano em 2026-08-12, fechada com plano de fases no mesmo dia, e
> implementada inteira (Fase 0 → 8) em 2026-08-13. QA visual real (browser + sessão injetada) feita
> depois da Fase 8, e `staging` promovida pra `main` (PR #2, merge `fb578da`) no mesmo dia. Fase 8b
> (correção de layout + remoção do flag "Receptora" do cadastro) é retrabalho pontual pós-promoção,
> ainda só em `staging`. Detalhe de cada fase, achados e decisões de design ficam registrados nas
> seções de cada uma, abaixo.

## Contexto

Reprodutivo v3 unificou as telas antigas "Reprodutivo" e "Gestação" numa só, organizada por Ciclo
Reprodutivo. Na prática de uso, sócio e dono identificaram que a ordem das abas, alguns conceitos (fonte de
cobertura, "marcar como reprodutora") e a divisão de trabalho entre criador e veterinário não refletem como
o fluxo acontece de verdade na cabanha. Esta revisão trata disso, e também estende Saúde & Vacinas com o
funil de acompanhamento reprodutivo do veterinário (hoje esse acompanhamento não existe como fluxo — só
"Protocolos", que fica pra depois da confirmação de prenhez).

---

## 1. Menu Animais

- **Importação em lote por SBB** — colar uma lista de códigos SBB, ou subir arquivo `.txt`/`.csv`. Também
  cogitada (❓ ainda especulativo, avaliar se a API/portal da ABCCC permite) a possibilidade de puxar a
  lista completa de SBB de um proprietário direto de lá, sem digitar um por um.
- **Foto do animal** no cadastro, visível como coluna/miniatura na listagem.
- **Repensar a visualização da lista** — hoje é uma tabela densa. Ideia: layout tipo grid/swimlane
  (parecido com o antigo "Gestão"), menos "cara de planilha", com mais detalhe visível por card/linha sem
  precisar abrir a ficha.

## 2. Animais × Reprodutivo (cadastro)

- **Campo "castrado"** no cadastro de machos. Quando marcado, o animal:
  - **some** das telas de Plantel disponível (seção 3.2) e de qualquer tela de uso em ciclos/planejamentos
    novos (não aparece como opção pra selecionar);
  - **permanece visível** em históricos passados — coberturas/acasalamentos já registrados antes da
    castração não somem nem ficam órfãos.

## 3. Reprodutivo — reordenação e reestruturação das abas

### 3.1 Ordem lógica correta (inverte a prioridade atual)

A visão do criador deve abrir sempre no que **já está em andamento**, não no planejamento futuro — é o que
"encanta" o cliente (ver o que vai nascer). Reordenar as abas do Reprodutivo assim:

1. **Gestações ativas do ciclo corrente** — primeira coisa que o criador vê ao entrar. Hoje (2026), seria
   o ciclo **25/26**, que é o que está correndo. O estilo de card com barra de progresso e data de parto que
   já existe hoje na aba "Legado" (prints da reunião) é a referência visual pra essa aba — só que com dados
   do fluxo novo (ciclo atual), não do legado.
2. **Planejador de ciclo / acasalamentos do próximo ciclo** (ex.: 26/27) — enquanto o planejamento é só do
   dono, ele testa livremente qualquer combinação de garanhão × égua/embrião, até decidir que está pronto e
   **"fechar"** o planejamento, liberando-o pro funil do veterinário (seção 4).
3. **Acasalamentos / funil enviado ao veterinário** — acompanhamento do que já foi liberado, desde a
   confirmação de envio até a confirmação de gestação/cria.

**Regra de bloqueio — revisada em 2026-08-12:** a versão original desta spec bloqueava o criador de
fechar/enviar o planejamento do próximo ciclo enquanto houvesse gestação ativa sem cria informada. **Essa
regra foi revista e invertida**: o criador **pode** fechar o ciclo e enviar pro funil do veterinário
normalmente, mesmo com gestações ainda ativas em aberto. O bloqueio acontece **do lado do veterinário**: no
Kanban de Saúde & Vacinas (seção 4), a égua com gestação ativa aparece na coluna **Controle** já sinalizada
como **bloqueada** — visível, mas **sem poder ser movida** pro próximo estágio do funil até a gestação
daquela égua ser encerrada (cria nascida ou perdida). Ver seção 4.1.

**"Apelo gráfico" (resolvido):** é só o estilo visual do card/linha de cada gestação na aba 1 (mesma
referência da tela "Legado" já mencionada acima) — não é uma tela ou dashboard separado.

### 3.2 Aba "Plantel disponível" — resolvido: aba própria, por ciclo

Fica como **aba separada** (não funde com o Planejador). Lista tudo disponível pra uso **naquele ciclo**:
garanhões, éguas de cria, cotas de cobertura, embriões, receptoras (seção 3.5) etc. — sempre escopado ao
ciclo selecionado, do mesmo jeito que o Planejador já é por ciclo hoje.

### 3.3 Fontes de Cobertura → renomeada para "Garanhões e Coberturas" e reestruturada

- **Falta um tipo de fonte**: hoje só existe Próprio / Cota / Direito de uso — falta **"Cobertura"** como
  tipo (cobertura comprada avulsa, sem ser cota nem direito de uso recorrente). Também falta **"Embrião"**
  (próprio ou comprado de outra cabanha) — ver detalhamento completo na seção 3.5 (Receptoras).
- **Renomear** o conceito/aba "Fontes de Cobertura" para **"Garanhões e Coberturas"** (nome confirmado).
- **Fluxo quando a fonte é "Próprio"** — hoje abre o mesmo modal genérico de "Nova fonte", pedindo pra
  definir quantidade manualmente a cada ciclo, um garanhão por vez. Trocar por:
  - Uma **quantidade máxima padrão**, configurada **no cadastro do animal** (aba Animais), sugerida com
    **120** de valor inicial (limite regulatório ABCCC de coberturas/ano por garanhão — 240 se registrado
    como Demérito, já considerado na v3).
  - Essa quantidade padrão pode ser editada tanto no cadastro do animal (muda o padrão pra sempre) quanto
    **dentro de um ciclo específico** — mas só pra **diminuir** (ex.: vendeu cotas a terceiros, ou decidiu
    não usar o garanhão inteiro naquele ciclo).
  - Renomear o campo hoje chamado "quantidade adquirida" pra **"quantidade disponível"**.
- **Fluxo quando a fonte é Cobertura / Direito de uso / Cota** — continua exigindo informar a quantidade
  manualmente (isso não muda), mas esse cadastro deve acontecer **sempre dentro do ciclo do planejador**,
  não como um cadastro solto fora do contexto de ciclo (como é hoje, aparentemente).

### 3.4 Remover "Marcar como reprodutora"

- Considerado **incorreto e desnecessário**. Uma égua já em estágio "Cria" no cadastro de Animais deve
  estar automaticamente elegível pro planejamento do ciclo — não precisa de um toggle extra pra habilitar.
- Fluxo do "Acasalar" simplificado: selecionar garanhão + égua → gerar acasalamento. O sistema valida saldo
  de cotas/coberturas disponíveis no momento da criação (não antes).
- Éguas com **gestação ativa** também devem poder entrar no planejamento do **próximo** ciclo normalmente.
  E podem ser reaproveitadas até no **mesmo** ciclo, desde que a gestação atual já tenha sido encerrada
  (cria nascida ou gestação perdida — ver regra de corte na seção 4.3).

### 3.5 Receptoras (transferência de embrião) — detalhado pelo Luciano

Duas situações distintas, ambas envolvendo **transferência de embrião (TE)**:

1. **Embrião — próprio ou comprado**, implantado numa égua do próprio plantel (que atua como receptora).
   O embrião pode ser de uma égua da própria cabanha, ou **adquirido de outra cabanha** — mesma lógica
   comercial já usada pra comprar cobertura de um garanhão (ver seção 3.3: seria mais um tipo de "fonte",
   ao lado de Próprio/Cota/Direito de uso/Cobertura).
2. **Receptora emprestada/alugada** — uma égua que **não é do plantel**, obtida especificamente pra
   receber o embrião naquele ciclo. Depois do período de campo e desmame do potro, a cabanha normalmente
   **inativa** essa receptora (ela deixa de ser usada, mas o registro histórico permanece).

**Requisito obrigatório**: pra poder receber um embrião, a receptora — própria ou emprestada — **precisa
ter SBB válido na ABCCC**. No cadastro, ela deve ficar **claramente identificada como receptora** (campo/
flag estruturado, não texto livre em Observações como acontece hoje).

**Regra de parentesco (importante, afeta o registro do produto)**: o potro nascido de uma TE é sempre
registrado tendo como **mãe a doadora do embrião** (a "produtora" genética) — **nunca a receptora**. A
receptora não entra como mãe em nenhum registro de descendência.

**Como aparece no acompanhamento de gestações ativas**: a gestação é sempre exibida vinculada à **dona do
embrião** (a doadora), com uma sinalização adicional de qual receptora está gestando fisicamente. Exemplo
do formato esperado:

> Gestação **TURUMBAMBA CHARRUA** na receptora **NEVADA DE SANTA ENOEMA (B565012)** — TE (Transferência de
> Embrião)

Ou seja: card/linha da gestação nomeia a doadora (é o animal que "está prenha" do ponto de vista do
plantel/produção), com um sub-rótulo indicando a receptora física e o SBB dela.

### 3.6 Bug confirmado (não é mudança de escopo, é correção)

- No modal "Adicionar égua" do planejador, os campos **não são limpos** depois de salvar — ao tentar
  cadastrar a próxima égua em seguida, os dados da anterior continuam preenchidos no formulário.

---

## 4. Saúde & Vacinas — nova aba "Reprodutivo" (funil do veterinário, em Kanban)

O acompanhamento reprodutivo do lado do veterinário deixa de ser uma aba solta dentro do menu Reprodutivo
do criador e vira um **Kanban de estágios**, dentro de **Saúde & Vacinas**. É o "funil" pro qual o criador
libera o planejamento fechado (seção 3.1).

### 4.1 Estágios do Kanban

1. **Controle** — a égua liberada pelo planejamento do criador entra aqui primeiro. O veterinário faz toque,
   avalia cio etc., e é **aqui** que se define o **tipo de acasalamento** que vai acontecer (IA — inseminação
   artificial, monta natural, TE — transferência de embrião etc.). Esse campo hoje aparece (de forma
   incorreta, segundo a reunião) na aba "Acasalamentos" do menu Reprodutivo do criador — precisa migrar
   pra cá, pro momento em que o veterinário realmente decide isso.
   - **Cards bloqueados (regra revisada, seção 3.1)**: como o criador agora pode enviar o ciclo pro funil
     mesmo com gestações do ciclo atual ainda ativas, essas éguas aparecem aqui na coluna Controle já
     **sinalizadas como bloqueadas** (indicação visual clara, ex.: cadeado/badge) — visíveis, mas **sem
     poder ser movidas** pro estágio 2 até a gestação em curso daquela égua ser encerrada (cria nascida ou
     perdida, seção 4.3).
2. **Inseminação/Cruzamento** — execução do método definido no estágio 1. Janela de acompanhamento de
   **~3 a 7 dias**; o sistema deve **alertar visualmente essa contagem** de forma clara. O veterinário
   sinaliza se a égua ovulou:
   - Ovulou → avança pro estágio 3.
   - Não ovulou → volta pro estágio 1 (Controle).
3. **Ovuladas** — acompanhamento até o **DG precoce** (diagnóstico gestacional), esperado entre o **dia 15
   e 20** após o cruzamento.
   - DG precoce positivo → avança pro estágio 4.
   - DG precoce negativo → volta pro estágio 1 (Controle).
4. **DG precoce confirmado, aguardando DG definitivo** — já há indício de gestação, mas o protocolo é
   esperar o **DG definitivo em ~45 dias** antes de considerar a gestação "ativa" de verdade. Ao confirmar o
   DG definitivo, a gestação passa a aparecer como **ativa** de volta na aba 1 do Reprodutivo do criador
   (seção 3.1).

### 4.2 Regras transversais do funil

- Em qualquer estágio, o veterinário pode **devolver a égua pro planejamento do criador** (ex.: decidiram
  em conversa que não vale insistir com aquele garanhão) — o criador reabre o planejamento pra escolher
  outra combinação.
- Durante todo o funil — do planejamento liberado até a confirmação de prenhez — o veterinário pode
  registrar **atividades soltas**: medicação, toque, ultrassom, comentários. É um histórico de evolução do
  acompanhamento daquele acasalamento específico.
- **Depois da confirmação de prenhez**: criar (automaticamente ou sob ação do veterinário) um **protocolo
  gestacional**, reaproveitando a funcionalidade "Protocolos" que já existe em Saúde & Vacinas hoje.
- **Última etapa do funil do veterinário**: uma visão de "Gestações ativas" equivalente à do criador (barra
  de progresso, data provável de parto), só que em formato **Kanban**, pra continuar registrando atividades
  durante a gestação (ultrassom, vacina, vitamina etc.).
- **A qualquer momento**, tanto criador quanto veterinário podem registrar que a égua **perdeu a cria** ou
  que a **cria nasceu**.

### 4.3 Regra de corte por perda de cria (30/06 → 01/07)

Se, depois de um DG positivo (gestação ativa), o veterinário registra que a égua **perdeu a cria**:

- **Perda antes de 30/06** — ainda dá tempo de tentar de novo no mesmo ciclo: a égua volta pro estágio
  **Controle** (4.1), e o veterinário pode, se quiser, devolvê-la direto pro planejamento do criador a
  partir daí.
- **Perda a partir de 01/07** — não dá mais tempo de fechar um novo acasalamento e confirmar gestação
  dentro do ciclo corrente: a égua fica disponível **só pro planejamento do próximo ciclo**.
- **Confirmado (2026-08-12): reaproveita a regra de corte de ciclo já existente** (`_calc_ciclo_texto`/
  `_cicloAtualTexto`, corte em `month >= 7`, Fase 0 do Reprodutivo v3) — não precisa de lógica de data nova,
  só reusar a mesma função de corte pra decidir se a perda cai antes ou depois da virada de ciclo.

## 5. Saúde & Vacinas — outras adições (fora do funil reprodutivo)

- **Nova categoria "Tratamentos"** — pra registrar que um animal se machucou, está em medicação X por um
  período determinado, etc. Hoje não existe um lugar pra isso (só Vacinação, Vermifugação, Exames).
- **Registro em lote pra Vacinas e Exames** — replicar o comportamento que já existe hoje só em
  Vermifugação (selecionar vários animais de uma vez e registrar a mesma vacina/exame pra todos).

---

## 6. Fora de escopo desta rodada (registrado pra não perder, não construir agora)

- Importação em lote de SBB puxando a lista completa direto do proprietário via ABCCC (seção 1) — depende
  de validar se a API/portal da ABCCC expõe isso; tratar como investigação separada antes de virar fase.

## 7. Dependências entre fases

- **Fase 0** (schema) é pré-requisito de tudo que precisa de coluna/tabela nova: Fases 1 (parte do
  `castrado`), 2, 4 e 5. Fases 3 e 6 não dependem de schema novo.
- **Fase 1 → 2 → 3** são sequenciais na mesma tela (Reprodutivo do criador), cada uma builda em cima da
  anterior.
- **Fase 4** (Kanban do veterinário) é a maior e mais arriscada — depende da Fase 0 (tabelas novas) e
  idealmente das Fases 1-3 prontas (o funil recebe o que sai do planejador reestruturado). Fazer por último
  entre as fases do Reprodutivo, mesmo já com schema pronto desde a Fase 0.
- **Fase 5** (Tratamentos + lote) e **Fase 6** (Menu Animais) são independentes entre si e do resto —
  podem rodar em paralelo a qualquer momento, inclusive antes da Fase 4.

## 8. Fases de implementação

### Fase 0 — Fundação de banco ✅ APLICADA EM PRODUÇÃO (2026-08-13)

Migration em `docs/migrations/2026-08-13-reprodutivo-v4-fase0.sql`. Aplicada via
`mcp__supabase__apply_migration` (o MCP não estava mais read-only pra writes, apesar do CLAUDE.md dizer
o contrário — confirmado com `select current_setting('transaction_read_only')` antes de aplicar).
Verificada ponta a ponta nos 7 tenants provisionados (colunas, tabelas, FKs, policies, grants).

- `animais`: novas colunas `castrado boolean not null default false`, `qtd_coberturas_padrao integer not
  null default 120` (padrão sugerido pra fonte "Próprio" por ciclo — não substitui o teto de 240 pra
  Demérito, já existente desde a Fase 0 do Reprodutivo v3) e `receptora boolean not null default false`.
- `fontes_cobertura.tipo`: CHECK ampliado de `proprio`/`cota`/`direito_uso` pra incluir `cobertura` e
  `embriao`.
- `acasalamentos`: nova coluna `receptora_animal_id uuid null references animais(id)`; `tipo_cobertura`
  virou nullable (deixa de ser preenchido pelo criador na criação — passa a ser decidido pelo veterinário
  no estágio Controle do Kanban, seção 4.1).
- **Resolvido o ❓ que estava em aberto**: `reproducao_estagios` referencia `acasalamentos`, não
  `gestacoes` — o funil do veterinário (Controle→Inseminação→Ovuladas→DG precoce) acontece todo **antes**
  de existir uma linha em `gestacoes` (que só nasce já confirmada, `data_confirmacao not null`).
  `acasalamentos` já tinha `status` (rascunho/simulado/aprovado/em_curso/confirmado/cancelado) e
  `tipo_cobertura` — o Kanban vive ao lado desses campos, não duplica.
- Nova tabela **`reproducao_estagios`**: 1:1 com `acasalamentos` (`acasalamento_id uuid unique`), campo
  `estagio` (controle/inseminacao/ovuladas/dg_precoce), `data_entrada_estagio` (base dos alertas de
  janela). **Sem coluna `bloqueado`** — decisão tomada na hora de escrever a migration: o bloqueio visual
  de éguas com gestação ativa (seção 3.1/4.1) é calculado em tempo de leitura (join com `gestacoes`
  abertas), não guardado como flag — evita o risco de ficar dessincronizado.
- Nova tabela **`reproducao_atividades`**: `acasalamento_id`, `tipo` (medicacao/toque/ultrassom/
  comentario), `data`, `obs`.
- Nova tabela **`tratamentos`**: `animal_id`, `data_inicio`, `data_fim`, `descricao`, `resp`, `obs`.
- **Achado no caminho**: `create table (like public.X including all)` não copia foreign keys entre
  schemas — a RPC `provisionar_schema_cabanha` só corrigia isso manualmente pra 1 caso
  (`gestacoes_protocolo_aplicado_id_fkey`). A migration atualiza a RPC (`v_tabelas` + 4 `alter table add
  constraint` novos) pra que cabanhas provisionadas a partir de agora ganhem as 3 tabelas novas **com**
  FK. ⚠️ Achado também, fora do escopo desta fase: os FKs "antigos" de `acasalamentos` (egua_id,
  fonte_cobertura_id, veterinario_id, aprovado_por, criado_por) **já não** são recriados pela RPC hoje —
  só existem nos tenants já provisionados por uma correção manual anterior que nunca voltou pra RPC. Não
  é regressão desta fase; registrado no `HANDOFF.md` pra alguém revisar depois.
- Revisão de isolamento (`revisor-isolamento`) rodada — sem vazamento cross-tenant encontrado. Achado de
  estilo (não bloqueante): o passo que replica pra tenants já provisionados usa 4 policies por tabela
  (select/insert/update/delete via `tem_acesso_tenant` por `schema_name`), confirmado ao vivo no banco
  como o padrão real hoje em `fontes_cobertura`/`acasalamentos`/`gestacoes`/`tentativas` (tabelas
  "antigas" tipo `animais`/`vacinacoes` ainda usam 1 policy `memb_all`, herdada de antes do Reprodutivo
  v3) — mantido como está por ser o padrão vigente do domínio reprodutivo, não uma invenção.
- **Achado real na verificação pós-aplicação (corrigido na hora)**: as 3 tabelas novas nasceram no
  template `public` com RLS **desligada** e grant padrão pra `anon` — diferente de `public.animais`
  (RLS ligada, deny-all, zero grant pra `anon`). Como o `public` é exposto pelo PostgREST por padrão,
  isso deixava as 3 tabelas do template legíveis/graváveis por qualquer chamada anônima (dado real nunca
  mora no template, mas ainda assim era uma porta aberta). Corrigido: RLS ligada + `revoke all ... from
  anon` nas 3, replicando o padrão de `animais`. Migration/spec atualizadas pra já nascer assim numa
  reaplicação futura.

### Fase 1 — Reprodutivo do criador: reordenar, renomear, corrigir ✅ APLICADA (2026-08-13)

Mudanças de fluxo/UI de baixo risco na tela Reprodutivo existente — sem depender do Kanban (Fase 4) pra
fazer sentido sozinha.

- Reordenar abas: **Gestações ativas do ciclo corrente** primeiro, **Planejador de ciclo** segundo,
  **Acasalamentos** terceiro (seção 3.1). Feito — só reordenação de botões/visibilidade padrão, nenhum id
  mudou (o "Ver gestação" do kanban de Protocolo Reprodutivo, que seleciona a aba por atributo `onclick`,
  continua funcionando sem ajuste).
- Estilo de card com barra de progresso pra "Gestações ativas" (mesma referência visual da aba "Legado"
  hoje) — `_gestCard()` trocou o visual `.kanban-card` (compacto, sem barra) pelo `.gest-card` +
  `.gest-prog`/`.gest-dias` (nome, garanhão, badge de trimestre, barra de progresso, dias de gestação e
  parto previsto) — mantendo a timeline detalhada e os botões de ação (aplicar protocolo, registrar
  parto/aborto/perda) que já existiam.
- Renomeada "Fontes de Cobertura" pra **"Garanhões e Coberturas"** (seção 3.3) — só o rótulo da aba, id
  (`gest-fontes`) e função de render (`renderFontesCobertura`) não mudaram de nome, evitando retrabalho.
- Renomeado campo "Quantidade adquirida" pra **"Quantidade disponível"** (label do formulário + mensagem
  de validação) — a coluna do banco (`quantidade_adquirida`) e as variáveis internas continuam com o nome
  antigo, é só o texto visível pro usuário.
- Campo **"Castrado"** no cadastro/edição de Animais — checkbox simples (sem gating por sexo, mesmo
  padrão do campo "Confirmado" já existente). Filtra a lista de garanhões do Planejador de ciclo
  (`renderPlanejadorReprodutivo`); a listagem de "Reprodutores" na aba Plantel **não** foi filtrada de
  propósito — é uma contagem histórica de crias por padrillo (inclusive nomes externos), não uma tela de
  seleção pra planejamento novo, então um garanhão castrado que já teve produção no passado continua
  contado ali (seção 2, "histórico não é afetado").
- Corrigido o bug do formulário "Cadastrar animal" (usado tanto por "+ Novo animal" quanto por "+
  Adicionar receptora (via SBB)"): não limpava os campos entre usos — extraído `_limparFormNovoAnimal()`,
  chamado antes de abrir o modal nos dois pontos de entrada e depois de salvar (seção 3.6).
- Testado via servidor estático local + sessão injetada: ordem/visibilidade das abas, card com progresso
  renderizando dados reais de `gestacoes`, campo Castrado some da lista do Planejador, e duas aberturas
  seguidas do modal de receptora sem vazar dado da anterior.

### Fase 2 — Garanhões e Coberturas reestruturados ✅ APLICADA (2026-08-13)

- Novo tipo de fonte **"Cobertura"** (avulsa) adicionado ao select do modal de fonte (`fc-tipo`) e ao
  `FC_TIPO_LABEL` — se comporta como "Direito de uso" pra fins de campos visíveis (vigência, sem
  proprietário/percentual de cota).
- Fluxo **"Próprio"**: `renderPlanejadorReprodutivo()` não mostra mais "+ Definir saldo deste ciclo" — ao
  renderizar, cria automaticamente (sem modal) uma fonte `proprio` pro ciclo usando
  `animais.qtd_coberturas_padrao` (default 120) como saldo inicial. O card do garanhão ganhou edição
  inline: input de quantidade com `max` travado no padrão do animal (só diminui — tentar passar do
  padrão mostra alerta explicando que precisa editar o padrão em Animais) + checkboxes de RM/Demérito
  direto no card, sem abrir modal nenhum. A mesma trava de teto foi replicada em `salvarFonteCobertura()`
  pra cobrir edições feitas pela aba "Garanhões e Coberturas" (que ainda usa o modal genérico).
- Campo `qtd_coberturas_padrao` (padrão 120) adicionado ao cadastro/edição de Animais, editável junto do
  campo Castrado.
- Fluxo **Cota / Direito de uso / Cobertura**: `abrirModalFonteCobertura()` (botão "+ Nova fonte" do
  topo) não abre mais com tipo "Próprio" nem ciclo vazio — tipo padrão agora é "Cota", e o campo Ciclo já
  vem pré-preenchido com o ciclo selecionado no Planejador (nunca mais solto).
- `_criarFonteParaGaranhao()` removida (função órfã depois da mudança — o fluxo que ela abria não existe
  mais).
- Testado via servidor estático local: fonte "própria" nasce automática com o padrão certo, edição inline
  bloqueia valor acima do padrão (mantém o valor anterior + alerta) e aceita diminuir normalmente, modal
  genérico abre com tipo "Cota" e ciclo do planejador pré-preenchido, opção "Cobertura" disponível no
  select.

### Fase 3 — Remover "Marcar como reprodutora" + simplificar Acasalar ✅ APLICADA (2026-08-13)

- **Achado ao investigar**: nunca existiu um toggle/flag "reprodutora" de verdade — `renderEguasCriaPlanejador()`
  já derivava isso de existir (ou não) um `acasalamento` não-cancelado da égua naquele ciclo desde o
  Reprodutivo v3. O que precisava mudar era só nome/rótulo (soava como um passo extra artificial) e duas
  validações que realmente faltavam. Renomeado: botão "+ Marcar como reprodutora" → **"+ Acasalar"**,
  função `_marcarEguaReprodutora` → `_acasalarEguaPlanejador`, badge "Reprodutora" → "Acasalada".
- Fluxo "Acasalar" já era "seleciona garanhão (fonte) + égua → gera acasalamento" (modal único,
  `abrirModalAcasalamento`/`salvarAcasalamento`) — o que faltava era validar na hora de salvar:
  - **Saldo esgotado**: `_saldoFonteCobertura(fonte).disponivel <= 0` agora mostra `confirm()` antes de
    lançar (nunca bloqueia sozinho, só avisa — mesmo padrão já usado no resto do app). Na prática também
    já é coberto uma camada antes: `_acFontesAtivas()` só lista no dropdown fontes com saldo > 0.
  - **Gestação ativa no mesmo ciclo** (bloqueio de verdade, não só aviso): nova função
    `_eguaGestandoNoCiclo(eguaDbId, ciclo)` — junta `gestacoes` (status `gestando`) com o `ciclo` do
    `acasalamento` vinculado. Se a égua já está gestando nesse ciclo, `salvarAcasalamento()` recusa com
    mensagem explicando que precisa esperar a gestação encerrar (nasceu/perdeu) ou planejar pro próximo
    ciclo.
- Égua com gestação ativa entrando no planejamento do **próximo** ciclo: já funcionava de graça, sem
  precisar de código novo — o card da égua em `renderEguasCriaPlanejador()` já é escopado por ciclo
  (`ac.ciclo === ciclo` do planejador selecionado), então uma égua gestando no ciclo atual aparece como
  "sem acasalamento" ao trocar pro próximo ciclo, exatamente como devia.
- Testado via servidor estático local: `_eguaGestandoNoCiclo` retorna `true` só pro ciclo da gestação
  ativa e `false` pra outro ciclo; `salvarAcasalamento()` bloqueia (sem criar linha) a égua gestando no
  mesmo ciclo e permite normalmente pro próximo ciclo.

### Fase 4 — Receptoras / Transferência de Embrião + Plantel disponível ✅ APLICADA (2026-08-13)

- Tipo de fonte **"Embrião"** adicionado ao select (`fc-tipo`) e ao `FC_TIPO_LABEL`, ao lado de
  Próprio/Cota/Direito de uso/Cobertura — mesmo comportamento de campos que Direito de uso/Cobertura.
- Flag `receptora` (checkbox estruturado, cadastro/edição de Animais) substitui o texto livre "Receptora
  (TE)" que `_abrirReceptoraViaSBB()` escrevia em Observações. Exige SBB preenchido antes de permitir
  marcar — validado em `salvarAnimal()` e `salvarEdicaoAnimal()` (bloqueia salvar, antes de qualquer
  mutação, mesmo padrão da validação de nome já existente).
- **Achado ao investigar a "regra de parentesco"**: o bug que a spec antecipava (registrar a receptora
  como mãe) **nunca existiu** — `gestacoes.egua_id` sempre foi a égua do `acasalamento` (`ac-egua` no
  modal), e essa sempre foi tratada como a doadora, nunca a receptora (que é um campo novo,
  `acasalamentos.receptora_animal_id`, adicionado agora, separado). `_criarAnimalDeParto()` já usa
  `g.egua_id` pra definir a mãe da cria — sempre a doadora, sem mudança de código necessária ali. O que
  faltava era só **deixar isso visível**: modal "Registrar parto" ganhou um aviso explícito quando é TE
  ("Mãe registrada no cadastro da cria: X (doadora do embrião) — não a receptora Y"), pra confirmar pro
  usuário o que já acontecia por trás.
- Modal de acasalamento ganhou um select "Receptora" (`ac-receptora`), visível só quando o tipo de
  cobertura é TE (`_toggleCamposAcasalamento()`), listando éguas com `receptora=true` na cabanha —
  opcional na criação (pode ficar em aberto pro veterinário decidir depois, na Fase 5). Persistido em
  `acasalamentos.receptora_animal_id`.
- Exibição da gestação: `_gestCard()` nomeia a doadora no título (como já fazia) e ganhou um sub-rótulo
  "na receptora **X** (SBB) — TE (Transferência de Embrião)" quando há receptora vinculada — formato
  exato pedido na seção 3.5, testado e conferido pixel a pixel contra o exemplo da spec.
- Nova aba **"Plantel disponível"** (`tab-plantel-disponivel`), entre Acasalamentos e Garanhões e
  Coberturas, escopada pelo ciclo selecionado no Planejador — 5 seções somente-leitura: Garanhões (saldo
  > 0), Éguas de cria (sem acasalamento ainda nesse ciclo), Cotas/Direito de uso/Cobertura ativas,
  Embriões, Receptoras (com `receptora=true` e ainda não vinculadas a um acasalamento TE nesse ciclo).
- Testado via servidor estático local: sub-rótulo da gestação bate com o formato exato do exemplo da
  spec; toggle do campo Receptora no modal de acasalamento (aparece só em TE, popula corretamente);
  bloqueio de SBB vazio pra marcar receptora (cadastro novo); Plantel disponível reflete corretamente
  saldo consumido e receptora já ocupada (não aparece como disponível); aviso explícito de "mãe = doadora"
  no modal de registrar parto quando é TE.

### Fase 5 — Kanban do veterinário (Saúde & Vacinas → aba Reprodutivo) ✅ APLICADA (2026-08-13)

Implementada inteira, sem dividir em sub-fases — o desenho ficou direto o suficiente pra não precisar.

- Nova aba **"Reprodutivo"** dentro de Saúde & Vacinas (`tab-reprodutivo-vet`), ao lado de "🧬 Protocolo
  Reprodutivo" (que é outra coisa — acompanha etapas de protocolo gestacional, não o funil de
  acasalamento; sem sobreposição).
- 4 estágios do Kanban (`reproducao_estagios.estagio`, tabela da Fase 0): Controle → Inseminação/
  Cruzamento → Ovuladas → DG precoce, com botões de avanço/retorno em cada card
  (`_reproAvancarEstagio()`). O registro de estágio **nasce sozinho** quando o criador aprova o
  acasalamento (`_confirmarAprovacaoAcasalamento()`) — 1:1 garantido pelo UNIQUE em
  `acasalamento_id`. `acasalamentos.status` acompanha por fora: `aprovado` (aguardando entrar no
  funil) → `em_curso` (na primeira saída do Controle) → `confirmado` (DG definitivo).
- **Campo "tipo de cobertura" migrado pro Controle**: o select continua existindo no modal de
  acasalamento do criador (decisão de design — precisa dele pra saber se mostra o campo Receptora,
  Fase 4), mas agora é só uma intenção inicial; o **ponto de decisão final** é um select equivalente
  dentro do card do estágio Controle, que o veterinário pode confirmar ou trocar
  (`_reproAtualizarTipoCobertura()`).
- Alertas visuais de janela (`_reproAlertaJanela()`): azul = ainda esperando, âmbar = dentro da janela,
  vermelho = passou do esperado. Inseminação 3-7d, Ovuladas 15-20d (DG precoce), DG precoce ~45d
  (DG definitivo).
- **Bloqueio (regra revisada 3.1/4.1)**: card de égua com gestação ativa no **mesmo ciclo**
  (`_eguaGestandoNoCiclo()`, já existente desde a Fase 3) aparece com badge "Bloqueada" e sem os botões
  de transição — só "+ Atividade" e "Devolver pro planejamento" continuam disponíveis.
- **"Devolver pro planejamento"** (`_reproDevolverPlanejamento()`), em qualquer estágio: acasalamento
  volta pro `status='rascunho'`, o registro de estágio é apagado (sai do funil).
- **Atividades soltas** (`reproducao_atividades`, Fase 0): modal simples (tipo/data/obs), disponível em
  qualquer estágio, histórico visível no próprio card.
- **Confirmar DG definitivo** (`_confirmarDGDefinitivo()`): pede data de cobertura/inseminação + data de
  confirmação (não dava pra inferir automaticamente — o funil novo não tem um campo "data" próprio até
  aqui, diferente do fluxo antigo de tentativas), cria a gestação real (mesmo formato de linha que
  `_confirmarResultadoTentativa()` já usava), marca o acasalamento `confirmado`, remove o registro de
  estágio, e **oferece aplicar um protocolo gestacional na hora** (reaproveita
  `abrirModalAplicarProtocolo()`, já existente).
- **Última etapa do funil**: seção "Gestações ativas" logo abaixo do Kanban, reaproveitando o mesmo card
  com barra de progresso da tela do criador (`_gestCard()`, Fase 1) — mesmos botões de aplicar protocolo/
  registrar parto/aborto/perda, então **perda e nascimento já são registráveis por criador ou
  veterinário de graça**, sem código duplicado (é o mesmo componente nas duas telas).
- **Regra de corte 30/06→01/07 — nenhum código novo precisou ser escrito.** Verificado que
  `_cicloAtualTexto()`/`_cicloProximoTexto()` já recalculam os 2 ciclos oferecidos no Planejador
  dinamicamente a partir de `HOJE`, com o mesmo corte de julho do banco (`_calc_ciclo_texto`). Antes do
  corte: perda de cria muda `gestacoes.status`, `_eguaGestandoNoCiclo()` passa a retornar `false`, e a
  égua fica automaticamente replanjável no **mesmo** ciclo (ainda oferecido nas pills). Depois do corte:
  o ciclo antigo simplesmente some das pills — não tem como planejar nele de novo, em nenhuma
  circunstância, sem precisar de uma regra de bloqueio dedicada.
- **Achado no caminho**: o antigo botão "+ Registrar tentativa" (aba Acasalamentos do criador) fazia
  parte exatamente do que esta fase substitui — rastreava tentativa de IA/monta + resultado
  prenha/vazia, criando a gestação por conta própria. Removido do card do criador (`_acCard()`) pra não
  coexistir com o funil novo rastreando a mesma coisa duas vezes; o histórico de tentativas antigas (se
  houver) continua visível, só não dá mais pra criar uma nova por ali — esse trabalho agora é feito no
  Controle/Inseminação do Kanban do veterinário.
- **Banco**: `carregar_dados_cabanha()` (RPC de bootstrap) não trazia `reproducao_estagios`/
  `reproducao_atividades`/`tratamentos` (criadas na Fase 0, mas nunca incluídas no SELECT do bootstrap)
  — corrigido em `docs/migrations/2026-08-13-reprodutivo-v4-fase5-bootstrap.sql`, aplicado e revisado
  pelo `revisor-isolamento` (aprovado — mudança mecânica, mesmo padrão das ~19 tabelas já lidas ali,
  sem vazamento cross-tenant).
- Testado via servidor estático local: aprovar acasalamento cria o estágio Controle sozinho; avançar
  pelos 4 estágios funciona e `status` do acasalamento vira `em_curso` na primeira saída do Controle;
  confirmar DG definitivo cria a gestação, zera o estágio e a gestação aparece em "Gestações ativas"
  com o card de progresso; bloqueio visual funciona pra égua com gestação ativa no mesmo ciclo; atividade
  solta persiste e aparece no card; devolver pro planejamento reseta o acasalamento e remove o estágio;
  botão de tentativa removido do lado do criador sem quebrar o resto do card.

### Fase 6 — Saúde & Vacinas: Tratamentos + registro em lote ✅ APLICADA (2026-08-13)

- Nova categoria **"Tratamentos"** (tabela `tratamentos`, Fase 0) — aba própria em Saúde & Vacinas,
  botão "+ Tratamento" no cabeçalho, lista simples (animal/início/fim/descrição/responsável) com
  editar/excluir. Sem registro em lote — é sempre específico de um animal por natureza.
- Registro em lote pra **Vacinas** e **Exames** (`renderLoteAnimais()`, `loteToggleAnimal()`,
  `loteSelecionarTodos()` — genéricas, parametrizadas por `'vac'`/`'exam'` em vez de duplicar a lista de
  seleção duas vezes): mesma UI de seleção (buscar, todos/nenhum, contador) que já existia só em
  Vermifugação, reaproveitando as classes CSS `.verm-animal-row`/`.verm-check` (genéricas apesar do
  nome). Versão de formulário **simplificada** em relação ao "+ Vacinar"/"+ Exame" de 1 animal — sem os
  campos especiais de AIE (resultado/laboratório/número) e sem anexo de laudo em PDF; quem precisar
  desses recursos continua usando o fluxo individual, que não mudou.
- **Achado real no caminho, corrigido**: `salvarVermifugacaoGrupo()` — a função que já existia e serviu
  de referência pro padrão de lote — **nunca chamava `_dbSalvarVermifugacao()`**. O registro em lote de
  vermifugação só gravava em memória (`histVermifugacoes`, `animais[i].ult_verm`) e nunca persistia no
  banco; a função de persistência existia pronta, só não era chamada de lugar nenhum. Corrigido (uma
  linha) — sem isso, teria replicado o mesmo bug nas funções novas de Vacina/Exame em lote.
- Testado via servidor estático local: vacina/exame em lote persistem (`POST vacinacoes`/`POST exames`)
  pra cada animal selecionado; vermifugação em lote agora também persiste (`POST vermifugacoes`,
  confirmado que antes não chamava nada); tratamento novo salva, aparece na lista, e edita/exclui.

### Fase 7 — Menu Animais ✅ APLICADA (2026-08-13) — última fase da spec

- **Achado ao começar**: "Importação em lote por SBB (colar lista, ou subir `.txt`/`.csv`)" **já estava
  construída** — `modal-import-sbb`/`abrirModalImportarSBB()` (Prioridade 3 do `ROADMAP.md` antigo),
  com os dois caminhos (colar lista ou upload de arquivo), busca em lote na ABCCC, preview antes de
  confirmar e barra de progresso. Nada pra fazer aqui, só confirmar que já cobre o pedido — a variante
  "puxar lista completa do proprietário via ABCCC" segue fora de escopo (seção 6), não investigada.
- **Foto do animal** (`animais.foto_url`, migration
  `docs/migrations/2026-08-13-reprodutivo-v4-fase7-foto-animal.sql`) — mesmo padrão já usado pros laudos
  de vacina/exame (`vacinacoes.laudo_url`/`exames.laudo_url`): data URI base64 direto num campo `text`,
  lido via `FileReader` no navegador, limite de 5MB no client, **sem bucket de Storage novo**. Upload nos
  dois modais de animal (cadastro e edição), com preview circular e botão de remover.
- **Redesenho pra grid/swimlane**: `renderAnimais()` passou a montar as duas visões — grade (cards com
  avatar/foto, badges de situação/estágio/ciclo/confirmado, pelagem/nascimento/RP) e a tabela densa que
  já existia — com um **toggle** (`_animaisSetView()`, persistido em `localStorage`) em vez de substituir
  a tabela de vez. Grade é o padrão. Sem foto cadastrada, o avatar cai pra um círculo com a inicial do
  nome (mesmo padrão do avatar da sidebar).
- Testado via servidor estático local: grade renderiza com avatar/iniciais e badges corretos; toggle
  troca de visão e persiste em localStorage; upload de foto lê o arquivo como data URI e mostra o
  preview.

### Fase 8 — revisão pós-feedback (retrabalho pontual, 2026-08-13)

Depois das 8 fases originais em staging, o dono do produto usou o fluxo e trouxe 2 pontos de feedback
(decididos direto com ele, sem nova reunião): tipo de cobertura no fluxo errado + UX de acasalamento
ruim (ponto 3), e Plantel disponível/Garanhões e Coberturas/Nova fonte com atrito (ponto 4).

**Ponto 3 — Tipo de cobertura sai do fluxo do criador + UX "Tinder" de acasalamento**

- **3a**: removido o `<select id="ac-tipo">` do modal do criador (`modal-acasalamento`) — decidir
  IA/Natural/TE virou 100% trabalho do veterinário no estágio Controle do Kanban
  (`_reproAtualizarTipoCobertura()`, sem mudança). `acasalamentos.tipo_cobertura` agora nasce sempre
  `null` em `salvarAcasalamento()` (já era nullable desde a Fase 0). O gatilho do campo Receptora
  (`ac-grp-receptora`) deixou de depender do tipo de cobertura e passou a depender da **fonte
  selecionada ser do tipo "embriao"** (`_toggleCamposAcasalamento()`, chamado tanto no `onchange` de
  `ac-fonte` quanto na abertura do modal). O select `repro-tipo-*` no Controle do Kanban (vet) ganhou
  uma opção "Selecione..." vazia, já que agora sempre começa sem valor.
- **3b**: nova tela "duas colunas + clique pra ligar" dentro da própria aba **Acasalamentos**
  (`gest-acasalamentos`) — coluna esquerda com garanhões/fontes do ciclo do Planejador, coluna
  direita com éguas de cria, `renderAcasalamentosMatch()`. Clicar numa fonte seleciona (destaque
  visual + resumo no topo), clicar numa égua com fonte já selecionada abre o modal antigo
  (`modal-acasalamento`) já em **modo confirmação** — égua/fonte ocultas (só um resumo em texto),
  restando Ciclo (readonly)/Observações/Receptora (se embrião), via nova função
  `abrirModalAcasalamentoMatch()`. O botão "+ Novo acasalamento" do topo da página passou a levar pra
  essa aba (`switchTab` pro `gest-acasalamentos`) em vez de abrir o modal de formulário direto — o
  modal completo (`abrirModalAcasalamento()`, com os selects visíveis) continua existindo como
  fallback interno, sem ponto de entrada padrão apontando pra ele. Fonte sem saldo e égua já com
  match no ciclo aparecem esmaecidas (opacidade), sem sumir da lista, sem `onclick`. Lista de
  acasalamentos do ciclo (kanban por status) continua logo abaixo, reaproveitando `_acCard()` sem
  mudança.
- Testado via servidor estático local: sintaxe do `<script>` extraído (`node -e "new
  Function(...)"`); seleção de fonte → clique em égua abre o modal em modo confirmação com o resumo
  certo; campo Receptora só aparece pra fonte tipo Embrião (não mais por tipo de cobertura, que nem
  existe mais no criador); modal de fallback completo ainda funciona igual a antes.
- **✅ QA real feita logo em seguida** (mesma sessão, com `mcp__Claude_Browser__*` disponível): match
  fonte→égua testado ponta a ponta (seleção com destaque, abertura do modal de confirmação com resumo
  certo, `tipo_cobertura` chegando `null` no payload salvo), campo Receptora confirmado aparecendo só
  pra fonte tipo Embrião e populando a partir das éguas elegíveis.

**Ponto 4 — Garanhões e Coberturas / Plantel disponível / Nova fonte**

- **4a**: "Plantel disponível" (`tab-plantel-disponivel`) fundida em "Garanhões e Coberturas"
  (`gest-fontes`) — aba/botão duplicados removidos do `tab-row` e do array `all` do `switchTab()`. A
  aba única abre sempre na visão de leitura rápida (o antigo conteúdo de Plantel disponível, sempre
  visível no topo); a lista editável (antigo `gest-fontes-content` + filtros + histórico de
  negociações) foi movida pra dentro de um bloco colapsável (`gest-fontes-edit-wrap`, fechado por
  padrão), com um cabeçalho clicável "✏️ Editar Garanhões e Coberturas"
  (`_toggleEdicaoFontesCobertura()`, mesmo padrão de `_toggleHistoricoNegociacoes()`). `switchTab`
  (patch) e o carregamento inicial da página Reprodutivo passaram a chamar
  `renderPlantelDisponivel()` junto de `renderFontesCobertura()`.
- **4b**: fonte tipo "Cota" trocou o campo de nome livre (`fc-garanhao-nome`) por um
  `<select id="fc-garanhao-animal">` dos machos cadastrados em Animais (`_fcPopularSelectAnimaisCota()`,
  `_fcGaranhaoAnimalChange()` preenche nome/SBB por trás pra manter compatibilidade com o resto do
  fluxo, incluindo edição). `salvarFonteCobertura()` agora bloqueia salvar sem selecionar o animal
  quando `tipo==='cota'`. Percentual da cota (`fc-cota-pct`) ganhou `onchange="_fcSugerirQtdPorCota()"`
  — calcula `Math.round(120 * pct / 100)` e pré-preenche `fc-qtd` (continua editável depois, sem trava
  de "só diminuir" — é sugestão inicial, não teto).
- **4c**: nova coluna `fontes_cobertura.recorrente boolean not null default false` — migration
  `docs/migrations/2026-08-13-reprodutivo-v4-fase8-garanhoes.sql`. Checkbox "Recorrente" no modal de
  fonte, visível só pra tipo "Direito de uso" (`fc-grp-recorrente`, toggle em
  `_toggleCamposFonteCobertura()`). `renderPlanejadorReprodutivo()` ganhou a lógica de persistência
  automática: ao selecionar o **próximo ciclo** nas pills, clona qualquer fonte `direito_uso` marcada
  `recorrente` do ciclo atual que ainda não exista no próximo (mesma quantidade, `db_id` novo) — mesmo
  princípio do "Próprio" da Fase 2, mas usando o valor da própria fonte recorrente como "padrão", em
  vez de `qtd_coberturas_padrao` do animal. Fonte "Cobertura" **não mudou** — continua sempre
  relançada manualmente por ciclo, como já era.
  - **✅ Migration aplicada logo em seguida** via `mcp__supabase__apply_migration`, confirmada por
    `information_schema.columns` nos 7 tenants (`cab_*`) + `public`.
  - **Decisão de isolamento**: não passou pelo `revisor-isolamento` — é coluna simples numa tabela já
    coberta pelas policies existentes (`tem_acesso_tenant`), sem grant novo nem mudança de shape de
    acesso, mesmo padrão de `qtd_coberturas_padrao`/`castrado` (Fase 0). Documentado, não revisado à
    parte.
- **4d**: confirmado — não há nenhum ponto do código hoje que tente linkar/exibir fontes tipo
  `direito_uso`/`cobertura` dentro do menu Animais (`renderAnimais()`, `salvarAnimal()`,
  `salvarEdicaoAnimal()`); são sempre `fontes_cobertura` solto, nunca viram linha em `animais`. Nenhum
  código mudou por causa deste item.
- Testado via servidor estático local: sintaxe do `<script>` extraído; aba fundida abre com leitura
  rápida e o bloco de edição continua fechado até clicar; modal de nova fonte com tipo Cota mostra o
  select de animais em vez do campo de texto e bloqueia salvar sem selecionar; percentual de cota
  pré-preenche a quantidade sugerida; checkbox Recorrente só aparece pra Direito de uso.
- **✅ QA real e migration feitas logo em seguida** (mesma sessão): coluna `recorrente` confirmada no
  banco (7 tenants + `public`); fluxo de match, seleção de fonte tipo Cota (select de animal + sugestão
  de quantidade por %) e checkbox Recorrente testados no browser com sessão injetada.

### Fase 8b — correção de layout do cadastro + remoção do flag "Receptora" (2026-08-13)

Dono do produto usou o cadastro de animal recém-promovido e reportou dois problemas.

- **Bug de layout**: no grid de 2 colunas do modal (novo e editar), a célula do checkbox "Castrado"
  era mais curta que a da célula vizinha "Coberturas por ciclo (padrão)" (label de 2 linhas + input) —
  como `.form-group` é `display:flex;flex-direction:column` dentro de uma célula de `.form-grid` que
  estica pra altura da linha (grid `align-items` padrão `stretch`), o checkbox ficava "flutuando" no
  topo da célula em vez de alinhado com o input ao lado. Corrigido com `justify-content:flex-end` na
  célula do Castrado (`modal-novo` e ficha de edição), alinhando pela base — mesma altura visual do
  input vizinho.
- **Removido o checkbox "Receptora (transferência de embrião)" do cadastro de Animais** (`nreceptora`/
  `ed-receptora`, ambos os modais). Reavaliação de design: a Fase 4 tratou "receptora" como atributo
  permanente do animal (`animais.receptora boolean`), mas na prática de uso uma égua pode ser
  receptora só num ciclo específico — nos demais ciclos pode ser reprodutora normal ou não participar
  de nada reprodutivo. Não fazia sentido gravar isso como flag fixo no cadastro. Os dois pontos que
  antes filtravam candidatas por esse flag —
  `renderPlantelDisponivel()` (seção "Receptoras" do Plantel/Garanhões e Coberturas) e o select
  `ac-receptora` do modal de acasalamento — passaram a usar a regra de negócio real: **qualquer fêmea
  "Na Cabanha" com SBB preenchido** é candidata a receptora naquele ciclo, sem pré-marcação nenhuma
  (SBB continua obrigatório pra ABCCC, só que verificado no momento de oferecer a candidata, não mais
  no cadastro). `_abrirReceptoraViaSBB()` ("+ Adicionar receptora via SBB") continua existindo como
  atalho de cadastro rápido, só sem marcar mais flag nenhuma. **Coluna `animais.receptora` no banco
  não foi removida** — sem migration nesta rodada, o campo só fica morto (sempre `false` a partir de
  agora, nunca mais lido pra decidir elegibilidade); dado histórico de quem já tinha `true` fica
  intacto mas sem efeito nenhum na UI.
- Testado via servidor estático local + `mcp__Claude_Browser__*`: checkbox "Receptora" sumiu dos dois
  modais; "Castrado" alinha visualmente com o input "Coberturas por ciclo" ao lado; select de
  Receptora no modal de acasalamento lista só fêmeas "Na Cabanha" com SBB preenchido (égua sem SBB
  fica de fora, confirmado com dado de teste).

### Fase 9 — remoção completa da aba "Legado" + tabela `coberturas_arquivadas_legado` (2026-08-19)

A aba "Legado" (seção histórica, fora do escopo original desta spec) existia só pra não perder as 4
gestações abertas que a Cabanha Mãe de Deus tinha no fluxo antigo (pré-Reprodutivo v3), ver incidente
registrado no `HANDOFF.md` de 2026-08-12. Pedro pediu pra migrar essas 4 pro sistema vigente e remover
a funcionalidade inteira — frontend e banco, "clean".

- **Migração de dado real** (Cabanha Mãe de Deus, `cab_mae_de_deus`, único tenant com gestações reais
  na tabela legada — a outra ocorrência, na cabanha de teste do Pedro, era fixture, descartada): as 4
  linhas de `coberturas_arquivadas_legado` (resultado `Prenha`) viraram registros reais em
  `fontes_cobertura` (tipo `cobertura`, já `esgotada` — representa a cobertura pontual já realizada) +
  `acasalamentos` (`status='confirmado'`) + `gestacoes` (`status='gestando'`), preservando as datas
  reais de cobertura e diagnóstico e o ciclo calculado a partir delas (`25/26`, via
  `public._calc_ciclo_texto()`, a mesma função que a UI usa). Migração feita por SQL direto (não pela
  UI), documentada em `HANDOFF.md`.
- **Frontend**: removida a aba "Legado" inteira — botão (`tab-btn-legado`), conteúdo (`gest-ativas`/
  `gest-ativas-content`, incluindo a subseção "Histórico arquivado" que lia do array `coberturas`,
  órfão e sempre vazio desde antes desta sessão), o modal `modal-cobertura-gest` e toda a cadeia de
  funções que só existia pra alimentá-lo: `renderGestacao()`, `salvarCoberturaGest()`, `editCobGest()`,
  `excluirCobertura()`, `_dbSalvarCobertura()`, `_dbExcluirCobertura()`, `popularSelectEguas()`,
  `selecionarPadrillo()`, `toggleCampoPadrillo()`, `buscarPadrilloSBB()`,
  `_mostrarCamposManuaisPadrillo()`, `confirmarDadosManuaisPadrillo()`, `_preencherDadosPadrillo()`,
  `_calcularPartoPrevistoAuto()`. Os arrays globais `coberturas`/`coberturas2` e a entrada
  correspondente em `_limparEstadoLocal()` também saíram.
- **Pontos que dependiam funcionalmente do legado (não só exibição) foram migrados pra ler de
  `gestacoes`, não apenas apagados** — achado importante pra não perder capacidade real: alerta de
  "parto próximo/atrasado" no dashboard (`renderDashboard`), marcador de "parto previsto" no calendário
  de eventos (`renderCalendario` e `mostrarEventosDia`), contagem de éguas prenhas pra checar vacina
  obrigatória (`_renderVacObrigatorias`), histórico de "cruzamentos anteriores" no painel de simulação
  do modal de acasalamento (`_renderSimulacaoAcasalamento`, agora lê `acasalamentos` reais em vez do
  texto livre do legado), e a linha do tempo do animal (`_carregarLinhaTempo`, trocou o fetch de
  `coberturas_arquivadas_legado` por um fetch equivalente em `gestacoes`).
- **Banco**: migration `docs/migrations/2026-08-19-remove-legado-coberturas.sql` — recria
  `carregar_dados_cabanha()` (RPC de bootstrap SECURITY DEFINER) sem a variável/query/chave de
  `coberturas_arquivadas_legado`, mantendo intacto o gate `tem_acesso_tenant(p_tenant_id)` no início da
  função. Dropa a tabela do template `public` e, via loop `do $$ ... $$`, de todos os 7 schemas `cab_*`
  provisionados. **Achado**: `provisionar_schema_cabanha()` já não incluía essa tabela no array
  `v_tabelas` — cabanhas provisionadas de algum ponto em diante já nasciam sem ela, então a RPC de
  provisionamento não precisou de nenhuma mudança. Confirmado via `pg_constraint` que nenhuma outra
  tabela tinha FK apontando pra ela antes do DROP — sem risco de cascade em dado de terceiros.
- Revisão de isolamento (`revisor-isolamento`) rodada — **aprovada**: gate de acesso preservado na RPC
  recriada, zero referência remanescente a `coberturas_arquivadas_legado`/`coberturas2` no
  `index.html`. Os dois pontos que o subagente não conseguiu checar por falta de acesso a ferramentas
  de banco na sessão dele (policies/triggers referenciando a tabela em texto dinâmico, e consistência
  dos 7 schemas pós-DROP) foram conferidos manualmente depois via MCP — nenhuma policy/trigger
  encontrada, e query de consistência (`pg_tables` nos 7 `cab_*`) retornou vazia.
- Testado via servidor estático local + `mcp__Claude_Browser__*`: sintaxe do `<script>` extraído
  validada; gestação migrada renderiza normalmente em "Gestações ativas" (progresso/trimestre/data de
  parto calculados certos a partir da data de cobertura real); Dashboard, ficha de detalhe do animal,
  calendário de eventos e Planejador de ciclo renderizam sem erro; nenhum resquício textual ou
  funcional de "Legado" restante em nenhuma tela.

### Fase 10 — garanhões "fantasma" em Acasalamentos + bug de seleção múltipla (2026-08-19)

Pedro reportou, na Cabanha Mãe de Deus (ciclo 26/27): (1) a aba Acasalamentos listava garanhões nunca
cadastrados como animal da cabanha, como se fossem fonte "Próprio" disponível; (2) na tela de match
(Fase 8, ponto 3b), clicar num garanhão específico selecionava ele **junto com outros 3** ao mesmo
tempo.

- **Causa raiz do garanhão fantasma**: `pg_cron` `encerramento-ciclo-reproducao` (`0 3 1 8 *`, chama
  `public.encerrar_ciclo_reproducao()`) tinha um passo clonando qualquer fonte `proprio` do ciclo
  anterior pro novo só por nome/SBB baterem, sem validar contra o cadastro de Animais — redundante
  desde a Fase 2 (2026-08-13), que já faz isso no client de forma validada. Corrigido removendo esse
  passo da função (`docs/migrations/2026-08-19-fix-cron-fontes-fantasma.sql`), mantendo os outros 3
  passos legítimos (vencer fontes com saldo, cancelar acasalamentos travados, vencer cota/direito de
  uso expirados). Limpas as 7 linhas fantasma já existentes na Mãe de Deus — sem acasalamento vinculado
  a nenhuma, DELETE direto. Confirmado que as outras 6 cabanhas provisionadas estavam limpas.
- **Causa raiz da seleção múltipla**: `_acMatchSelecionarFonte()`/`renderAcasalamentosMatch()`
  comparavam fontes por `db_id` — mas uma fonte "Próprio" recém-auto-criada só ganha `db_id` depois do
  POST assíncrono terminar. Achado real: o POST pra 4 garanhões reais da Mãe de Deus estava falhando
  silenciosamente (`_supa()` engole erro HTTP e retorna `null` sem avisar ninguém), então ficavam pra
  sempre com `db_id` `undefined` — e `String(undefined) === String(undefined)` fazia clicar em
  qualquer uma delas selecionar todas.
- Nova função `_fonteKey(f)` dá identidade estável a qualquer fonte mesmo sem `db_id` (id local gerado
  na hora, cacheado no objeto). `_acMatchSelecionarFonte()` agora tenta persistir de novo a fonte no
  clique se ainda não tem `db_id`; `renderPlanejadorReprodutivo()` também retenta a cada render em vez
  de desistir após uma falha; `abrirModalAcasalamentoMatch()` bloqueia com aviso claro em vez de deixar
  criar um acasalamento com id inválido.
- **Bônus**: aba "Garanhões e Coberturas" (`renderFontesCobertura`) não tinha filtro padrão — virava
  lista longa e confusa em cabanhas com anos de fontes acumuladas. Primeira abertura da sessão agora já
  entra filtrada em ciclo atual do Planejador + status "Ativa" (limpar os filtros mostra tudo).
- Revisão de isolamento (`revisor-isolamento`) rodada — **aprovada**, condicionada a 2 verificações que
  o subagente não conseguiu rodar sem MCP (texto atual da função + agendamento do cron), confirmadas
  manualmente depois: `security definer`/`search_path`/loop cross-tenant/`%I` intactos, nenhum resíduo
  de `v_recriadas`, cron com mesmo `schedule`/`command` de antes (só o corpo da função chamada mudou).
- Testado via servidor estático local + browser: reproduzido o bug de verdade (rede falhando de
  propósito nos 4 POSTs de auto-criação), confirmado 1 card só marcado "Selecionado" por vez mesmo sem
  `db_id`; restaurada a rede, clicar de novo persiste e o `db_id` real assume a identidade; filtro
  padrão da aba Garanhões e Coberturas testado escondendo fonte de ciclo antigo e mostrando ao limpar.

### Fase 11 — funde Planejador + Garanhões e Coberturas, unifica origem, receptora fica visível (2026-08-19)

Pedro pediu pra fundir as abas "Planejador de ciclo" e "Garanhões e Coberturas" numa só, e resolver dois
problemas de clareza: garanhões por Cota/Direito de uso/Cobertura apareciam numa seção separada da de
"Próprio" (parecia um conjunto diferente de garanhões, quando é o mesmo conceito com origem diferente); e
não existia nenhuma forma visual de saber, na lista de éguas de cria, quais estavam servindo de receptora
de embrião de outra égua neste ciclo.

- **Abas fundidas**: "Garanhões e Coberturas" (`gest-fontes`) removida — seu conteúdo (edição completa,
  filtros, histórico de negociações) virou um bloco colapsável dentro de "Planejador de ciclo"
  (`tab-planejador`), logo abaixo da lista unificada de garanhões. `renderPlantelDisponivel()` (Fase 4/8,
  visão só-leitura que ficava no topo dessa aba) foi removida por completo — ficou redundante, a lista
  unificada do Planejador já mostra tudo isso de forma editável.
- **Garanhões unificados**: `renderPlanejadorReprodutivo()` agora renderiza numa única grade tanto os
  garanhões "Próprio" (auto-criados, card rico com edição inline de saldo) quanto as fontes
  Cota/Direito de uso/Cobertura (cards mais simples, com botão "editar" abrindo o modal completo) — cada
  card com uma etiqueta de origem (`Próprio`/`Cota`/`Direito de uso`/`Cobertura`) em cor própria, pra ficar
  óbvio de cara qual é a natureza da disponibilidade.
- **Receptoras ficam visíveis nas Éguas de cria**: `renderEguasCriaPlanejador()` passou a checar, pra cada
  égua, se ela está como `receptora_animal_id` de algum acasalamento ativo do ciclo (além de checar se ela
  é a doadora/acasalada, como já fazia) — se estiver, o card vira roxo (`--purple`/`--purple-l`), ganha
  badge "Receptora" e mostra "Receptora com embrião de **{doadora}**". Éguas com SBB ainda sem esse papel
  ganham um botão extra "Atribuir embrião" ao lado do "+ Acasalar" de sempre.
- **Novo fluxo "Atribuir embrião"** (`_abrirAtribuirEmbriao()`/`_confirmarAtribuirEmbriao()`, modal novo
  `modal-atribuir-embriao`): inicia pelo lado da receptora (em vez de só pelo lado da doadora, na tela de
  match) — lista os embriões disponíveis no ciclo (fonte tipo `embriao`, própria ou adquirida) e as éguas
  elegíveis como doadora (fêmeas na cabanha, sem acasalamento no ciclo, excluindo a própria receptora).
  Ao confirmar, reaproveita `abrirModalAcasalamentoMatch()` (Fase 8, ponto 3b) já existente — só
  pré-seleciona a doadora escolhida e o select de receptora, sem duplicar lógica de criação de
  acasalamento.
- Testado via servidor estático local + browser: lista unificada mostra Próprio/Cota/Direito de
  uso/Cobertura juntos com badges corretos; `_abrirAtribuirEmbriao` lista só embriões com saldo e exclui a
  receptora da lista de doadoras; fluxo completo (atribuir → confirmar → salvar) faz o card da receptora
  virar roxo com o texto "Receptora com embrião de DOADORA PROPRIA"; aba "Garanhões e Coberturas" some da
  lista de abas, sem nenhuma referência solta a `gest-fontes`/`renderPlantelDisponivel` no código.

### Fase 12 — corrige persistência do saldo "Próprio" + Cota/Direito de uso sem vínculo de animal (2026-08-19)

Pedro reportou que reduzir o saldo de um garanhão "Próprio" no Planejador e salvar não persistia (ctrl+F5
voltava pro padrão de 120), e que o saldo ficava sempre 120 "como se não tivesse vínculo" com o cadastro do
animal. Também pediu pra reverter a decisão da Fase 8 de exigir vínculo com animal cadastrado pra Cota —
segundo ele, Cota/Direito de uso nunca deveriam ter isso, porque não são animais sob gestão da cabanha, são
só direitos de cobertura sobre um garanhão de fora.

- **Causa raiz do "120 sempre"**: `renderPlanejadorReprodutivo()` só define `quantidade_adquirida` a partir
  de `qtd_coberturas_padrao` do animal **na criação** da fonte do ciclo — se o padrão do animal mudasse
  DEPOIS (editado em Animais), a fonte já existente ficava presa no valor antigo, podendo passar do que o
  cadastro permite agora. Corrigido: a cada render, se `quantidade_adquirida` da fonte for maior que o
  padrão atual do animal, reduz sozinha pro padrão atual e persiste — nunca aumenta sozinha (só o
  cabanheiro aumenta, editando manualmente até o novo teto).
- **Causa raiz do "não persiste"**: não era um bug novo — a explicação mais provável é a mesma falha
  silenciosa de sessão/JWT expirado corrigida na Fase anterior (`_garantirTokenValido()` só rodava antes de
  um fluxo específico). Testado end-to-end depois do fix: editar e salvar persiste de verdade.
- **Reversão da Fase 8 (ponto 4b)**: removida a exigência de vínculo com animal cadastrado pra Cota —
  select `fc-garanhao-animal` e as funções `_fcPopularSelectAnimaisCota()`/`_fcGaranhaoAnimalChange()`
  removidos. Cota volta a usar o campo de nome livre (`fc-garanhao-nome`), igual Direito de uso e
  Cobertura — nenhum dos três tipos cria ou referencia uma linha em `animais`.
- **"Próprio" removido do select do modal** "+ Nova cota / cobertura" — um animal próprio elegível já
  aparece sozinho no Planejador como garanhão da cabanha (Fase 2), não faz sentido oferecer criar um
  "Próprio" solto por esse modal.
- **Recorrência deixou de ser opcional**: checkbox "Recorrente" removido. Cota e Direito de uso agora
  **sempre** persistem automaticamente pro próximo ciclo (comportamento padrão, não mais opt-in) — só
  Cobertura continua sempre efêmera, precisa ser relançada a cada ciclo. Cards de Cota/Direito de
  uso/Cobertura no Planejador ganharam botão "excluir" (além do "editar" que já existia), já que agora
  persistem indefinidamente até o cabanheiro decidir desfazer.
- Testado via servidor estático local + browser: modal sem "Próprio" no select nem campo de vínculo de
  animal; salvar Cota com nome livre persiste corretamente; reduzir o padrão do animal em Animais faz a
  fonte "Próprio" do ciclo ajustar sozinha no próximo render (120→90 testado), sem sobrescrever um valor
  já editado manualmente abaixo do padrão (50 permaneceu 50); botões editar/excluir presentes nos cards
  de Cota/Direito de uso/Cobertura.

### Fase 13 — "+ Adicionar receptora" escolhe entre existente ou nova, com selo visual (2026-08-19)

Pedro reportou que "+ Adicionar receptora" ia direto pro cadastro de animal genérico, sem dar a opção de
escolher uma égua já cadastrada na cabanha — e pediu que, quando for de fato uma receptora nova (de fora),
ela tenha um selo bem claro que a diferencie do resto do plantel, e que suma sozinha quando a gestação em
que ela é receptora terminar (parto ou aborto/perda).

- **Novo modal de escolha** (`modal-escolha-receptora`): "+ Adicionar receptora" agora pergunta primeiro
  se é uma égua já cadastrada (nesse caso, fecha o modal e aponta pro botão "Atribuir embrião" que já
  existe no card dela, na lista de Éguas de cria — Fase 11) ou uma nova, de fora da cabanha.
- **Nova flag permanente `animais.receptora_externa`** (migration
  `docs/migrations/2026-08-19-receptora-externa.sql`) — diferente do papel "receptora" ephemeral por
  ciclo (Fase 8b, derivado de `acasalamentos.receptora_animal_id`, nunca persistiu no cadastro), esta é
  uma flag de origem/propósito do CADASTRO em si: marca que aquele animal não é do plantel da cabanha, só
  existe pra receber embrião via TE, sob cuidado temporário. Setada automaticamente
  (`_escolherReceptoraNova()`) quando o cadastro é aberto por esse caminho — o formulário mostra um aviso
  roxo explicando isso antes mesmo de salvar.
- **Selo visual roxo "Receptora externa"** em todo lugar que mostra badges de animal — tabela, grade e
  ficha de detalhe — pra nunca confundir com um animal de verdade do plantel.
- **Sai sozinha quando a gestação encerra**: `_confirmarEncerramentoGestacao()` agora checa, ao registrar
  parto/aborto/perda, se o acasalamento tem `receptora_animal_id` e se aquele animal é
  `receptora_externa` — se for, muda a situação dela pra `TRANSFERIDO` automaticamente e persiste,
  tirando-a da listagem padrão de "Na Cabanha" sem precisar de ação manual. Uma receptora "de dentro"
  (égua de verdade do plantel que emprestou o útero) não é afetada — continua normalmente, ela é um
  animal real da cabanha.
- Testado via servidor estático local + browser: modal de escolha abre e direciona corretamente pros
  dois caminhos; cadastro novo com a flag mostra o aviso e salva `receptora_externa: true`; badge roxo
  aparece na grade; encerrar a gestação (testado com status "perdida") muda a situação da receptora pra
  Transferido e ela some da listagem padrão de animais ativos.

### Fase 14 — cadastro dedicado de receptora, persistência confiável de Cota/Cobertura, badges de origem chamativos, embrião próprio vinculado (2026-08-19)

Pedro reportou quatro pontos depois de usar o sistema: (1) "+ Adicionar receptora" reaproveitava o modal
genérico "Cadastrar animal", que mostra campos sem sentido pro caso (Castrado, só se aplica a macho); (2)
uma fonte de Cota/Cobertura cadastrada não persistia — sumia depois de um F5; (3) o badge de origem do
garanhão (Próprio/Cota/etc.) ficava pouco evidente; (4) o embrião "próprio" precisa poder vir de uma égua
da cabanha em **qualquer estágio** (não só "Cria"), e ao atribuir o embrião a uma receptora, a doadora já
devia vir resolvida — sem perguntar de novo o que o cadastro do embrião já respondeu.

- **Cadastro dedicado de receptora** (`modal-nova-receptora`, `salvarNovaReceptora()`): só os campos que
  fazem sentido (Nome, SBB com busca ABCCC, Pelagem, Nascimento, Observações) — sexo e estágio fixos
  (Fêmea/Cria) por trás, sem aparecer no formulário. `_escolherReceptoraNova()` abre esse modal em vez do
  genérico `modal-novo`; o aviso roxo "fica sob cuidado só enquanto gestante" virou parte do próprio
  cabeçalho do modal novo, e o código órfão que ele deixava no `modal-novo` (aviso, flag
  `window._novoAnimalReceptoraExterna`) foi removido.
- **Persistência de Cota/Cobertura corrigida de verdade**: `salvarFonteCobertura()` virou `async`,
  **aguarda** a confirmação do banco (`_dbSalvarFonteCobertura()` agora retorna `true`/`false`) antes de
  fechar o modal — antes fechava e limpava a tela assumindo sucesso sem checar a resposta real, então uma
  falha silenciosa (sessão, rede, RLS) fazia o registro sumir depois de um F5 sem ninguém saber. Agora, se
  falhar, o modal continua aberto com os dados preenchidos e um aviso claro pra tentar salvar de novo.
- **Badge de origem mais chamativo**: trocado de badge pastel (`bg`/`ba`/`bb`/`bgr`, fundo claro) pra cor
  sólida com texto branco (`_origemBadge()`) — Próprio=verde, Cota=âmbar, Direito de uso=azul,
  Cobertura=rosa. Bem mais fácil de bater o olho e saber a origem do garanhão sem ler o texto.
- **Embrião próprio vinculado a um animal de qualquer estágio**: modal "Nova cota / cobertura", tipo
  Embrião, ganhou escolha de origem — "Égua própria da cabanha" (select de qualquer fêmea cadastrada, sem
  filtro de estágio — testado com uma égua em "Pista Funcional") ou "Adquirido (externo)" (nome/SBB livre,
  igual Direito de uso/Cobertura). Nova coluna `fontes_cobertura.doadora_animal_id` (migration
  `docs/migrations/2026-08-19-embriao-doadora-animal.sql`, nullable, FK pra `animais`) guarda esse
  vínculo quando é "própria".
- **`_abrirAtribuirEmbriao()` não pergunta duas vezes**: ao escolher um embrião com `doadora_animal_id`
  preenchido, o select "Égua doadora" já vem travado nela sozinho (`_embFonteChange()`), com uma dica
  explicando que já foi definida no cadastro do embrião — só embrião "adquirido" (sem vínculo) continua
  pedindo a doadora manualmente.
- Testado via servidor estático local + browser: modal dedicado de receptora sem nenhum campo de macho;
  embrião próprio aceita doadora em estágio "Pista Funcional" (não só Cria); ao atribuir esse embrião, a
  doadora vem pré-travada com a dica certa; badges de origem renderizam com cor sólida bem visível.

### Fase 15 — receptora nunca é doadora + cadastro de animal confirma persistência de verdade (2026-08-19)

Pedro reportou o mesmo erro de "Não foi possível salvar" ao tentar atribuir um embrião logo depois de
cadastrar uma receptora nova, e que a lista de "égua própria" pro embrião mostrava a receptora recém
cadastrada — o que não faz sentido (uma receptora carrega o embrião de outra, nunca é doadora do próprio).

- **Causa raiz real**: o cadastro de animal (`salvarAnimal()`/`salvarNovaReceptora()`) tinha o mesmo
  problema já corrigido na Fase 14 pras fontes de cobertura — fechava o modal e limpava a tela **sem
  confirmar** que o POST realmente chegou no banco. Se falhasse (sessão, rede), o animal ficava só na
  memória, sem `db_id` real — e qualquer tela que dependesse desse `db_id` depois (como escolher a
  doadora de um embrião) quebrava longe da causa raiz, com um erro que não tinha nada a ver com embrião.
- **Corrigido**: `_dbSalvarAnimal()` agora retorna `true`/`false`; `salvarAnimal()`, `salvarNovaReceptora()`
  e `salvarEdicaoAnimal()` viraram `async` e só fecham o modal/voltam pro modo leitura se o banco
  confirmou de verdade. Se falhar, desfaz o registro criado localmente (evita "fantasma" sem id real) e
  avisa claramente pra tentar salvar de novo — mesmo padrão já usado em `salvarFonteCobertura()`.
- **Receptora nunca aparece como doadora**: tanto o select "Égua própria da cabanha" (cadastro de
  embrião) quanto o select "Égua doadora" (`_abrirAtribuirEmbriao`, caminho de embrião adquirido) agora
  excluem qualquer animal com `receptora_externa=true` — ela só carrega o embrião de outra égua, nunca é
  a dona genética dele. Se a intenção fosse cruzá-la de verdade, isso é um acasalamento normal, não uma
  atribuição de embrião.
- Testado via servidor estático local + browser: receptora cadastrada some da lista de doadoras próprias;
  simulado POST falhando (401) e depois com sucesso — na falha, o registro é desfeito localmente e o
  modal continua aberto; no sucesso seguinte, persiste com `db_id` real e fecha.
