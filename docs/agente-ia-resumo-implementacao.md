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

- ✅ Duas tabelas novas em produção com o resumo da raça (29.282 animais sincronizados).
- ✅ Job de sincronização automática, rodando sozinho todo dia.
- ✅ As perguntas/respostas do agente sobre genealogia, testadas direto no banco com dado real.
- ✅ Balão do chat reativado no app (estava escondido desde 25/08 esperando essa evolução).
- ✅ Toda mudança que toca segurança/isolamento entre cabanhas passou por revisão dedicada antes
  de ir pro ar — nada foi aplicado sem essa checagem.

## O que falta

**Só uma coisa: crédito na conta da Anthropic.** A chave de API já está configurada, mas sem
crédito carregado o agente ainda não processa nenhuma mensagem de verdade (ele já avisa isso com
uma mensagem clara em vez de travar). Assim que o crédito existir, o fluxo completo (pergunta →
resposta com tom e vocabulário de quem entende a raça) pode ser testado ponta a ponta.

## Fora de escopo por ora (registrado, não esquecido)

- Cruzamento hipotético ao vivo entre um par específico nunca testado.
- "Melhor Exemplar da Raça" (o nível mais alto de todos) ainda não aparece separado nos dados —
  só os níveis abaixo dele (Grande Campeão, Reservado, etc.).
