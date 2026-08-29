import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// agente-ia — chat flutuante do agente de IA interno (ADR 0006, 0007, 0009).
//
// Diferente da maioria das Edge Functions deste projeto, esta é a primeira a
// nascer versionada no repo (`supabase/functions/agente-ia/index.ts`) em vez
// de só existir no dashboard do Supabase — vale a pena revisar código aqui.
//
// Roda com o JWT do usuário logado (verify_jwt=true, nunca service_role). O
// modelo (Claude) NUNCA monta SQL livre: as únicas "ferramentas" que ele pode
// chamar são RPCs Postgres já existentes e read-only. A autorização real de
// cada ferramenta `cab_*` acontece no Postgres via `tem_acesso_tenant` dentro
// da própria RPC — esta função nunca eleva privilégio pra satisfazer uma
// chamada de ferramenta. As ferramentas `abccc_*` não têm `tem_acesso_tenant`
// de propósito (dado público da raça, agregado ou cacheado — não pertence a
// nenhuma cabanha) — nunca fazem JOIN cross-schema com dado de tenant; a
// ponte com o animal da própria cabanha do usuário acontece em duas chamadas
// de ferramenta separadas (o modelo primeiro acha o SBB via cab_buscar_animal,
// depois consulta abccc_resumo_animal/abccc_sangues_animal com esse SBB),
// nunca numa query só.
//
// Duas fontes DISTINTAS de genealogia/ABCCC, propositalmente separadas (não
// convergidas — decisão em aberto, ver HANDOFF): abccc_estatisticas_animal
// (Mimba Lab, dado competitivo — participações, finalistas — só cobre animal
// que já apareceu em resultado/catálogo) e sangues_linhagem (pedigree cru
// buscado direto na ABCCC pela própria Análise de Sangues do app — sem dado
// competitivo, mas cobre qualquer animal já buscado uma vez, mesmo os muito
// jovens que nunca competiram). Achado real (2026-08-28): um animal recém-
// nascido tinha pedigree completo numa fonte mas o agente só sabia checar a
// outra, e respondeu "sem dado" errado — daí a regra no system prompt de
// sempre tentar as duas antes de concluir isso.
//
// Escopo desta v1 (ver docs/adr/0006, 0007, 0009): caso de uso 1 (dado da
// própria cabanha) + caso de uso 3 (especialista ABCCC: genealogia, campeões,
// linhagens em alta) + caso de uso 4 (ajuda de uso). Score de cruzamento ao
// vivo entre um par garanhão×égua nunca testado continua fora de escopo
// (ADR 0009, "o que continua fora de escopo").

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
// Sem fallback hardcoded de propósito — o ID de modelo certo na API pública da
// Anthropic muda com o tempo; melhor exigir a variável explicitamente do que
// arriscar embutir um ID desatualizado/errado.
const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL");
const MAX_RODADAS_TOOL_USE = 5;

function resp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

const BASE_CONHECIMENTO_USO = `
O Mimba organiza a gestão da cabanha em: Dashboard (resumo geral e alertas), Animais (cadastro e
ficha de cada animal), Reprodutivo (Gestações ativas, Planejador de ciclo, Cruzamentos/Conselho,
Protocolos, Crias por ciclo, Plantel), Nutrição (projetos, templates, lista de compras), Eventos
(calendário/histórico, por animal, resultados), Estoque (itens, alertas, movimentações), Medidas
(corporais por animal), Financeiro (lançamentos), Sangues (genealogia via ABCCC/SBB) e Relatórios.

Administradores convidam novos usuários (veterinário, cabanheiro, outro administrador) pela tela
de Usuários. O agente é só consulta — não cadastra nem edita nada, e não tem acesso a dado de
outra cabanha. Sugestões de manejo/cruzamento são apoio à decisão, não prescrição veterinária.
`.trim();

const BASE_CONHECIMENTO_ABCCC = `
Você também tem acesso a dado agregado da raça Crioula (fonte "abccc_lab"), sincronizado
periodicamente do Mimba Lab pro banco de produção — nunca em tempo real, nunca por proxy direto.

TERMINOLOGIA — nunca traduzir pra linguagem genérica:
- "Linha alta" de um animal = nome do pai direto (garanhão). Nunca diga "linhagem paterna".
- "Linha baixa" = a mãe SEGUIDA do pai dela, formato fixo: "[mãe] que vem a ser [avô materno]"
  (o mercado sempre referencia linhagem por garanhão, mesmo do lado materno). Se o campo já vier
  sem o "que vem a ser", é porque o avô materno não tem nome resolvido — não insinue isso, só use
  o que veio.
- Nunca chame as provas principais de "Tier 1" pro usuário — é vocabulário interno nosso.

REGRA CRÍTICA — silêncio na ausência: se um lado (linha alta ou baixa) não tiver dado, ou a
ferramenta retornar null pra ele, NÃO comente a ausência, não diga "não há registros" nem "falta
informação" — omita completamente aquele lado da resposta. Comentar a ausência insinua uma lacuna
de dado que pode não existir (o pai/mãe daquele lado pode genuinamente não ter tido destaque).

CRUZAMENTO DE VALOR — o que vale destacar:
- Irmão/irmã inteiro(a) (mesmo pai E mesma mãe) é o sinal mais forte de "cruzamento já testado" —
  vire a frase de mercado ("esta égua é irmã inteira da X"), não um score numérico perdido no meio
  de outros números.
- "Este pai já colocou N finalistas na Morfologia Expointer" é evidência concreta pra citar
  (campo finalistas_produzidos) — é contagem real, nunca invente esse número.
- "Linhagens em alta" (ferramenta abccc_ranking_linhagens) é o ranking de quem mais produziu
  finalistas no ciclo MAIS RECENTE de cada prova — sinaliza quem está em alta AGORA, é dado
  derivado recalculado a cada sincronização, nunca uma lista fixa que você já sabe de memória.

PROVAS PRINCIPAIS: Morfologia Expointer, Final Freio de Ouro, Doma de Ouro. Cuidado: "Bocal de
Ouro" é uma prova DIFERENTE (semifinal de seleção pro Freio de Ouro, só animais inéditos) — não
confundir as duas. Colocação de Doma de Ouro é só posição numérica, sem a hierarquia textual
(Grande Campeão etc.) que Morfologia e Freio de Ouro têm.

COBERTURA DE DADO: genealogia da raça no Lab tem ~69% de pai e ~27% de mãe resolvidos — linhagens
recentes (pós-2020) tendem a ser confiáveis, linhagens muito antigas podem ter buracos reais (não
hipótese sua). Se a ferramenta abccc_resumo_animal devolver null pro SBB perguntado, diga que esse animal
ainda não tem dado sincronizado da ABCCC — não invente pedigree.

O QUE VOCÊ NÃO FAZ: não calcula cruzamento hipotético ao vivo entre um garanhão e uma égua que
nunca competiram/foram testados juntos (fora de escopo por ora) — se perguntarem isso
especificamente, explique a limitação em vez de estimar um número. Não apresenta dado agregado da
raça como se fosse específico da cabanha do usuário, nem o contrário — quando combinar as duas
fontes numa resposta, deixe claro qual é qual.
`.trim();

const SYSTEM_PROMPT = `Você é o Mimba — não um agente de suporte genérico. Quando o usuário pedir uma informação que
você consegue buscar com as ferramentas disponíveis, BUSQUE E RESPONDA DIRETO, com o dado real.
Só oriente a usar a interface (\"vá em tal página\", \"clique em tal botão\") quando genuinamente
nenhuma ferramenta sua cobrir aquilo — e mesmo assim, tente primeiro entregar o que já dá pra
responder com o que você tem, antes de mandar a pessoa navegar sozinha. Nunca troque uma resposta
que você já pode dar por instruções de navegação.

Responda em português do Brasil, de forma direta e objetiva, na língua de quem entende a raça
(linha alta/baixa, "vem a ser", "irmã inteira de") — não a de um sistema genérico citando
estatística.

═══ REGRAS CRÍTICAS — releia antes de responder, nunca pule uma delas ═══

1. GENEALOGIA — DUAS FERRAMENTAS OBRIGATÓRIAS antes de dizer "sem dado": pra qualquer pergunta
sobre pedigree/linha alta/linha baixa de um animal específico, você TEM que chamar tanto
abccc_resumo_animal QUANTO abccc_sangues_animal com o SBB dele — nessa ordem ou na ordem que
preferir, mas as DUAS, sempre, antes de escrever qualquer frase tipo "sem dado" ou "não
sincronizado". Chamar só uma e concluir que não há dado é um erro grave que já aconteceu mais de
uma vez em produção com animais que tinham pedigree completo na segunda fonte. Nunca escreva "sem
dado sincronizado" numa resposta sem ter chamado as duas ferramentas NESSA MESMA resposta — não
vale confiar em memória de uma resposta anterior na conversa, o SBB pode ser de outro animal.

2. NUNCA EXPONHA ARQUITETURA/INFRAESTRUTURA INTERNA — o usuário é um criador de cavalo, não
alguém que opera o sistema. Nunca mencione: nome de sistema interno ("Mimba Lab"), palavras como
"sincronizado"/"sincronização", fonte de dado ("abccc_lab", "fonte cabanha"), nome de ferramenta
ou RPC, ou "análise de sangues registrada no histórico do app" como explicação técnica de por que
um dado existe ou não. Se não achar genealogia depois de tentar as duas ferramentas da regra 1,
diga só "ainda não tenho a genealogia desse animal" — sem explicar o mecanismo por trás, sem
citar de onde viria o dado se existisse.

3. REAPROVEITE SBB QUE JÁ APARECEU NA CONVERSA — se uma ferramenta anterior (ex.:
cab_listar_gestacoes_ativas, que devolve egua_sbb; cab_buscar_animal, que devolve sbb) já trouxe
o SBB de um animal, use esse SBB diretamente nas próximas chamadas sobre ele. NUNCA busque de
novo por nome (cab_buscar_animal) um animal cujo SBB você já tem — isso desperdiça uma chamada e
já causou erro em produção (SBB errado sendo usado depois de uma rebusca desnecessária).

4. NUNCA RECALCULE UM NÚMERO QUE JÁ VEIO DE FERRAMENTA — se um número já apareceu no resultado de
cab_resumo_geral ou outra ferramenta (e já virou cartão visual pro usuário), cite-o exatamente
como veio. Já aconteceu em produção do modelo pegar os números certos de um cartão e, ao tentar
reescrever em texto, errar a conta. Se não tiver certeza, não invente — cite o campo literalmente
ou não mencione esse número específico.

5. NÃO AFIRME GARANTIA QUE NENHUMA FERRAMENTA CONFIRMOU — frases tipo "tudo dentro do
esperado/dos prazos" só valem se alguma ferramenta calculou isso explicitamente. Se não calculou,
não afirme.

6. NUNCA INVENTE NOME DE ANCESTRAL/PARENTE — se um campo de genealogia (linha_alta, linha_baixa,
pai, mae, avo_paterno, avo_materno) não aparecer no resultado de uma ferramenta (campo ausente,
ou você ver um "aviso_grounding" explícito dizendo que aquele lado não tem dado), você NÃO tem
esse nome — é proibido escrever qualquer nome ali, mesmo que pareça familiar de algum outro ponto
da conversa ou da raça. JÁ ACONTECEU EM PRODUÇÃO: perguntado sobre a linha baixa de uma égua cujo
campo vinha vazio, o modelo escreveu o nome de um animal TOTALMENTE DIFERENTE (que existe de
verdade na base, só que não tem nenhuma relação com o animal perguntado) como se fosse a mãe dela.
Isso é alucinação grave — o usuário toma decisão real de cruzamento com base nisso. Se o campo não
veio, a resposta certa é omitir esse lado, nunca "completar" com um nome que pareça plausível.

═══ fim das regras críticas ═══

Você tem acesso a ferramentas que consultam o banco de dados da cabanha do usuário logado (fonte
"cabanha"), dado agregado da raça Crioula sincronizado do Mimba Lab (fonte "abccc_lab"), e uma
base de conhecimento estática sobre como o sistema funciona (fonte "sistema"). Essas etiquetas de
fonte são só pra você raciocinar internamente — NUNCA as mencione pro usuário (ver regra 2). Cada
resultado de ferramenta já vem marcado com sua fonte real — nunca invente ou troque a fonte de
uma informação.

Pra falar da genealogia/linhagem de um animal específico da cabanha do usuário: primeiro ache o
SBB dele com a ferramenta cab_buscar_animal (ou reaproveite um SBB que já apareceu na conversa,
ver regra 3), depois consulte abccc_resumo_animal E abccc_sangues_animal com esse SBB (ver regra
1) — nunca espere uma ferramenta só que já cruze as fontes.

Pra perguntas do tipo "o que precisa da minha atenção", "quais animais têm vacina/exame vencido
ou faltando", "quais são as pendências": use cab_listar_pendencias, NUNCA tente forçar isso com
cab_resumo_periodo (que só dá contagem agregada num período explícito, não lista quais animais, e
não responde bem a "agora"/"neste momento" — cab_resumo_periodo serve pra perguntas que já vêm
com datas, tipo "quantas vacinas eu apliquei em agosto"). cab_listar_pendencias tem 4 tipos
possíveis, e "vencido(a)" e "faltando" são coisas DIFERENTES — quando o usuário perguntar de forma
ampla ("exames vencidos", "o que está pendente"), considere os dois tipos relacionados juntos (ex.:
"Exame sanitário" = nunca foi registrado nenhum exame, "Exame vencido" = tinha exame mas venceu —
as duas são formas de "esse animal está sem exame válido agora", geralmente é isso que a pessoa
quer saber, não só o match exato da palavra "vencido"). Se quiser só um tipo específico, filtre;
se a pergunta for ampla, chame sem filtro e organize a resposta pelos tipos relevantes.

Pra "quantos animais eu tenho", "como está minha cabanha", contagens gerais amplas: use
cab_resumo_geral, não tente somar/adivinhar a partir de outras ferramentas.

CUIDADO — "estágio" tem DOIS sentidos diferentes no sistema, não confunda: "estágio de
atividade" (Campo, Cria, Pista Morfologia, Arreio Cabanha, Pista Funcional, Laço — o que o
animal está fazendo agora) vem de cab_agrupar_por_estagio; "estágio de confirmação na ABCCC"
(confirmado/em desenvolvimento/aguardando confirmação — status de registro na raça) vem de
cab_resumo_geral. "Relatório dos animais por estágio" sem mais contexto quase sempre quer
dizer o primeiro (atividade) — já aconteceu em produção do modelo responder com o segundo por
engano.

Sobre listas e resumos: quando cab_listar_pendencias, cab_buscar_animal, cab_listar_gestacoes_ativas,
cab_agrupar_por_estagio ou cab_resumo_geral devolverem uma lista/resumo, a interface já desenha esse dado como cartão
visual pro usuário — você NÃO precisa (e não deve) reescrever cada item em texto corrido. Sua
resposta em texto deve ser só um comentário curto contextualizando o que apareceu (ex.: "Você tem
4 gestações ativas, a mais próxima do parto é a Necajô Donana" em vez de listar as 4 de novo com
todos os detalhes que o cartão já mostra). Exceção: se a ferramenta retornar vazio ([] ou 0), não
tem cartão pra desenhar — aí sim descreva isso em texto.

Evite responder só "vá em Relatórios e gere lá" quando cab_listar_pendencias já responde a
pergunta com dado real — isso é exatamente o tipo de resposta pouco resolutiva a evitar. A seção
Relatórios existe pra exportar em PDF, não é a única forma de responder uma pergunta sobre
sanidade — se você consegue responder com uma ferramenta, responda, e só cite Relatórios se o
usuário quiser especificamente o PDF pra imprimir/arquivar.

Você NÃO tem acesso a dado de nenhuma outra cabanha, e não tem (por ora) um mecanismo de calcular
o score de cruzamento sob demanda entre um garanhão e uma égua específicos fora da tela do
Conselho — se perguntarem isso, explique essa limitação em vez de inventar um número, sem citar
nome de tela/ferramenta interna (ver regra 2) — diga algo como "ainda não calculo isso na hora
pra um par específico".

Base de conhecimento de uso do sistema:
${BASE_CONHECIMENTO_USO}

Base de conhecimento da raça Crioula / ABCCC:
${BASE_CONHECIMENTO_ABCCC}`;

const TOOLS = [
  {
    name: "cab_buscar_animal",
    description: "Busca animais da cabanha do usuário por nome, SBB ou RP. Retorna até 10 resultados compactos.",
    input_schema: {
      type: "object",
      properties: { termo: { type: "string", description: "Nome, código SBB ou RP (ou parte deles) a buscar" } },
      required: ["termo"],
    },
  },
  {
    name: "cab_listar_gestacoes_ativas",
    description: "Lista as gestações ativas (éguas prenhas) da cabanha do usuário, com datas de cobertura, confirmação e parto previsto.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "cab_resumo_periodo",
    description: "Contagens agregadas da cabanha do usuário num período: nascimentos, coberturas registradas, vacinas aplicadas, vacinas e exames vencendo no período.",
    input_schema: {
      type: "object",
      properties: {
        data_inicio: { type: "string", description: "Data inicial, formato YYYY-MM-DD" },
        data_fim: { type: "string", description: "Data final, formato YYYY-MM-DD" },
      },
      required: ["data_inicio", "data_fim"],
    },
  },
  {
    name: "ajuda_sistema",
    description: "Consulta a base de conhecimento estática sobre como o Mimba funciona (não é dado de banco, não muda por cabanha).",
    input_schema: {
      type: "object",
      properties: { topico: { type: "string", description: "O que o usuário quer entender sobre o sistema" } },
      required: ["topico"],
    },
  },
  {
    name: "cab_listar_pendencias",
    description:
      "Lista as pendências abertas (não resolvidas) da cabanha do usuário — animais com vacina ou exame sanitário vencido, ou nunca registrado. É a ferramenta certa pra 'o que precisa da minha atenção', 'quais animais têm exame/vacina vencido ou faltando', 'quais são as pendências' — NÃO use cab_resumo_periodo pra esse tipo de pergunta. Tipos possíveis: 'Vacina' (nunca registrada), 'Vacina vencida' (registrada mas venceu), 'Exame sanitário' (nunca registrado), 'Exame vencido' (registrado mas venceu). Pra perguntas amplas sobre exame ou vacina, considere o par (nunca registrado + vencido) junto, não só o tipo com a palavra 'vencido' exata.",
    input_schema: {
      type: "object",
      properties: {
        tipo: { type: "string", description: "Filtra por um tipo exato ('Vacina', 'Vacina vencida', 'Exame sanitário' ou 'Exame vencido'). Omitir pra trazer todas e organizar na resposta." },
      },
    },
  },
  {
    name: "cab_agrupar_por_estagio",
    description:
      "Contagem de animais ativos da cabanha agrupada por ESTÁGIO DE ATIVIDADE (ex.: Campo, Cria, Pista Morfologia, Arreio Cabanha, Pista Funcional, Laço) — mesmo dado do card 'Estágio / atividade' do Dashboard. É a ferramenta certa pra 'relatório dos animais por estágio', 'quantos animais estão em cada estágio', 'quantos estão em pista/cria/campo'. NÃO confundir com estágio de CONFIRMAÇÃO NA ABCCC (confirmado/em desenvolvimento/aguardando) — isso é outra coisa e vem de cab_resumo_geral.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "cab_resumo_geral",
    description:
      "Resumo geral da cabanha: total de animais (por sexo, por situação — na cabanha/empréstimo/vendido/morto/transferido), quantos confirmados/em desenvolvimento/aguardando confirmação na ABCCC, gestações ativas, pendências abertas. É a ferramenta certa pra 'quantos animais eu tenho', 'como está minha cabanha', 'me dá um resumo geral' — qualquer pergunta ampla de contagem que não pede um período específico.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "abccc_resumo_animal",
    description:
      "Consulta o resumo genealógico/competitivo de um animal da raça Crioula por SBB (linha alta/baixa, participações em provas com peso, finalistas produzidos, árvore de 5 gerações). Dado agregado da raça, sincronizado do Mimba Lab — não é específico de nenhuma cabanha. Pra usar com o animal da própria cabanha do usuário, ache o SBB antes com cab_buscar_animal.",
    input_schema: {
      type: "object",
      properties: { sbb: { type: "string", description: "Código SBB do animal na ABCCC" } },
      required: ["sbb"],
    },
  },
  {
    name: "abccc_sangues_animal",
    description:
      "Consulta o pedigree de um animal por SBB direto da fonte que a Análise de Sangues do app já buscou na ABCCC (pai, mãe, avô paterno, avô materno, total de ancestrais na árvore de 5 gerações). Diferente de abccc_resumo_animal: essa fonte NÃO tem estatística competitiva (sem participações, sem finalistas_produzidos) mas cobre praticamente qualquer animal já buscado uma vez, mesmo os que nunca competiram (ex.: animal muito jovem). Use isso quando abccc_resumo_animal não trouxer dado — NÃO conclua 'sem dado sincronizado' sem tentar essa também.",
    input_schema: {
      type: "object",
      properties: { sbb: { type: "string", description: "Código SBB do animal na ABCCC" } },
      required: ["sbb"],
    },
  },
  {
    name: "abccc_ranking_linhagens",
    description:
      "Ranking dos garanhões que mais produziram finalistas no ciclo mais recente de cada prova principal (Morfologia Expointer, Final Freio de Ouro, Doma de Ouro) — 'linhagens em alta', dado derivado recalculado a cada sincronização.",
    input_schema: {
      type: "object",
      properties: {
        prova: { type: "string", description: "Nome exato da prova (opcional — sem isso, devolve o top de cada uma das 3 provas principais)" },
      },
    },
  },
];

type Ferramenta = { id: string; name: string; input: Record<string, unknown> };

// Grounding anti-alucinação (2026-08-28): campos de genealogia nulos são REMOVIDOS
// do JSON (não mandamos "campo: null" pro modelo) e trocados por um aviso
// explícito nesse mesmo resultado de ferramenta — reforço bem colado no dado,
// além da regra 6 no system prompt. Achado real: com o campo só ausente/null
// "solto", o modelo às vezes "completava" com um nome plausível de outro
// animal da base em vez de simplesmente omitir.
function limparCamposGenealogia(dado: Record<string, unknown>, campos: string[]) {
  const limpo: Record<string, unknown> = { ...dado };
  const avisos: string[] = [];
  for (const campo of campos) {
    if (limpo[campo] == null) {
      delete limpo[campo];
      avisos.push(`${campo}: SEM DADO -- proibido inventar nome aqui, só omita esse lado na resposta (ver regra 6)`);
    }
  }
  return { limpo, avisos };
}

async function executarFerramenta(supa: ReturnType<typeof createClient>, tenantId: string, chamada: Ferramenta) {
  switch (chamada.name) {
    case "cab_buscar_animal": {
      const { data, error } = await supa.rpc("cab_buscar_animal", { p_tenant_id: tenantId, p_termo: chamada.input.termo });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_listar_gestacoes_ativas": {
      const { data, error } = await supa.rpc("cab_listar_gestacoes_ativas", { p_tenant_id: tenantId });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_resumo_periodo": {
      const { data, error } = await supa.rpc("cab_resumo_periodo", {
        p_tenant_id: tenantId,
        p_data_inicio: chamada.input.data_inicio,
        p_data_fim: chamada.input.data_fim,
      });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_listar_pendencias": {
      const { data, error } = await supa.rpc("cab_listar_pendencias", {
        p_tenant_id: tenantId,
        p_tipo: chamada.input.tipo ?? null,
      });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_resumo_geral": {
      const { data, error } = await supa.rpc("cab_resumo_geral", { p_tenant_id: tenantId });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "cab_agrupar_por_estagio": {
      const { data, error } = await supa.rpc("cab_agrupar_por_estagio", { p_tenant_id: tenantId });
      if (error) return { fonte: "cabanha", erro: error.message };
      return { fonte: "cabanha", resultado: data };
    }
    case "ajuda_sistema":
      return { fonte: "sistema", resultado: BASE_CONHECIMENTO_USO };
    case "abccc_resumo_animal": {
      const { data, error } = await supa.rpc("abccc_resumo_animal", { p_sbb: chamada.input.sbb });
      if (error) return { fonte: "abccc_lab", erro: error.message };
      if (!data) return { fonte: "abccc_lab", resultado: null };
      const { limpo, avisos } = limparCamposGenealogia(data, ["linha_alta", "linha_baixa"]);
      return { fonte: "abccc_lab", resultado: limpo, ...(avisos.length ? { aviso_grounding: avisos } : {}) };
    }
    case "abccc_sangues_animal": {
      // p_tenant_id adicionado 2026-08-28 -- a RPC antiga lia public.sangues_linhagem
      // (template, sempre vazio) em vez do schema real da cabanha. Ver migration
      // 2026-08-28-fix-abccc-sangues-animal-schema-errado.sql.
      const { data, error } = await supa.rpc("abccc_sangues_animal", { p_tenant_id: tenantId, p_sbb: chamada.input.sbb });
      if (error) return { fonte: "abccc_lab", erro: error.message };
      if (!data) return { fonte: "abccc_lab", resultado: null };
      const { limpo, avisos } = limparCamposGenealogia(data, ["pai", "mae", "avo_paterno", "avo_materno"]);
      return { fonte: "abccc_lab", resultado: limpo, ...(avisos.length ? { aviso_grounding: avisos } : {}) };
    }
    case "abccc_ranking_linhagens": {
      const { data, error } = await supa.rpc("abccc_ranking_linhagens", {
        p_prova: chamada.input.prova ?? null,
      });
      if (error) return { fonte: "abccc_lab", erro: error.message };
      return { fonte: "abccc_lab", resultado: data };
    }
    default:
      return { fonte: "sistema", erro: `ferramenta desconhecida: ${chamada.name}` };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resp(405, { erro: "metodo" });

  if (!ANTHROPIC_API_KEY || !ANTHROPIC_MODEL) {
    return resp(500, { erro: "ANTHROPIC_API_KEY/ANTHROPIC_MODEL nao configurados — agente ainda nao esta ativo." });
  }

  const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
  const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return resp(401, { erro: "nao autenticado" });

  const supa = createClient(SUPA_URL, ANON, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: errUser } = await supa.auth.getUser();
  if (errUser || !user) return resp(401, { erro: "sessao invalida" });

  let body: any;
  try { body = await req.json(); } catch { return resp(400, { erro: "payload" }); }
  const { tenant_id, mensagens } = body;
  if (!tenant_id || !Array.isArray(mensagens) || mensagens.length === 0) {
    return resp(400, { erro: "tenant_id e mensagens (array) sao obrigatorios" });
  }

  const { data: uso, error: errUso } = await supa.rpc("agente_ia_registrar_uso", { p_tenant_id: tenant_id });
  if (errUso) return resp(403, { erro: errUso.message });
  if (uso?.excedeu) {
    return resp(429, { erro: `Limite de mensagens do agente de IA atingido este mês (${uso.cota}). Fala com o suporte se precisar de mais.` });
  }

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      const enviar = (evento: string, dados: unknown) => {
        controller.enqueue(encoder.encode(`event: ${evento}\ndata: ${JSON.stringify(dados)}\n\n`));
      };

      let historico = [...mensagens];

      try {
        for (let rodada = 0; rodada < MAX_RODADAS_TOOL_USE; rodada++) {
          const r = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "x-api-key": ANTHROPIC_API_KEY,
              "anthropic-version": "2023-06-01",
              "content-type": "application/json",
            },
            body: JSON.stringify({
              model: ANTHROPIC_MODEL,
              max_tokens: 1024,
              system: SYSTEM_PROMPT,
              messages: historico,
              tools: TOOLS,
              stream: true,
            }),
          });

          if (!r.ok || !r.body) {
            const detalhe = await r.text().catch(() => "");
            enviar("erro", { erro: `Claude API ${r.status}: ${detalhe}` });
            controller.close();
            return;
          }

          const reader = r.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";
          const blocosConteudo: any[] = [];
          let stopReason: string | null = null;

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const partes = buffer.split("\n\n");
            buffer = partes.pop() ?? "";

            for (const parte of partes) {
              const linhaDados = parte.split("\n").find((l) => l.startsWith("data: "));
              if (!linhaDados) continue;
              const evento = JSON.parse(linhaDados.slice(6));

              if (evento.type === "content_block_start") {
                blocosConteudo[evento.index] = { ...evento.content_block };
                if (evento.content_block.type === "tool_use") blocosConteudo[evento.index].input_json = "";
              } else if (evento.type === "content_block_delta") {
                if (evento.delta.type === "text_delta") {
                  blocosConteudo[evento.index].text = (blocosConteudo[evento.index].text ?? "") + evento.delta.text;
                  enviar("texto", { delta: evento.delta.text });
                } else if (evento.delta.type === "input_json_delta") {
                  blocosConteudo[evento.index].input_json += evento.delta.partial_json;
                } else if (evento.delta.type === "thinking_delta") {
                  // Extended thinking (2026-08-28): sem isso, o bloco "thinking" ficava vazio
                  // e a API rejeitava com 400 ("each thinking block must contain thinking") assim
                  // que o histórico com esse bloco era reenviado na proxima rodada de tool use.
                  blocosConteudo[evento.index].thinking = (blocosConteudo[evento.index].thinking ?? "") + evento.delta.thinking;
                } else if (evento.delta.type === "signature_delta") {
                  blocosConteudo[evento.index].signature = (blocosConteudo[evento.index].signature ?? "") + evento.delta.signature;
                }
              } else if (evento.type === "message_delta") {
                if (evento.delta.stop_reason) stopReason = evento.delta.stop_reason;
              }
            }
          }

          const blocosFinais = blocosConteudo.map((b) => {
            if (b.type !== "tool_use") return b;
            const { input_json, ...resto } = b;
            return { ...resto, input: JSON.parse(input_json || "{}") };
          });
          historico.push({ role: "assistant", content: blocosFinais });

          if (stopReason !== "tool_use") {
            enviar("fim", {});
            controller.close();
            return;
          }

          const chamadasFerramenta = blocosFinais.filter((b) => b.type === "tool_use") as Ferramenta[];
          const resultados = await Promise.all(
            chamadasFerramenta.map(async (chamada) => {
              enviar("ferramenta", { nome: chamada.name });
              const resultado = await executarFerramenta(supa, tenant_id, chamada);
              enviar("ferramenta_resultado", { nome: chamada.name, resultado });
              return {
                type: "tool_result" as const,
                tool_use_id: chamada.id,
                content: JSON.stringify(resultado),
              };
            })
          );
          historico.push({ role: "user", content: resultados });
        }

        enviar("erro", { erro: "Limite de rodadas de ferramentas atingido." });
        controller.close();
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        enviar("erro", { erro: msg });
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: { ...CORS, "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" },
  });
});
