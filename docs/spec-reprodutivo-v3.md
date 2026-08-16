# Spec — Reprodutivo v3 (unificação Gestação + Reprodutivo, planejamento por ciclo)

> **Status: spec fechada, pronta pra desenvolvimento.** Requisitos (seções 1-6), decisões de produto (seção 7),
> levantamento de schema + conflitos resolvidos (seção 8) e fases de implementação (seção 10) completos. Um
> único ponto secundário segue em aberto (empilhar ou não os bônus de `tem_rm`+`demerito`, seção 10/Fase 0) —
> não bloqueia o início do trabalho.

## 1. Problema

Hoje existem **duas telas paralelas e defasadas** — "Reprodutivo" e "Gestação" — cobrindo o mesmo domínio de
forma inconsistente, confundindo o usuário sobre onde fazer o quê. A aba "Gestação" (v2, da sessão de
Reprodução Equina) já é onde cabanheiro/gerente/dono efetivamente planejam o ciclo reprodutivo; a aba
"Reprodutivo" ficou para trás e hoje pede dados que não fazem sentido pro fluxo real (registro de cobertura
com campos desnecessários).

Esta é considerada **a funcionalidade mais estratégica do produto** — a que mais justifica a assinatura,
o "brincar de deus" do dono da cabanha planejando o futuro do plantel. Merece prioridade e um desenho único,
não dois fragmentos.

## 2. Objetivo desta revisão

Unificar tudo em **uma única tela** ("Reprodutivo", substituindo as duas atuais), organizada em torno do
conceito de **Ciclo Reprodutivo** — com uma aba pro ciclo atual (gestações em andamento) e a possibilidade de
já planejar o próximo ciclo, mesmo com éguas ainda prenhas do ciclo atual.

## 3. Conceito central: Ciclo Reprodutivo

- Um ciclo é nomeado pelo período de **cobertura**, não de nascimento — ex.: ciclo **25/26** é quando as
  coberturas acontecem; os nascimentos resultantes caem no ciclo seguinte, **26/27**.
- A tela deve permitir acompanhar o ciclo atual **e** planejar o próximo em paralelo. Uma égua prenha no
  ciclo atual não pode virar "inseminação" (ela está de cria), mas o sistema deve permitir **planejá-la** já
  para o próximo ciclo — quanto antes o planejamento for liberado pro veterinário, melhor pro cliente.
- ❓ **A definir:** como o sistema decide quando um ciclo "vira" o atual (data de corte? ação manual do
  admin encerrando o ciclo anterior — já existe uma funcionalidade de "encerramento de ciclo" da Fase 8 do
  módulo anterior, avaliar se reaproveita)? Quantos ciclos futuros podem coexistir planejados ao mesmo tempo
  (só o próximo, ou N)?

## 4. Ponto de partida do planejamento: o cadastro de Animais

Tudo no planejamento do ciclo nasce do que já está cadastrado na aba Animais — o Reprodutivo não deve
duplicar cadastro, só **completar com informações que são específicas do ciclo** (não do animal em si).

### 4.1 Garanhões (reprodutores)

- Animal cadastrado como reprodutor (macho, >20 meses) aparece disponível no **planejador de ciclo**, não na
  aba Animais.
- No planejador, o admin informa **quantas coberturas daquele garanhão usar naquele ciclo específico** —
  limite regulatório: até **120 coberturas/ano**, ou **240 se o garanhão for registrado como Demérito**.
  O valor pode ser menor que o limite máximo (ex.: cotas vendidas a terceiros reduzem a disponibilidade real
  pra cabanha) — quem decide o número disponível é o admin, por ciclo.
- Conforme coberturas vão sendo lançadas no ciclo, o sistema **desconta** do saldo informado (contador
  regressivo, por garanhão, por ciclo).
- ❓ **A definir:** o sistema deve *bloquear* lançar mais coberturas que o saldo informado, ou só avisar/permitir
  passar do limite com confirmação? O status "Demérito" já existe em algum campo do cadastro do animal, ou
  precisa ser adicionado?

### 4.2 Confirmação de animal (pré-requisito, mexe na aba Animais)

- Hoje não existe conceito de "confirmação" no cadastro de animal. Confirmação = um técnico valida que o
  animal é Crioulo com pedigree confirmado e medidas dentro do padrão.
- Regra: **só pode confirmar a partir de 2 anos de idade**.
- Adicionar ao cadastro/edição de animal (aba Animais) um campo **Confirmado: sim/não**, selecionável pelo
  usuário — respeitando a regra de idade mínima.
- ❓ **A definir:** o app deve *impedir* marcar "confirmado" antes dos 2 anos (validação bloqueante), ou só
  avisar? Confirmação afeta elegibilidade pra reprodução (ex.: só confirmados entram no planejador) ou é só
  um dado informativo por enquanto? Isso conecta com o item já registrado no `ROADMAP.md` ("Campo 'situação'
  e 'data de confirmação' no cadastro de novos animais") — tratar como o mesmo item, não duplicar.

### 4.3 Éguas — três origens possíveis no planejador

O planejador de ciclo precisa aceitar égua reprodutora de três origens, todas configuradas **no menu de
Reprodutivo, por ciclo** — nunca fixo no cadastro do animal, porque isso muda ciclo a ciclo:

1. **Égua de cria já cadastrada na cabanha** (aba Animais) — no planejador, o admin escolhe se ela será
   reprodutora *naquele ciclo*.
2. **Égua receptora** — égua que recebe embrião de outra (fêmea doadora + sêmen de outro garanhão), comum em
   TE (transferência de embrião). Cadastro pelo **SBB** da receptora, associando-a ao ciclo.
3. **Cobertura comprada** — registro de cobertura adquirida (hoje sem sentido no cadastro atual, que pede
   dados errados). Deve puxar os dados **do SBB**, não formulário manual solto.

Resumo do fluxo: ao iniciar/abrir o planejador de um ciclo, o sistema carrega o que já existe cadastrado na
cabanha (garanhões, éguas de cria) e oferece **completar** com o que falta (coberturas compradas, receptoras)
— todas essas opções ficam disponíveis pra seleção dentro do mesmo fluxo de planejamento.

## 5. Remover / substituir

- **Excluir** a funcionalidade atual de registro de cobertura da aba Reprodutivo (pede campos que não fazem
  sentido pro fluxo real).
- Substituir por lançamento de cobertura **puxando do SBB** (garanhão e, quando aplicável, égua/receptora).

## 6. Fora de escopo desta rodada (registrado pra não perder, não construir agora)

- **Marketplace de coberturas entre cabanhas**: um usuário lançar a venda de uma cobertura e ela cair, para a
  cabanha compradora, como um aceite + cadastro da quantidade comprada — via integração entre tenants dentro
  do próprio Mimba. Ideia registrada, **não entra nesta rodada**.

## 7. Decisões (respondidas em 2026-08-02)

1. **Transição de ciclo**: **data de corte fixa**, não ação manual. Ciclo reprodutivo vai sempre de
   **julho a junho**, nomeado pelo ano da cobertura → ex. ciclo **25/26** (coberturas jul/25–jun/26) gera as
   crias do ciclo **26/27**. A troca de "atual" é automática por data: em qualquer momento a partir de 1º de
   julho, o ciclo que começa nessa data vira o atual. Exemplo prático (hoje, 2026-08-02): estamos dentro do
   ciclo **26/27** (atual), e o **27/28** já pode estar sendo planejado em paralelo.
2. **Ciclos paralelos**: só **dois** de cada vez — o atual e o próximo. Nunca mais que isso.
3. **Estouro de saldo de coberturas**: **não bloqueia** — só **avisa de forma bem incisiva** (visualmente
   evidente, não um toast discreto) ao ultrapassar o saldo informado pro garanhão naquele ciclo.
4. **Cotas/Demérito**: sem integração externa por enquanto — **o próprio usuário informa manualmente**, no
   cadastro do animal (aba Animais), a quantidade de cotas/coberturas disponíveis daquele garanhão; o
   planejador do ciclo vai consumindo esse saldo conforme lança coberturas.
5. **Confirmação de animal**: **não bloqueia** nada — é só orientação/aviso. Um animal não confirmado (ou
   com menos de 2 anos) pode ser usado no planejamento normalmente; a responsabilidade é do dono da cabanha.
6. **Receptora/cobertura via SBB**: reaproveitar **exatamente** a mesma integração/mecanismo já usado no
   link SBB→ABCCC e na importação de animais por lista de SBB — sem construir uma integração nova.
7. **Dados/telas atuais do "Reprodutivo"**: **arquivar**, não descartar de vez — motivo explícito: garantir
   que, se os sócios identificarem depois que algum recurso importante foi cortado, dá pra recuperar. (Ver
   nota de implementação abaixo — provavelmente renomear/mover tabelas em vez de `DROP`, nunca apagar dado.)

## 8. Levantamento do schema atual (2026-08-02)

Tabelas em `public` (template, clonado em cada `cab_<slug>`) relevantes ao domínio:

| Tabela | O que guarda hoje |
|---|---|
| `fontes_cobertura` | Já é quase exatamente o conceito de "saldo de coberturas por ciclo" pedido na spec: `tipo` (`proprio`/`cota`/`direito_uso`), `garanhao_nome`/`garanhao_sbb`, `tem_rm` (bool), `quantidade_adquirida`, `ciclo` (texto), `vigencia_inicio/fim`, `proprietario_cota`, `percentual_cota`, `status` (`ativa`/`vencida`). |
| `acasalamentos` | Lançamento de cobertura em si: `egua_id`, `fonte_cobertura_id`, `tipo_cobertura`, `ciclo`, `status` (`rascunho`/`em_curso`/`confirmado`/`cancelado`), aprovação (`aprovado_em/por`). |
| `tentativas` | Tentativas dentro de um acasalamento (inseminação/diagnóstico), com veterinário e resultado. |
| `gestacoes` | Uma gestação confirmada, ligada a um `acasalamento_id` — datas de cobertura/confirmação/parto, protocolo aplicado. |
| `protocolos_reproducao` | Protocolos reutilizáveis (etapas em jsonb). |
| `coberturas_negociadas` | **Marketplace entre cabanhas já existe**: `fonte_cobertura_id`, `quantidade`, `comprador_tenant_id`/`nome`/`contato`, `valor_total`, `parcelas` (jsonb), `status` (`pendente`/`aceito`/`quitado`/...). |
| `coberturas` | Tabela **antiga** (pré-v2), campos soltos (`egua_nome`, `garanhao` texto livre, `sbb_padrillo`, `cria_nome`/`sexo` direto na linha) — é a que a spec pede pra **arquivar** (seção 7, item 7). |
| `animais` | Sem campo de reprodutor/cotas, sem campo de confirmação — só `situacao`, `estagio`, `status_cadastro`, `sexo`, `nasc`, `sbb`. Confirma que os dois campos novos da spec (seção 4.1 e 4.2) realmente não existem ainda. |

RPCs/funções já implementadas:
- `_calc_ciclo_texto(data)` — calcula o texto do ciclo (`"25/26"`) a partir de uma data.
- `encerrar_ciclo_reproducao()` — rotina (chamada por cron, `SECURITY DEFINER`, roda pra **todos os tenants**) que
  a cada virada de ciclo: vence fontes de cobertura própria com saldo (indevidamente, hoje — ver conflito 1
  abaixo), cancela acasalamentos `em_curso` não confirmados, **recria automaticamente** uma fonte de cobertura
  nova pro ciclo seguinte por garanhão (`120` coberturas, ou `150` se `tem_rm=true`), vence cotas/direitos de
  uso com `vigencia_fim` expirada.
- `negociar_cobertura_mimba` / `aceitar_negociacao_cobertura` / `recusar_negociacao_cobertura` /
  `buscar_tenant_para_negociacao` — fluxo completo de venda/aceite de cobertura **entre cabanhas diferentes do
  Mimba**, já funcionando.

### Conflitos com as decisões da seção 7 — resolvidos em 2026-08-02

1. **✅ Corte do ciclo: muda pra julho.** `_calc_ciclo_texto` passa de `month >= 8` pra **`month >= 7`**.
   Como essa função já roda em produção via cron (`encerrar_ciclo_reproducao`) pra todos os tenants, é
   migration simples na função — mas **atenção no dia do deploy**: rodar fora da janela de virada de ciclo
   (não fazer isso em julho de um ano real sem revisar o que já foi criado com o corte antigo).
2. **✅ Investigado — `tem_rm` NÃO tem relação com Demérito.** Confirmado no código-fonte
   (`index.html`, checkbox `#fc-tem-rm`): o rótulo é **"Reserva de material (RM)"**, um conceito de reserva de
   sêmen/material genético — sem nenhuma ligação com a classificação Demérito da ABCCC. É só uma coincidência os
   dois hoje darem bônus parecido (RM libera 150 em vez de 120). **Decisão**: `tem_rm` continua existindo como
   está (não mexe); Demérito vira um **campo novo e independente** em `fontes_cobertura` (ex.: `demerito
   boolean`), que sozinho eleva o teto de 120 pra 240. ❓ Combinação `tem_rm=true` + `demerito=true` ao mesmo
   tempo: soma os dois bônus, ou o maior teto (240) já cobre tudo? Decidir na fase de implementação, não é
   bloqueante pra desenhar o resto.
3. **✅ Marketplace fica exposto.** A tela nova de Reprodutivo vai dar acesso ao fluxo de
   `negociar_cobertura_mimba`/`aceitar_negociacao_cobertura` (venda/compra de cotas entre cabanhas) e à
   marcação automática que ele já habilita — não é preciso construir nada novo de backend pra isso, só desenhar
   a UI que hoje não existe pra esse fluxo.
4. **✅ Herança automática mantida, com edição manual liberada.** `encerrar_ciclo_reproducao` continua recriando
   a fonte de cobertura do ciclo novo herdando do ciclo anterior (comportamento atual, sem mudar a rotina) — o
   admin só precisa poder **editar manualmente** depois (garanhão trocou de cota disponível, ou a cabanha
   adquiriu mais coberturas entre um ciclo e outro). Isso já é possível hoje via `editFonteCobertura` — não
   precisa de mudança de banco, só garantir que a tela nova deixa essa edição visível e óbvia no fluxo do
   planejador (não escondida numa tela separada de "fontes de cobertura" como está hoje).

## 9. Nota de síntese (onde vive o saldo de coberturas)

A resposta à pergunta 4 original ("usuário informa manualmente a quantidade de cotas do animal **ao
cadastrar na aba de animais**") parecia contradizer a seção 4.1 ("isso não pode ficar na aba de Animais,
tem que ficar no planejador, porque muda por ciclo"). Resolvido pela decisão 4 da rodada seguinte ("herda do
ciclo anterior, edita manualmente") + pelo schema já existente (`fontes_cobertura` já é por-ciclo, com
`ciclo` como coluna): **o saldo/cota vive em `fontes_cobertura` (por ciclo), nunca na tabela `animais`**. O
garanhão em si (nome/SBB) continua vindo do cadastro em Animais — só o número de coberturas disponíveis
naquele ciclo específico é que é configurado (e herdado/editado) no planejador. Sem conflito real, só
imprecisão de linguagem na resposta — sinalizando aqui pra não haver dúvida na hora de implementar.

## 10. Fases de implementação

### Fase 0 — Fundação de banco ✅ APLICADA (2026-08-02)
Migration `docs/migrations/2026-08-02-reprodutivo-fase0.sql` aplicada e verificada nos 7 tenants provisionados
(`cab_cabanha_santa_adelina`, `cab_mae_de_deus`, `cab_cabanha_santa_enoema`, `cab_qa_isolamento`,
`cab_qa_segunda`, `cab_cabanha_pedro_teste`, `cab_cabanha_pedro_teste_completo`) + template `public`. Bônus de
`tem_rm`+`demerito` **empilha** (120 base, +30 tem_rm, +120 demerito, até 270) — confirmado com o Pedro.

<details><summary>Escopo original da fase (referência)</summary>

(migrations, reflete em todos os `cab_*` via skill `nova-migration-tenant`)
- `animais`: nova coluna `confirmado boolean not null default false` (sem `data_confirmacao` obrigatória por
  ora — só o flag, ver Fase 1).
- `fontes_cobertura`: nova coluna `demerito boolean not null default false` (independente de `tem_rm`).
  Ajustar a lógica de teto (hoje só `tem_rm` → 150) pra: base 120, +120 se `demerito` (total 240), `tem_rm`
  mantém seu efeito atual **separado** (❓ empilha ou não — decidir aqui, é o único ponto ainda em aberto,
  não bloqueia o resto da fase).
- `_calc_ciclo_texto`: trocar corte de `month >= 8` pra `month >= 7`. Revisar dados já gerados com o corte
  antigo antes de aplicar (não deve haver nenhum ciclo "errado" ainda, já que a virada real de julho/26 só
  aconteceu recentemente — checar).
- `coberturas` (tabela legada): renomear pra `coberturas_arquivadas_legado` em cada schema `cab_*` existente
  (não `DROP`) + remover do template `public` a versão "ativa" (a tabela de arquivo não precisa existir no
  template, só nos tenants que já tinham dado). Revisar grants (não expor a tabela arquivada via API).
- Revisão de isolamento (`revisor-isolamento`) obrigatória nesta fase — mexe em template + reflexo cross-tenant.

</details>

### Fase 1 — Confirmação de animal (aba Animais)
- Campo "Confirmado" (sim/não) no formulário de cadastro/edição de animal — sem bloqueio de idade, só aviso
  visual se `nasc` indicar menos de 2 anos e o usuário marcar confirmado mesmo assim (banner de alerta, não
  impede salvar — decisão 5).
- Badge "Confirmado"/"Não confirmado" na listagem de Animais e na ficha de detalhe.
- Fecha também o item pendente equivalente já registrado no `ROADMAP.md`.

### Fase 2 — Planejador de ciclo (núcleo da tela nova) ✅ APLICADA (2026-08-02)
Nova aba **"Planejador de ciclo"** dentro da página Reprodutivo (primeira/padrão), reaproveitando toda a
infra de `fontesCobertura`/modal já existente do módulo de Reprodução Equina v2 em vez de recriar CRUD:
- Seletor de ciclo com no máximo 2 opções (decisão 2): "Ciclo atual" e "Próximo ciclo", calculados no
  frontend por `_cicloAtualTexto()`/`_cicloProximoTexto()` (espelham o corte de julho do `_calc_ciclo_texto`
  do banco, Fase 0).
- Painel de garanhões: `animais.filter(sexo==='Macho' && isNaCabanha && idade≥20 meses)`. Pra cada um, busca a
  `fonte_cobertura` (tipo `proprio`) do ciclo selecionado (por SBB, com fallback pro nome) — se existir, mostra
  saldo (usado/negociado/disponível), badges RM/Demérito e botão "Editar saldo do ciclo" (abre o modal já
  existente, `editFonteCobertura`); se não existir ainda, mostra "+ Definir saldo deste ciclo" (pré-preenche
  o modal com nome/SBB/ciclo via `_criarFonteParaGaranhao`).
- Aviso incisivo ao estourar (decisão 3): `_saldoFonteCobertura()` foi corrigida — antes escondia o excedente
  atrás de `Math.max(0, ...)`; agora expõe `estourado`/`excedente` também, e tanto o planejador quanto o card
  antigo da aba "Fontes de Cobertura" mostram um banner vermelho fixo (não um toast) quando o saldo é
  ultrapassado. Nunca bloqueia o lançamento.
- Campo `demerito` exposto no modal de fonte de cobertura (checkbox ao lado do já existente "Reserva de
  material (RM)"), persistido e lido em todos os pontos (`_dbSalvarFonteCobertura`, bootstrap,
  `_recarregarFontesCobertura`).
- Testado via servidor estático local + sessão injetada: garanhão sem fonte, com saldo normal e com saldo
  estourado; troca de ciclo; pré-preenchimento do modal a partir do planejador.
- **Não fechado nesta fase** (fica pra Fase 5, por decisão de escopo): a tela "Gestação" e as demais abas de
  "Reprodutivo" (Crias por ciclo, Matrizes, Reprodutores, Coberturas) continuam coexistindo por enquanto —
  o corte final das telas antigas é o item da Fase 5.

### Fase 3 — Éguas e origens de cobertura (dentro do planejador) ✅ APLICADA (2026-08-02)
- **Éguas de cria**: nova seção no planejador (`renderEguasCriaPlanejador`) lista `animais.filter(sexo==='Fêmea'
  && isNaCabanha && estagio==='CRIA')`. "Reprodutora neste ciclo" **não é um campo novo** — é derivado de existir
  (ou não) um `acasalamento` não-cancelado dessa égua nesse ciclo, evitando duplicar estado. Marcar abre o modal
  de acasalamento já existente com a égua pré-selecionada e as fontes filtradas pro ciclo do planejador
  (`_marcarEguaReprodutora`); desmarcar reusa `acasCancelar` (exige motivo, preserva histórico).
- **Receptora via SBB**: botão "+ Adicionar receptora (via SBB)" reaproveita o modal de cadastro de animal
  normal (`modal-novo`) pré-preenchido (sexo Fêmea, estágio CRIA, obs "Receptora (TE)") com foco no campo SBB —
  o autofill já existente (`_buscarAbccc('novo')`) faz o resto. Ao salvar, ela aparece automaticamente na lista
  de éguas de cria acima. Zero integração nova.
- **Cobertura comprada**: campo SBB no modal de fonte de cobertura agora busca o garanhão automaticamente
  (`_buscarAbcccParaFonte`, mesma edge function `buscar-abccc` usada em Animais) e preenche o nome — funciona
  pra qualquer tipo de fonte (`proprio`/`cota`/`direito_uso`), não só cobertura comprada.
- **Removido de vez**: modal `modal-cob` e a função `salvarCobertura()` (achado no caminho: essa função nem
  persistia no banco — só empurrava pro array local, dado se perderia ao recarregar a página). O botão
  "+ Registrar cobertura" saiu do cabeçalho e da aba "Coberturas", que agora é só consulta ao histórico
  arquivado (`coberturas_arquivadas_legado`, Fase 0), com aviso explicando a descontinuação.
- Testado via servidor local: égua sem plano → marcar reprodutora → fonte filtrada por ciclo → salvar → aparece
  como reprodutora no planejador; receptora pré-preenchida; botão/modal antigos confirmados removidos.

### Fase 4 — Marketplace entre cabanhas (expor o que já existe) ✅ APLICADA (2026-08-02)
**Achado ao iniciar a fase**: diferente do presumido no levantamento de schema (seção 8), o marketplace **já
tinha UI própria** desde a Fase 7 do módulo anterior — botão "Negociar" nos cards da aba antiga "Fontes de
Cobertura", e aceitar/recusar já funcionavam, só que enterrados dentro da página **Saúde → Pendências**
("Pendências sanitárias"), fora de contexto pra quem está pensando em Reprodutivo. O trabalho real desta fase
foi trazer esse fluxo pronto pra dentro do Planejador, não construir do zero:
- Botão "Negociar com outra cabanha" adicionado direto no card do garanhão no planejador (reaproveita
  `abrirModalNegociarCobertura` como está).
- Nova seção "Marketplace entre cabanhas" no planejador: **ofertas recebidas** (pendências tipo
  `negociacao_cobertura` não resolvidas, com Aceitar/Recusar reaproveitando `aceitarNegociacaoCobertura`/
  `recusarNegociacaoCobertura` — mesmas funções, só chamadas de um lugar novo) e **ofertas enviadas**
  (`coberturasNegociadas` com `status='pendente'`, lista somente-leitura).
- Zero mudança de RPC/banco, como previsto. As ofertas continuam também aparecendo em Saúde → Pendências
  (não removido de lá) — só passaram a ser alcançáveis também de onde fazem mais sentido.
- Testado via servidor local: oferta recebida com aceitar/recusar, oferta enviada com status, botão "Negociar"
  no card do garanhão abrindo o modal já preenchido com saldo/ciclo corretos.

### Fase 5 — Corte final e limpeza ✅ APLICADA (2026-08-02, QA local; QA em staging real ainda pendente)
Consolidação real (não só remoção): as duas páginas viraram uma.
- **Menu lateral**: item "Gestação" removido — só "Reprodutivo" (SVG já existente) fica.
- **Todas as abas da antiga Gestação foram migradas** (não descartadas) pra dentro de "Reprodutivo", como
  abas depois do Planejador: Acasalamentos (kanban), Gestações (dado real), Agenda reprodutiva, Fontes de
  Cobertura (histórico completo, todos os ciclos — complementa o Planejador, que só mostra 2), Protocolos,
  Nascimentos. Nenhuma função/id mudou de nome — só de página, então zero retrabalho de lógica.
- **"Gestações ativas" virou "Gestações legadas em aberto"**: filtra só o que ainda está `Prenha`/`Aguardando`
  na tabela arquivada (`coberturas_arquivadas_legado`), com aviso explicando que é legado e sem botão de criar
  novas — só editar/fechar o que já existia. **"Histórico de coberturas" foi removido** (100% redundante com
  "Histórico arquivado", que já mostra a mesma tabela por completo).
- **`abrirModalCobertura()` removida** (a última porta de criação de dado novo na tabela arquivada) —
  `editCobGest`/`excluirCobertura` continuam existindo pra fechar prenhezes legadas em aberto.
- **Achados corrigidos no caminho** (dado real que ficaria "congelado" silenciosamente se eu só tivesse
  removido a UI sem olhar o que dependia dela):
  - O alerta do Dashboard "Parto próximo/atrasado" só lia a tabela arquivada (`coberturas2`) — ganhou uma
    versão paralela lendo `gestacoes` (dado real), mantendo a legada só pra não sumir com o que já estava em
    aberto.
  - O card "Reprodução" na ficha de detalhe do animal (fêmea) tinha o mesmo problema — mesma correção.
  - Permissões por perfil (`PERMISSOES.veterinario`/`vet`/`cabanheiro`/`cab`) referenciavam a página
    `'gestacao'`, que deixou de existir — trocado por `'reprodutivo'`, preservando o nível de acesso que
    vet/cabanheiro já tinham (e como consequência inerente da fusão, ganham acesso também ao que só existia
    no antigo "Reprodutivo" — não dá pra ter permissão parcial dentro de uma página só).
  - Link "Ver gestação" (kanban de Protocolo Reprodutivo, na página Saúde) apontava pra
    `#page-gestacao .tab-row .tab:nth-child(7)` (seletor frágil, quebraria though com a nova ordem de abas) —
    trocado por um seletor por atributo (`[onclick*="gest-gestacoes"]`), mais robusto a reordenação futura.
- Testado via servidor local: as 12 abas trocam sem erro, dado real (`gestacoes`) e legado (`coberturas2`)
  aparecem corretamente nas abas certas, ficha de detalhe mostra a seção de gestação real, perfil `vet`
  mantém acesso à página fundida, nenhuma referência órfã a `page-gestacao`/`showPage('gestacao')`/
  `gest-historico`/`abrirModalCobertura` sobrou no código.
- **Pendente, não feito aqui**: QA ponta a ponta em `mimba-hml.pages.dev` com dado/login reais (login,
  planejar ciclo do zero, negociar entre duas cabanhas de teste de verdade) e o deploy pra produção — o que
  foi feito nesta fase foi construção + QA local (sessão fake via servidor estático), consistente com o
  padrão usado em todas as fases anteriores desta spec.

## 11. Dependências entre fases
Fase 0 é pré-requisito de todas as outras (schema). Fase 1 é independente e pode andar em paralelo à Fase 0.
Fases 2→3→4 são sequenciais (mesma tela, build incremental). Fase 5 só depois de 2, 3 e 4 estarem prontas e
testadas — é ela que remove as telas antigas, sem volta fácil se algo do planejador ainder estiver faltando.

## 12. Revisão final antes da Fase 5 (2026-08-02)

Antes do corte final, rodei uma checagem própria (sintaxe, ids duplicados, referências órfãs — tudo limpo) e
uma revisão de isolamento (`revisor-isolamento`) cobrindo o arco inteiro Fase 0→4. Achado real, corrigido:

**`_limparEstadoLocal()` não zerava os arrays de Reprodução/Marketplace** (`fontesCobertura`, `acasalamentos`,
`coberturasNegociadas`, `gestacoes`, `tentativas`, `coberturas` legado) — só eram zerados dentro de
`_sincronizarAoLogin` (assíncrono), deixando uma janela real em que trocar de cabanha (multi-tenant) e abrir
o Planejador **antes do sync terminar** mostrava dado da cabanha **anterior**, incluindo `comprador_nome`/
`comprador_contato`/`valor_total` de negociações de marketplace — dado de outra cabanha. Não é bypass de RLS
(o dado foi buscado legitimamente pra sessão anterior e ficou em memória), mas é vazamento visual entre
tenants. Existia antes da Fase 4, mas ficou mais exposto porque o Planejador virou a aba padrão de
Reprodutivo (menos cliques até esses dados que a antiga aba "Fontes de Cobertura" dentro de Gestação).
**Corrigido**: os 6 arrays entraram na lista zerada por `_limparEstadoLocal()`. Testado via servidor local
(popular os arrays, chamar `_limparEstadoLocal()`, confirmar os 6 zerados).

Demais pontos checados e aprovados: migration da Fase 0 (RLS/grants corretos, nenhum grant residual a
`anon`), remoção de `coberturas` do provisionamento (nenhuma referência órfã, tenants novos nascem sem a
tabela), exposição do marketplace na Fase 4 (zero RPC/policy nova, isolamento continua garantido pelo
banco), e a Fase 5 em si (nenhuma policy/trigger depende exclusivamente das telas antigas — pode remover a
UI sem afetar persistência/RLS).

Item fora do escopo desta migration, sinalizado pelo revisor mas não verificável via MCP (read-only): checar
manualmente no SQL Editor se algum schema `cab_*` mais antigo tem grant residual pra `anon` — a `Fase 0` não
reexecuta esse revoke (só `provisionar_schema_cabanha`, chamada só no provisionamento), mas também não
concede nada novo, então só é risco se já existisse antes, fora do escopo deste módulo.
