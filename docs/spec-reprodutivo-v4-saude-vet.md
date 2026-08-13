# Spec — Reprodutivo v4 + Saúde & Vacinas (revisão pós-reunião com o sócio)

> **Status: rascunho, aguardando revisão do sócio (Thiago).** Este documento organiza as anotações da
> reunião de 2026-08-12 entre Pedro e Thiago, revendo o módulo Reprodutivo (v3, recém lançado —
> `docs/spec-reprodutivo-v3.md`) e a tela de Saúde & Vacinas. **Não é uma spec fechada** — várias decisões
> ficaram em aberto ou incompletas na anotação original (marcadas com ❓) e precisam da revisão do Thiago
> antes de virar plano de fases. Depois de revisado, quebrar em fases seguindo o padrão da v3.

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

- **Campo "castrado"** no cadastro de machos. Quando marcado, o animal **não aparece** como opção no
  planejador de ciclo do Reprodutivo.
  - ❓ **A definir com o sócio:** o campo bloqueia só a entrada em *novos* planejamentos, ou também esconde
    o animal de telas de histórico reprodutivo? (assumir "só bloqueia novo planejamento" até confirmação —
    dado histórico não deveria sumir).

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

**Regra de bloqueio (importante):** uma gestação ativa do ciclo atual que ainda não teve a cria
informada (nem nascimento, nem perda) **impede** o criador de finalizar/enviar o planejamento do próximo
ciclo pro veterinário — mesmo que ele tente. Só libera depois que a gestação correspondente for encerrada
(sinalizando cria nascida ou perdida).

- ❓ A anotação original menciona "ter uma visão do criador com apelo gráfico magnífico" pra gestações — não
  ficou claro se isso é só o estilo de card da aba 1, ou uma tela/dashboard extra separada. Confirmar com o
  Thiago.

### 3.2 Aba "Plantel disponível" (posição ainda em aberto)

Lista tudo disponível pra uso no ciclo: garanhões, éguas de cria, cotas de cobertura, embriões etc.

- ❓ **A definir:** vira uma aba própria (3ª/4ª posição) ou fica fundida dentro da aba de Planejador (3.1,
  item 2)? A anotação original registra as duas possibilidades sem decidir.

### 3.3 Fontes de Cobertura → renomear e reestruturar

- **Falta um tipo de fonte**: hoje só existe Próprio / Cota / Direito de uso — falta **"Cobertura"** como
  tipo (cobertura comprada avulsa, sem ser cota nem direito de uso recorrente).
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
  (cria nascida ou gestação perdida — ver regra de corte na seção 4.4).

### 3.5 Receptoras — revisar fluxo (pouco detalhado, precisa de esclarecimento)

- Rever: (a) adicionar égua de **outra cabanha** como receptora, e (b) definir uma égua **própria** como
  receptora.
- ❓ **A anotação não detalha o que exatamente está errado.** Um dos prints da reunião mostra um cadastro de
  animal com "Receptora (TE)" digitado livremente no campo de Observações — sugere que hoje isso é tratado
  como texto solto em vez de um conceito estruturado (campo/flag própria), mas isso é inferência, não foi
  dito explicitamente. **Marcar como pendente de esclarecimento direto com o Thiago antes de especificar.**

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

## Perguntas em aberto (revisar com o Thiago antes de especificar fases)

1. Campo "castrado" (seção 2) — bloqueia só planejamento novo, ou esconde de tudo?
2. "Visão do criador com apelo gráfico" (seção 3.1) — é o estilo de card da aba 1, ou uma tela extra?
3. Aba "Plantel disponível" (seção 3.2) — aba própria ou fundida no Planejador?
4. Nome final pra "Fontes de Cobertura" renomeada (seção 3.3) — sugestão "Garanhões e Coberturas", confirmar.
5. Receptoras (seção 3.5) — a anotação não diz o que está errado no fluxo atual; pedir pro Thiago detalhar
   com um exemplo concreto do que tentou fazer e não funcionou/fez sentido.
6. Corte 30/06→01/07 (seção 4.3) — confirmar se reaproveita a regra de corte de ciclo já existente.

## Próximos passos

1. Thiago revisa este documento e responde as perguntas em aberto (acima).
2. Com as respostas, quebrar em fases de implementação — separando o que é **mudança de fluxo/UI** (baixo
   risco, reaproveita schema existente: reordenar abas, renomear campos, remover "marcar como reprodutora",
   corrigir o bug do formulário) do que precisa de **schema novo** (estágios do Kanban veterinário,
   categoria "Tratamentos", quantidade-padrão de coberturas no cadastro de animal).
3. Seguir o formato de fases de `docs/spec-reprodutivo-v3.md` (spec fechada → fases numeradas → cada fase
   testada isoladamente antes da próxima).
