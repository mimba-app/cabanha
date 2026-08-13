# Spec — Reprodutivo v4 + Saúde & Vacinas (revisão pós-reunião com o sócio)

> **Status: revisado pelo Pedro e pelo Thiago (2026-08-12) — pronto para virar plano de fases.** Este
> documento organiza as anotações da reunião entre Pedro e Thiago revendo o módulo Reprodutivo (v3, recém
> lançado — `docs/spec-reprodutivo-v3.md`) e a tela de Saúde & Vacinas, e incorpora as respostas às
> perguntas que ficaram em aberto na primeira rodada. Restam só 2 pontos secundários sem decisão final (❓,
> seção "Perguntas em aberto") — não bloqueiam o início do trabalho.

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

### 3.3 Fontes de Cobertura → renomear e reestruturar

- **Falta um tipo de fonte**: hoje só existe Próprio / Cota / Direito de uso — falta **"Cobertura"** como
  tipo (cobertura comprada avulsa, sem ser cota nem direito de uso recorrente). Também falta **"Embrião"**
  (próprio ou comprado de outra cabanha) — ver detalhamento completo na seção 3.5 (Receptoras).
- **Renomear** o conceito/aba "Fontes de Cobertura" para algo como **"Garanhões e Coberturas"** (nome exato
  a validar).
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
- Nota de implementação: essa data de corte (30/06 → 01/07) parece ser a mesma regra de corte de ciclo em
  julho que já existe no sistema desde a Fase 0 do Reprodutivo v3 — provavelmente dá pra reaproveitar a
  lógica existente em vez de criar uma nova regra de data do zero. **Confirmar ao especificar a fase.**

## 5. Saúde & Vacinas — outras adições (fora do funil reprodutivo)

- **Nova categoria "Tratamentos"** — pra registrar que um animal se machucou, está em medicação X por um
  período determinado, etc. Hoje não existe um lugar pra isso (só Vacinação, Vermifugação, Exames).
- **Registro em lote pra Vacinas e Exames** — replicar o comportamento que já existe hoje só em
  Vermifugação (selecionar vários animais de uma vez e registrar a mesma vacina/exame pra todos).

---

## Perguntas em aberto (secundárias — não bloqueiam início do trabalho)

1. Nome final pra "Fontes de Cobertura" renomeada (seção 3.3) — sugestão "Garanhões e Coberturas",
   confirmar antes de nomear telas/campos na implementação.
2. Corte 30/06→01/07 (seção 4.3) — confirmar, ao especificar a fase, se reaproveita a regra de corte de
   ciclo já existente (Fase 0 do Reprodutivo v3) ou precisa de lógica própria.

Todas as demais perguntas da rodada anterior foram respondidas por Pedro/Thiago/Luciano em 2026-08-12 e
incorporadas nas seções correspondentes (castrado, apelo gráfico, regra de bloqueio, Plantel disponível,
receptoras).

## Próximos passos

1. Quebrar esta spec em fases de implementação — separando o que é **mudança de fluxo/UI** (baixo risco,
   reaproveita schema existente: reordenar abas, renomear campos, remover "marcar como reprodutora",
   corrigir o bug do formulário) do que precisa de **schema novo** (estágios do Kanban veterinário, flag de
   receptora + fonte "embrião", categoria "Tratamentos", quantidade-padrão de coberturas no cadastro de
   animal, flag "castrado").
2. Seguir o formato de fases de `docs/spec-reprodutivo-v3.md` (spec fechada → fases numeradas → cada fase
   testada isoladamente antes da próxima).
3. As 2 perguntas secundárias acima podem ser resolvidas durante a especificação da fase correspondente,
   sem precisar de nova rodada de revisão com o sócio.
