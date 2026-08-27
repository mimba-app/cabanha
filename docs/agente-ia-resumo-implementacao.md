# Agente Mimba — resumo da implementação (2026-08-27)

> Documento pra compartilhar o estado atual do agente de IA: o que ele sabe fazer, como foi
> construído, e o que falta pra ele estar 100% no ar.

## O que o agente faz hoje

O Agente Mimba é o chat flutuante do app (ícone no canto inferior direito, visível só logado).
Ele tem **dois "cérebros" que se conversam**:

### 1. Dado da própria cabanha
Responde perguntas sobre o que está cadastrado na cabanha do usuário: buscar um animal por
nome/SBB/RP, listar gestações ativas, resumir nascimentos/coberturas/vacinas num período. Só
enxerga a cabanha de quem está logado — nunca dado de outra cabanha.

### 2. Conhecimento da raça Crioula / ABCCC (novo — implementado agora)
Responde sobre genealogia, campeões e linhagens usando dado real da raça inteira, sincronizado
periodicamente de uma base analítica própria (o "Mimba Lab", onde carregamos catálogos de
finalistas 2020-2026 e histórico de campeões desde 1982, com pedigree de 5 gerações via ABCCC):

- **Linha alta e linha baixa** de um animal (o pai direto, e a mãe "que vem a ser" o avô materno)
  — no vocabulário de mercado, não em linguagem genérica de sistema.
- **Participações e colocações** nas 3 provas principais (Morfologia Expointer, Final Freio de
  Ouro, Doma de Ouro), com o peso certo (Grande Campeão pesa mais que finalista sem destaque).
- **Quantos finalistas um garanhão/égua já produziu** em cada prova — evidência concreta, contada
  de verdade no banco, nunca estimada.
- **"Linhagens em alta"**: ranking de quem mais produziu finalistas no ciclo mais recente de cada
  prova — recalculado a cada sincronização, nunca uma lista fixa. Testamos contra dado real e bateu
  exatamente com os nomes que o mercado já reconhece informalmente (Fantástico de São Pedro,
  Xeque Mate da Boa Vista, Basco Veneno, Chamamé Nochero na Morfologia; Ganadero da Harmonia e
  Colibri Matrero no freio).
- **Regra de silêncio na ausência**: se um lado da genealogia não tem destaque, o agente omite —
  nunca insinua que "falta dado" quando pode ser só ausência real de informação relevante.

### 3. Ajuda de uso do sistema
Explica como as telas do Mimba funcionam (onde cadastrar, o que cada aba faz).

### O que ele NÃO faz (por decisão, não por limitação técnica)
Não calcula um cruzamento hipotético ao vivo entre um garanhão e uma égua que nunca competiram
juntos (não temos ainda um "e se eu cruzasse X com Y" sob demanda) — se perguntarem isso, ele
explica a limitação em vez de inventar um número. Também nunca mistura as duas fontes sem avisar:
sempre deixa claro se está falando "da sua cabanha" ou "da raça em geral".

## Como funciona por trás (arquitetura, resumida)

```
Usuário pergunta no chat
        │
        ▼
Edge Function "agente-ia" (roda com o login do próprio usuário, nunca com acesso privilegiado)
        │
        ├─ pergunta sobre a cabanha? → consulta o banco de produção, só o que aquele
        │                              usuário tem permissão de ver
        │
        └─ pergunta sobre a raça/genealogia? → consulta uma tabela de resumo já pronta
                                                em produção (abccc_estatisticas_animal)
```

A parte nova é a segunda linha. Ela existe porque temos uma regra de segurança rígida desde um
incidente real em agosto: **nenhuma pergunta de uma cabanha pode tocar diretamente a base
analítica (Mimba Lab)** — foi o que causou uma queda de produção uma vez, e não vamos reabrir
esse risco. Em vez disso:

1. **Um job roda sozinho, 1x por dia, de madrugada** — sem nenhuma cabanha pedir nada, ele lê o
   Mimba Lab e escreve um resumo pronto (genealogia, participações, ranking) direto no banco de
   produção.
2. **O agente só consulta esse resumo já pronto**, igual consultaria qualquer outra tabela do
   sistema. Nunca fala com o Mimba Lab durante uma conversa.

Isso significa: mesmo que o Mimba Lab caia ou fique fora do ar, o agente continua respondendo
sobre genealogia normalmente (com o dado da última sincronização) — o app nunca depende dele em
tempo real.

## O que já está pronto e testado

- ✅ Duas tabelas novas em produção com o resumo da raça (30.037 animais sincronizados, já
  incluindo o backfill de campeões concluído em 27/08).
- ✅ Job de sincronização automática, rodando sozinho todo dia.
- ✅ As perguntas/respostas do agente sobre genealogia, testadas direto no banco com dado real.
- ✅ Balão do chat reativado no app (estava escondido desde 25/08 esperando essa evolução).
- ✅ Toda mudança que toca segurança/isolamento entre cabanhas passou por revisão dedicada antes
  de ir pro ar — nada foi aplicado sem essa checagem.

## Como "treinar" e corrigir a inteligência do agente

Primeiro, o ponto mais importante: **isso não é treinamento de IA no sentido técnico** (não existe
um modelo sendo re-treinado com dado novo). O agente usa um modelo de linguagem pronto (Claude, da
Anthropic) e "ensina" ele em tempo real, a cada pergunta, de duas formas — e são essas duas coisas
que dá pra editar/corrigir:

1. **O que o agente já sabe de cara** (vocabulário, regras de narrativa, o que destacar/omitir) —
   um texto que vai junto de toda pergunta, chamado "system prompt".
2. **O que o agente busca no banco na hora** (ferramentas/RPCs) — dado real, nunca inventado.

Não existe "período de treinamento": qualquer correção no texto ou no dado entra em vigor na
**próxima mensagem** depois de publicada, sem esperar nada.

### As 3 camadas onde uma correção pode acontecer

| Camada | O que é | Onde vive | Quem edita |
|---|---|---|---|
| **1. Vocabulário e regras de narrativa** | "linha alta = pai direto", "nunca comente ausência de dado", como citar prova/colocação | `docs/agente-ia-base-conhecimento-abccc.md` — texto normal, sem código | Qualquer um (Luciano inclusive) — é markdown puro |
| **2. Metodologia dos números derivados** | Como calcular peso de uma colocação, como calcular "linhagens em alta" | Funções SQL no Mimba Lab (`abccc_peso_colocacao`, `abccc_exportar_linhagens_em_alta`) | Precisa de uma sessão com acesso ao banco (Pedro ou Luciano via Claude Code) |
| **3. Cobertura de dado bruto** | Quantos animais/pedigrees estão carregados, quais catálogos/campeões já foram raspados da ABCCC | Scraper + job de sincronização (roda sozinho 1x/dia) | Cresce sozinho — só precisa rodar mais scraping quando aparecer catálogo novo |

### Como o Luciano interage com isso, na prática

O Luciano já roda sua própria sessão de Claude Code (foi assim que ele preparou o material que
"bebemos" pra montar tudo isso). O fluxo de correção é:

1. **Usar o agente de verdade no chat do app** e reparar quando uma resposta soa errada, incompleta
   ou no vocabulário errado.
2. **Abrir a sessão de Claude Code dele** (mesmo repositório, `projetos/cabanha`) e descrever a
   correção em português simples — não precisa saber programar. Exemplos reais de como isso
   aconteceu nesta própria sessão, pra servir de modelo:
   - *"A base de conhecimento fala em recorrência na 5ª geração pra linhagem em alta, mas os
     números batidos são só do pai direto — corrige o texto e a lógica."* → resultado: achamos o
     erro, corrigimos a função SQL e o texto da base de conhecimento, testamos contra dado real de
     novo antes de aceitar.
   - *"Doma de Ouro não é a mesma coisa que Bocal de Ouro, não deixa o agente confundir."* → já
     está no texto da base de conhecimento, seção 2.
3. **A sessão de Claude Code edita o arquivo** `docs/agente-ia-base-conhecimento-abccc.md` (camada
   1) e, se for regra de cálculo, também a função SQL correspondente (camada 2) — sempre testando
   contra dado real do Mimba Lab antes de aceitar a mudança, nunca só "parece certo".
4. **Alguém com acesso ao Supabase publica a atualização** — hoje esse é o único passo manual
   real: o texto que vai pro agente (dentro da Edge Function `agente-ia`) é uma cópia resumida do
   markdown, então depois de editar o `.md` é preciso também atualizar essa cópia e reimplantar a
   função. Isso é rápido (minutos), mas não é automático ainda — é um ponto real de fricção que dá
   pra melhorar depois (fazer o agente ler o `.md` direto, sem cópia).
5. **Testar de novo no chat** pra confirmar que a resposta mudou como esperado.

### E o dado bruto (genealogia, campeões, finalistas)?

Isso já está rodando sozinho — o job de sincronização lê o Mimba Lab todo dia de madrugada e
atualiza a tabela que o agente consulta. Sempre que um scraping novo terminar (tipo o que você
acabou de rodar agora — 22.966 animais processados, 30.037 no total), a sincronização automática
do dia seguinte já pega o dado novo sozinha. Se quiser que apareça **na hora**, sem esperar a
próxima madrugada, é só pedir pra rodar a sincronização manual (foi o que fizemos agora mesmo,
levou 44 segundos).

## O que falta

**Só uma coisa: crédito na conta da Anthropic.** A chave de API já está configurada, mas sem
crédito carregado o agente ainda não processa nenhuma mensagem de verdade (ele já avisa isso com
uma mensagem clara em vez de travar). Assim que o crédito existir, o fluxo completo (pergunta →
resposta com tom e vocabulário de quem entende a raça) pode ser testado ponta a ponta.

## Fora de escopo por ora (registrado, não esquecido)

- Cruzamento hipotético ao vivo entre um par específico nunca testado.
- "Melhor Exemplar da Raça" (o nível mais alto de todos) ainda não aparece separado nos dados —
  só os níveis abaixo dele (Grande Campeão, Reservado, etc.).
