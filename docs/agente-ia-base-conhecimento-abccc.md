# Base de conhecimento do agente de IA — especialista ABCCC / raça Crioula

> Caso de uso 3 do agente Mimba (ver ADR 0006, ADR 0007, ADR 0009). Conteúdo curado, pensado
> para alimentar o system prompt do agente e servir de insumo direto para o que a tabela
> `abccc_estatisticas_animal` (sincronizada periodicamente do Mimba Lab, ver ADR 0009) precisa
> carregar. Consolida terminologia de mercado e regras de narrativa levantadas com o Luciano ao
> longo de várias sessões, validadas contra dado real do Mimba Lab (`njynlsugmvtuvcczmuld`)
> sempre que possível — não é conhecimento teórico, é o que já foi testado.
>
> **Regra geral de tom**: o agente fala a língua de quem entende cavalo Crioulo, não a de um
> sistema genérico citando estatística. Os termos abaixo (linha alta/baixa, "vem a ser", "irmã
> inteira de") não são estilo opcional — são o vocabulário que faz a resposta soar como vinda de
> alguém que conhece a raça, não como um relatório de BI.

## 1. Terminologia — nunca traduzir para linguagem genérica

| Termo do mercado | Nunca dizer no lugar |
|---|---|
| Linha alta | "linhagem paterna", "lado do pai" |
| Linha baixa | "linhagem materna", "lado da mãe" |
| Vem a ser | "é filho de", "descende de" (quando citando a linha baixa, ver regra abaixo) |
| Irmã/irmão inteiro(a) | "parentesco total", "mesmos pais" |
| As provas principais da raça | **"Tier 1"** — isso é vocabulário interno nosso, nunca aparece para o usuário |

### Linha alta / linha baixa

- **Linha alta** de um animal = o nome do **pai direto** (o garanhão). Simples: um nome.
- **Linha baixa** de um animal = **não é só o nome da mãe**. É a mãe **seguida do pai dela** (o
  avô materno), no formato fixo:

  > "[nome da mãe] que vem a ser [nome do avô materno]"

  Porque o mercado sempre referencia linhagem através de garanhões — mesmo do lado materno, o
  costume é nomear o pai da égua em seguida, para dar o reconhecimento de linhagem. Não citar só
  a mãe é resposta incompleta aos olhos de quem conhece a raça, mesmo que tecnicamente correta.

  **Exemplo real, validado**: linha baixa do Crocel da Mãe de Deus = "Indiana do Butiazeiro que
  vem a ser Feriado de Santa Edwiges" (mãe dele é Indiana do Butiazeiro; o pai dela é Feriado de
  Santa Edwiges).

## 2. As provas principais da raça (uso interno: "Tier 1" — NUNCA falar isso para o usuário)

Quatro provas, frequentemente confundidas entre si — cuidado especial com as duas últimas, que
têm nome parecido mas são **provas diferentes**:

1. **Morfologia Expointer** — julgamento morfológico, prova mais tradicional da raça.
2. **Final do Freio de Ouro** — final do ciclo de freio, o resultado mais cobiçado no trabalho
   de rédeas.
3. **Bocal de Ouro** — prova de **seleção/semifinal** para o Freio de Ouro. Só competem animais
   **inéditos** (participando do ciclo do Freio de Ouro pela primeira vez).
4. **Doma de Ouro** — **diferente do Bocal de Ouro**, mesmo soando parecido. Trata de animais
   **domados para correr**: há uma vistoria 21–30 dias antes da prova para confirmar que o
   animal é **chucro** (nunca foi domado); se liberado, é domado especificamente para competir.

   > ⚠️ **Correção (2026-08-26)**: achado anterior (2026-08-25) dizia que "Doma de Ouro" não
   > existia na base — na verdade está carregada (336 linhas, `tier=2`, distinta de Bocal de Ouro).
   > Colocação de Doma de Ouro é só posição numérica (`01`, `04`...), sem a hierarquia textual
   > (Grande Campeão etc.) que Morfologia e Freio de Ouro têm — dá pra citar posição/finalista,
   > não o nível de detalhe da seção 6. Não confundir Doma de Ouro com Bocal de Ouro ao responder.

## 3. Análise ancestral (5 gerações) — regras de narrativa

### 3.1 Ancestral-referência por lado

Ao analisar a genealogia de um animal (ou um cruzamento), busca-se em cada lado (linha alta e
linha baixa) o **ancestral mais relevante dentro das 5 gerações**, e narra-se assim:

> "na linha alta chega ao [X], na linha baixa filha de [Y]"

### 3.2 Regra crítica — o silêncio na ausência

**Se não encontrar referência de peso num lado, isso NÃO é lacuna de dado — é ausência real** (o
pai/mãe/avô daquele lado provavelmente não teve destaque). Nesse caso: **omitir completamente**,
nunca comentar a ausência, nunca insinuar que falta informação. Dizer algo como "não há registros
de destaque na linha alta" está **errado** mesmo que factualmente verdadeiro — porque insinua uma
lacuna de dado que não existe. O comportamento correto é simplesmente não mencionar aquele lado.

### 3.3 Quando o ancestral mais importante está distante

Quando o ancestral de maior peso não está no avô (geração 2), mas mais distante, citar em ponte —
**só quando o elo intermediário também tem peso próprio** (senão a citação perde credibilidade,
vira um nome pescado sem conexão relevante):

> "[ancestral distante e importante], através do também campeão [ancestral mais próximo]"

Exemplo: "este cavalo tem na linha baixa o grande raçador Índio do Boeiro, através do também
campeão Las Gurizas Fogonero."

## 4. Cruzamento de valor — o que vale destacar

### 4.1 Irmão/irmã inteiro(a) — o caso mais forte

Irmão/irmã inteiro(a) = **mesmo pai E mesma mãe**. É o sinal mais forte de "cruzamento já
testado" — significa que a linha alta e a linha baixa são idênticas às de outro animal já
conhecido (normalmente um campeão). A frase de mercado:

> "Esta égua é irmã inteira da Belle Reserva."

**Generaliza via avós**: o mesmo conceito de "mesmo cruzamento" vale quando a coincidência
acontece nas posições p1/p2/p3/m2/m3 (pai, avô paterno, avó paterna, avô materno, avó materna) —
um match de 5/5 nessas posições é, na prática, o mesmo cruzamento repetido, mesmo sem ser irmão
inteiro literal. Quando o match é máximo, isso deve virar a frase especial ("irmã inteira de X",
ou equivalente para o caso via avós), não só um score numérico — um score alto perdido no meio de
outros números não comunica o mesmo peso que a frase de mercado.

### 4.2 Citar produção de finalistas como evidência

Quando um garanhão (ou égua) na linha alta/baixa de um animal já colocou descendentes na final de
uma prova principal, isso é evidência concreta a citar: "esse pai já colocou N finalistas na
Morfologia Expointer" (ou na prova relevante). Não é opinião, é contagem — deve vir de uma
consulta real (contagem de descendentes distintos aparecendo como finalistas daquele garanhão/
égua, por prova), não de memória do modelo.

### 4.3 Linhagens em alta — dado derivado, não lista fixa

"Linhagens em alta" não é uma lista que alguém escreveu uma vez e ficou congelada. É **derivada**:
contar, entre os finalistas do ciclo mais recente de cada prova principal, quantos têm cada
garanhão como **pai direto** — quem produziu mais finalistas nesse ciclo é quem está "em alta"
agora. Isso muda a cada ciclo novo carregado, e deve ser recalculado (não hardcoded).

> ⚠️ **Correção de metodologia (2026-08-27)**: a versão anterior deste texto descrevia o método
> como "recorrência na 5ª geração" (árvore inteira). Ao implementar o job de sincronização
> (ADR 0009), essa versão foi testada contra o dado real e devolvia um resultado sem sentido —
> um fundador antigo qualquer aparecia em quase metade de todas as árvores só por profundidade
> de pedigree, o que não sinaliza nada sobre "quem está em alta agora". A metodologia que
> realmente bate com os números já validados abaixo é mais simples: **só o pai direto**
> (`sbb_pai`) dos finalistas do ciclo mais recente, contado por prova.

**Exemplo validado com dado real (Morfologia Expointer 2026, 503 finalistas)**:

| Garanhão | Finalistas produzidos como pai direto |
|---|---|
| Fantástico de São Pedro | 28 |
| Xeque Mate da Boa Vista | 16 |
| Basco Veneno | 16 |
| Chamamé Nochero | 14 |

Esses nomes bateram exatamente com o que o mercado já reconhece informalmente como "os mais
falados de morfologia hoje" — confirma que o método (contar quantos finalistas recentes têm
aquele garanhão como pai direto) reproduz o conhecimento tácito de quem acompanha a raça de
perto, sem precisar hardcodar nome nenhum.

No freio (Final Freio de Ouro 2026, 217 finalistas), o mesmo método aponta hoje para Ganadero da
Harmonia e Colibri Matrero (este último citado como um dos maiores campeões da raça) empatados
em 8 finalistas cada como pai direto — confirmado com dado real, mesmo padrão de recorrência.

## 5. O que o agente NÃO faz (nesta fase — ver ADR 0009)

- Não calcula cruzamento hipotético ao vivo entre um garanhão e uma égua que nunca foram testados
  juntos — isso segue fora de escopo (ADR 0009, "o que continua fora de escopo").
- Não apresenta dado agregado do Lab como se fosse específico da cabanha do usuário, nem o
  contrário — sempre que a resposta combinar as duas fontes, deixar claro qual é qual (ver ADR
  0006, seção 3).
- Não inventa estatística — toda contagem citada (finalistas produzidos, linhagem em alta) vem de
  consulta real à tabela sincronizada, nunca de estimativa do modelo.

## 6. Hierarquia oficial de colocação (fonte: ABCCC e cobertura da Expointer) — resolve "o que conta como Campeão"

Pesquisado em material oficial e jornalístico da própria ABCCC (2026-08-26) pra não adivinhar o
critério de peso usado nas narrativas de referência (seção 3) e linhagens em alta (seção 4.3).

### Morfologia

1. **Melhor Exemplar da Raça** — topo absoluto do ciclo: o melhor entre os dois Grandes
   Campeões (macho e fêmea), representa a edição inteira.
2. **Grande Campeão / Grande Campeã** — 1º colocado geral do sexo (machos e fêmeas julgados
   separado, cada lado tem seu Grande Campeão).
3. **Reservado(a) Grande Campeão/ã** — 2º colocado geral do sexo.
4. **3ª/4ª Melhor Macho/Fêmea** — completam a "fila do Grande Campeonato", 4 animais por sexo.
5. **Campeão/Campeã de Categoria** — 1º lugar dentro de cada categoria etária (Potranco(a)
   Menor/Maior, Cavalo/Égua Menor/Adulto) — vários campeões de categoria, só os melhores avançam
   pro Grande Campeonato.

### Freio de Ouro

Não é uma prova isolada — é um sistema de **camadas dentro da mesma final**: Freio de Ouro,
Freio de Prata, Freio de Bronze e Freio de Alpaca são níveis por pontuação dentro do mesmo
evento. Mesmo padrão de "fila de 4" por sexo que a Morfologia usa (4 grandes campeões machos +
4 campeãs fêmeas na final). "Campeão do Freio de Ouro" é o topo absoluto dentro da camada Ouro.

### Escala de peso pra narrativa de referência (proposta, a confirmar quando o Pedro tiver
`colocação` carregada no Lab)

| Nível | Peso |
|---|---|
| Melhor Exemplar da Raça | Máximo |
| Grande Campeão/ã (Morfologia) / Campeão do Freio de Ouro | Muito alto |
| Reservado(a) Grande Campeão/ã | Alto |
| 3º/4º Melhor Macho/Fêmea ("fila de 4") | Alto |
| Campeão/ã de Categoria | Médio |
| Finalista sem título (participou da final, sem colocação de destaque) | Baixo — citável como "finalista", nunca como "campeão" |

Fontes: cavalocrioulo.org.br (notícias oficiais da ABCCC sobre Morfologia Expointer 2020/2025 e
Final do Freio de Ouro 2025), jornaluniao.com.br, revistahorse.com.br, expointer.rs.gov.br,
canaldocriador.com.br, comprerural.com.br — pesquisado 2026-08-26.

## 7. Notas de cobertura de dado (para calibrar confiança nas respostas)

- Genealogia (`sbb_pai`/`sbb_mae`) no Mimba Lab: **69% de pai, 27% de mãe** resolvidos, em
  26.593 animais (após backfill de 2026-08-25 — partiu de 3%). Cobertura pré-2000 continua baixa
  (a maioria dos ancestrais mais antigos só foi resolvida se também competiu e apareceu com o
  próprio SBB na base — ver detalhes técnicos em `docs/adr/0009-especialista-abccc-destravado-sincronizacao-periodica.md`).
- Isso significa: para animais/linhagens mais recentes (pós-2020), a análise de 5 gerações tende
  a ser confiável. Para linhagens muito antigas, pode haver buracos reais (não hipóteses do
  modelo) — o comportamento correto nesse caso é a regra 3.2 (omitir, não comentar a ausência).
