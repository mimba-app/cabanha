# Roadmap — pré-apresentação (quarta-feira, 2026-07-29)

> Levantado numa conversa com o sócio (2026-07-27) após feedback de uso real.
> Objetivo: vencer o máximo desta lista até quarta, na ordem de prioridade abaixo.
> Itens sem prioridade explícita ficam no fim, na ordem em que foram citados.

## Como usar este documento
- Cada item tem checkbox — marcar `[x]` ao concluir.
- "Onde mexe" aponta o ponto de partida no código (todo o frontend é `index.html`, sem framework).
- Ordem de prioridade é a ordem de trabalho recomendada — mas nada impede paralelizar se fizer sentido.

---

## 🔴 Prioridade 1 — Dashboard lento ✅
- [x] **Demora excessiva na tela de dashboard para carregar os dados sobre os animais.**
  Causa raiz medida com dados reais de rede: 12 requisições REST separadas no sync, cada uma
  disparando seu próprio preflight CORS — não era o banco (provado com `EXPLAIN ANALYZE`, poucos
  ms). Resolvido com a RPC `carregar_dados_cabanha` (1 requisição em vez de 12) + skeleton animado
  enquanto carrega. Ver memória `staging-e-isolamento-de-dados` / commits `perf:` na `staging`.

## 🔴 Prioridade 2 — Tela de conta centralizada + onboarding de usuário via Auth ✅
- [x] Tela de conta (modal "Conta", abas Cabanha/Usuários) acessível por um card no rodapé do
  menu lateral — avatar, nome, badge de perfil, botão "Sair" (vermelho, sempre visível) e ícone
  de engrenagem (SVG, estilo shadcn/ui) que abre as configurações.
- [x] Aba "Usuários" solta removida do menu lateral, unificada dentro da Tela de Conta.
- [x] **Convite de usuário corrigido** — nova edge function `convidar-usuario` cria identidade
  real no Supabase Auth + `tenant_memberships` + linha no schema, em vez de só uma linha local.
- [x] Achado extra do `revisor-isolamento` também corrigido: suspender/excluir usuário agora
  revoga o acesso de verdade (`tenant_memberships`), não só a linha local.
- [x] *(Achado maior, registrado para depois — ver memória `rls-permissiva-por-perfil`):* a RLS
  de todas as tabelas de tenant libera escrita a qualquer perfil, não só admin — não corrigido
  nesta rodada, precisa do `arquiteto`.

## 🔴 Prioridade 3 — Importação de animais por lista de códigos SBB ✅
- [x] Botão "📋 Importar por SBB" na página Animais — cola lista ou carrega `.txt`/`.csv`,
  deduplica, cruza contra SBBs já cadastrados, busca cada um novo na ABCCC (`buscar-abccc`, 3 em
  paralelo) com barra de progresso real, e insere tudo num único POST em lote.
- [x] `.xlsx` fica para depois (decisão consciente — evita introduzir a 1ª dependência externa
  do projeto sem necessidade imediata).
- [ ] *(Futuro — não entra nesta rodada):* puxar automaticamente todos os animais da cabanha via
  código/afixo na ABCCC e sugerir quais importar.

## 🔴 Prioridade 4 — Eventos não estão carregando ✅
- [x] Causa da **não-carga** encontrada e corrigida como efeito colateral da Prioridade 1: o
  PostgREST não reconhecia o relacionamento `eventos`→`eventos_animais` nesse schema
  (`PGRST200`). A RPC `carregar_dados_cabanha` monta esse vínculo manualmente em SQL.
- [x] **Confirmado ao vivo na Cabanha Mãe de Deus (2026-07-27)** pelo Pedro: os eventos que
  estavam sumidos voltaram a aparecer. Não era perda de dado na migração — era só o bug de
  leitura acima.

## 🔴 Prioridade 5 — Modal de detalhes do animal quebrado ✅
- [x] Causa do "texto colado" achada: `.ficha-row` (flex, label de largura fixa) estava dentro
  de um grid de 2 colunas, espremendo cada linha pela metade. Trocado por um grid de campos
  independentes.
- [x] Virou **página cheia** (`page-detalhe-animal`), com botão "← Voltar" — mesmo padrão de
  navegação das outras telas, em vez de modal de 900px.
- [x] Bônus: achado e corrigido um bug separado que deixava a seção "Eventos" do detalhe sempre
  vazia (`e.participantes`/`p.nome` vs. `e.animais`/`p.animal` — nomes de campo divergentes).
  Corrigir na origem também resolveu ~9 outros pontos de leitura no app (ranking Reprodutivo,
  busca da aba Eventos, timeline).

## 🔴 Prioridade 6 — Responsividade mobile quebrada ✅
- [x] Causa raiz medida em 375px (não suposição): nada travava `overflow-x` na raiz
  (`html`/`body`), então `.tab-row` (sub-abas tipo Vacinas/Exames/Vermifugação, sem quebra de
  linha nem scroll próprio) forçava a página inteira a crescer (scrollWidth chegava a 572px numa
  tela de 375px). Corrigido: trava `overflow-x:hidden` na raiz + `.tab-row` agora rola dentro de
  si mesma.
- [x] Menu lateral mobile **oculto por padrão**, com botão hamburger fixo que abre um painel
  suspenso (drawer) com overlay — fecha sozinho ao navegar ou tocar fora. Não disputa mais espaço
  fixo com o conteúdo (antes era uma barra de 60px só ícones sempre visível).
- [x] Testado em 375px: as 12 páginas + login sem overflow (`scrollWidth === innerWidth` em
  todas). Desktop confirmado sem regressão.

---

## Sem prioridade explícita (ordem em que foram citados — ficam para depois dos 6 acima)

- [x] **Tela de Animais (V1) — modernizar usando a tela de Gestações (V2) como referência de padrão.**
  Linha de métricas no topo (ativos/fêmeas/machos/rascunhos, mesmo padrão `.metrics` do Financeiro) + estado vazio
  quando o filtro não retorna nada. Tabela mantida (formato certo pra lista grande, não virou cards).
- [x] **Remover o recurso "salvar e carregar dados"** do menu lateral inferior esquerdo — resquício
  da versão antiga de importação por planilha, não é mais usado. *(Feito junto da Prioridade 2.)*
- [x] **Tela de Animais — edição sem confirmação e editável direto na "planilha" — concluído.** Causa raiz: colunas
  Situação/Estágio eram `<select onchange=...>` gravando direto no banco a cada troca, sem confirmação. Viraram
  badges somente-leitura (reaproveitando `sitb()`/`estb()`); editar agora exige clicar em "✏️" na linha, que abre a
  página de detalhe já em modo edição (reaproveita o fluxo Editar→Salvar/Cancelar que já existia desde a
  Prioridade 5, sem inventar um segundo padrão). De quebra, corrigido um bug cosmético achado no caminho: o mapa de
  cor do badge de situação (`sitb()`) usava chaves desatualizadas (`MORTO(A)`/`DOADO(A)`) que nunca batiam com o
  enum real (`MORTO`/`TRANSFERIDO`/`VENDIDO`), caindo sempre no cinza — corrigido.
- [x] **Bug de Gestação/Medidas não carregar na primeira visita — concluído.** Causa raiz
  reproduzida antes de corrigir: era uma corrida com o sync do login — se o usuário navegava pra
  Gestação/Medidas enquanto `_sincronizarAoLogin()` ainda estava em voo, a página renderizava com
  os arrays ainda vazios, e o sync (ao terminar) só re-renderizava Dashboard/Animais, nunca a
  página que o usuário estava vendo. Corrigido de forma abrangente: ao terminar o sync, re-renderiza
  a página que estiver ativa no momento (não só Gestação/Medidas — a mesma corrida podia afetar
  qualquer página visitada nesse intervalo).
- [x] **Aba de Medidas — layout modernizado.** Valores de medida (cernelha/tórax/canela) viraram badges/pills
  coloridos com ícone (reaproveitando a mesma paleta `.badge` verde/vermelho/âmbar do resto do app, em vez de só
  cor de texto crua) nas duas sub-abas (cards "Últimas medidas" e tabela "Histórico completo"). Adicionada linha de
  métricas no topo (ativos com medição / dentro do padrão / com medida abaixo / sem medição), mesmo padrão das
  telas mais novas. Só visual — nenhuma mudança de lógica de carregar/salvar.
- [x] **Link do SBB para a ABCCC concluído:** o link já existia (Matrizes e Animais), mas nunca
  funcionava de verdade — tentava injetar o SBB no DOM da popup via polling, bloqueado por
  cross-origin (restrição do navegador). Corrigido para montar um POST na própria página e
  submeter mirando a popup, exatamente os campos do formulário real da ABCCC. Testado contra o
  site real (curl) e no browser (mocks confirmando campos/target corretos).
- [x] **Campo "confirmado" no cadastro de novos animais — concluído (Fase 1 do Reprodutivo v3,
  2026-08-02).** Checkbox "Confirmado" no cadastro/edição de animal (`animais.confirmado`), sem
  bloqueio de idade — aviso não-intrusivo se marcado com menos de 2 anos (regra ABCCC: confirmação
  exige idade mínima de 2 anos, mas a responsabilidade pela informação é do dono da cabanha, decisão
  registrada em `docs/spec-reprodutivo-v3.md`). Badge "Confirmado" na listagem e nos dois modos
  (leitura/edição) da ficha de detalhe. Não tem `data_confirmacao` separada — só o flag por ora.
- [ ] **Buscar as medidas da confirmação** (altura, tórax, canela) direto da ABCCC para
  pré-preencher o cadastro de novo animal.
- [x] **Login concluído:** e-mail lembrado (localStorage, nunca a senha), botão de mostrar/ocultar
  senha, e sessão persistida entre recarregamentos — guarda `access_token`/`refresh_token`, renova
  silenciosamente no boot se expirado, cai de volta no login (com e-mail lembrado) se falhar.
  "Sair" limpa a sessão persistida de propósito.

---

## Notas de contexto (não fazer sem entender antes)
- Todo o frontend é um `index.html` único sem framework/bundler — qualquer mudança de UI é direto
  nesse arquivo. Deploy: só commitar o `index.html`, push na `main` (skill `deploy`).
- Mudanças que tocam **auth, provisionamento, RLS ou queries cross-schema** (caso do item de
  Prioridade 2 sobre convite de usuário) precisam passar pelo subagente `revisor-isolamento`
  antes de mergear — é regra do projeto (`CLAUDE.md`).
- Para investigar o bug de Eventos (Prioridade 4), começar pelo banco (schema
  `cab_mae_de_deus`) antes de mexer em código — precisa confirmar se é perda de dado ou bug de
  leitura antes de decidir o que corrigir.
