# Base de conhecimento do agente de IA — ajuda de uso do sistema

> Conteúdo curado, injetado inline no system prompt da Edge Function `agente-ia` (caso de uso 4:
> ajuda de uso). Não é dado de banco — é texto estático, versionado aqui, sem RPC nenhuma por
> trás. Mantém sincronizado com a estrutura real do `index.html`; não descrever funcionalidade que
> não existe.

## Visão geral

O Mimba organiza a gestão da cabanha em seções na barra lateral: **Dashboard**, **Animais**,
**Reprodutivo**, **Nutrição**, **Eventos**, **Estoque**, **Medidas**, **Financeiro**, **Sangues**
e **Relatórios**. Cada cabanha (tenant) só vê seus próprios dados — o agente nunca mistura dado de
uma cabanha com o de outra.

## Dashboard

Resumo geral: quantos animais ativos, proporção fêmeas/machos, vacinas urgentes (vencidas ou a
vencer em até 30 dias), quantos animais têm código SBB registrado na ABCCC, alertas prioritários
(vacinas/exames vencidos por animal) e situação do plantel.

## Animais

Cadastro e ficha de cada animal: nome, RP, código SBB, pelagem, data de nascimento, sexo,
situação (ativo/inativo), pai/mãe (por nome ou SBB), histórico de vacinas/exames/vermifugações,
medidas corporais e foto. Um animal pode ser marcado como receptora (para transferência de
embrião).

## Reprodutivo

Reúne o ciclo reprodutivo completo, em sub-abas:

- **Gestações ativas** — éguas atualmente gestantes, com data de cobertura, confirmação e parto
  previsto.
- **Planejador de ciclo** — organiza o que fazer em cada estágio reprodutivo do ciclo corrente.
- **Cruzamentos** (o "Conselho") — sugestão e análise de pares garanhão×égua já cobertos ou
  planejados na própria cabanha, considerando consanguinidade (parentesco) e diversidade
  genética, com uma pontuação de recomendação.
- **Protocolos** — protocolos de manejo reprodutivo (hormonais, indução) aplicáveis às éguas.
- **Crias por ciclo** — histórico de nascimentos agrupado por ciclo/temporada.
- **Plantel** — lista de matrizes e garanhões ativos na reprodução.

## Nutrição

Projetos nutricionais por animal (ração, suplementos, quantidades), templates reutilizáveis por
estágio (potro, gestante, atleta etc.) e lista de compras consolidada a partir dos projetos
ativos.

## Eventos

Calendário e histórico de eventos da cabanha (exposições, provas, treinos), organizados também
por animal e por resultado obtido.

## Estoque

Itens de estoque (ração, medicamentos, insumos), alertas de itens baixos, e movimentações de
entrada/saída.

## Medidas

Medidas corporais (altura, perímetro etc.) por animal, últimas e histórico completo.

## Financeiro

Lançamentos financeiros da cabanha (receitas/despesas).

## Sangues (genealogia ABCCC)

Consulta de ancestralidade de um animal via código SBB, buscando os dados públicos da ABCCC —
usado para compor a árvore genealógica e apoiar a análise de cruzamento.

## Relatórios

Relatórios exportáveis com os dados já cadastrados na cabanha.

## Conta e usuários

Administradores da cabanha podem convidar novos usuários (veterinário, cabanheiro ou outro
administrador) pela tela de Usuários — o convidado recebe um código de acesso por e-mail. Cada
usuário tem um perfil (`adm`, `vet`, `cab`) que define o que pode ver/editar.

## O que o agente NÃO faz

- Não modifica dado nenhum da cabanha (o agente é só consulta — cadastros e edições continuam
  sendo feitos pelas telas normais do app).
- Não tem acesso a dado de outra cabanha, nunca.
- Não substitui orientação veterinária profissional — sugestões de manejo/cruzamento são apoio à
  decisão, não prescrição.
