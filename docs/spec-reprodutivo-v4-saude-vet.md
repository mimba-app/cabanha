# Spec — Reprodutivo v4 + Saúde & Vacinas (revisão pós-reunião com o sócio)

> **Status: spec fechada, pronta pra desenvolvimento.** Revisada por Pedro, Thiago e Luciano em 2026-08-12.
> Todas as perguntas em aberto foram respondidas — as duas últimas ("Fontes de Cobertura" renomeada pra
> **"Garanhões e Coberturas"**; corte de perda de cria **reaproveita** a regra de corte de ciclo já
> existente) foram confirmadas por Pedro em 2026-08-12 e estão incorporadas abaixo.

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

### Fase 5 — Kanban do veterinário (Saúde & Vacinas → aba Reprodutivo)

A fase mais complexa da spec — avaliar, ao especificar em detalhe, se vale dividir em sub-fases (ex.:
5a — estágios 1-2, 5b — estágios 3-4 + regra de corte, 5c — atividades soltas + protocolo automático).

- 4 estágios do Kanban: Controle → Inseminação/Cruzamento → Ovuladas → DG precoce aguardando definitivo
  (seção 4.1), com transições de avanço/retorno conforme sinalização do veterinário.
- Migrar o campo "tipo de acasalamento" (IA/monta natural/TE) da aba Acasalamentos do criador pro estágio
  Controle do Kanban.
- Alertas visuais de janela: 3-7 dias (estágio 2), 15-20 dias (estágio 3), ~45 dias (estágio 4).
- Cards de égua com gestação ativa do ciclo atual aparecem **bloqueados** na coluna Controle (não movem até
  a gestação encerrar) — regra revisada da seção 3.1/4.1.
- Ação "devolver pro planejamento do criador", disponível em qualquer estágio.
- Registro de atividades soltas (medicação, toque, ultrassom, comentário) por acasalamento, em qualquer
  ponto do funil (tabela `reproducao_atividades`, Fase 0).
- Ao confirmar prenhez (fim do estágio 4): criar protocolo gestacional, reaproveitando "Protocolos" já
  existente em Saúde & Vacinas.
- Última etapa do funil: visão "Gestações ativas" em formato Kanban pro veterinário, pra continuar
  registrando atividades durante a gestação.
- Perda/nascimento de cria registrável a qualquer momento, por criador ou veterinário.
- Regra de corte 30/06→01/07 pra perda de cria (seção 4.3), **reaproveitando** `_calc_ciclo_texto`/
  `_cicloAtualTexto` já existente — perda antes do corte volta pro Controle (com opção de devolver ao
  planejamento); perda depois do corte só libera pro planejamento do próximo ciclo.

### Fase 6 — Saúde & Vacinas: Tratamentos + registro em lote

- Nova categoria **"Tratamentos"** (tabela `tratamentos`, Fase 0) — machucados, medicação por período etc.
- Registro em lote pra **Vacinas** e **Exames**, replicando o padrão que já existe em Vermifugação
  (selecionar vários animais, registrar o mesmo evento pra todos de uma vez).

### Fase 7 — Menu Animais

- Foto do animal no cadastro, visível na listagem.
- Redesenho da listagem pra grid/swimlane (menos "cara de planilha", mais detalhe por card/linha).
- Importação em lote por SBB (colar lista, ou subir `.txt`/`.csv`) — a variante "puxar lista completa do
  proprietário via ABCCC" fica de fora por ora (seção 6, fora de escopo).
