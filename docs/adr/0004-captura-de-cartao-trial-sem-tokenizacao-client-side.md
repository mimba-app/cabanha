# 0004 — Captura de cartão do trial passa pelo backend (sem tokenização client-side)

**Status:** Aceito, com dívida técnica registrada (2026-08-02).

## Contexto
O trial automático de 30 dias (V1.5, Fase 2 — `docs/roadmap-v15.md`) precisa tokenizar o cartão do
cliente no cadastro, sem cobrar na hora. A edge function `criar-checkout-trial` recebe o payload da
landing com número do cartão + CVV em texto plano, e repassa pro endpoint de tokenização do Asaas
(`POST /v3/creditCard/tokenize`, autenticado com a `ASAAS_API_KEY` secreta).

Numa sessão anterior da landing (`mimba-landing`), a implementação do formulário foi **pausada**
com uma objeção correta: mandar PAN+CVV pra um backend próprio (mesmo sem armazenar nada) coloca o
projeto em escopo **PCI-DSS SAQ D** — o nível mais pesado de compliance — só por *transmitir* esse
dado através de código nosso, em vez de tokenizar direto no navegador do cliente contra o Asaas (like
Stripe.js/hosted fields), que nunca colocaria nosso backend no caminho do cartão.

## Investigação
Consultamos a documentação oficial do Asaas (`docs.asaas.com`) antes de decidir:
- O endpoint de tokenização (`/v3/creditCard/tokenize`) exige o header `access_token` — a mesma
  credencial secreta da conta, não uma "chave pública" separada.
- A doc de "Criando assinatura com cartão de crédito" confirma: a API espera **chamadas diretas do
  backend do integrador com os dados do cartão no corpo da requisição**. Não há menção a formulário
  hospedado, iframe ou SDK client-side equivalente ao Stripe Elements/Braintree hosted fields.
- **Conclusão: o Asaas não oferece uma alternativa de tokenização client-side hoje.** O caminho
  "ideal" que motivou a pausa na landing não existe como opção disponível — é assim que qualquer
  integração de cartão recorrente com o Asaas funciona, documentado oficialmente por eles.

## Decisão
Manter a captura de cartão no backend (`criar-checkout-trial`), pelas razões:
1. Não há alternativa documentada do Asaas que evite isso.
2. O prazo da V1.5 (29/08/2026) não comporta pausar o trial esperando confirmação de um gerente de
   conta Asaas sobre uma funcionalidade não documentada publicamente.
3. Mitigações reais já estão em vigor: HTTPS obrigatório em toda a cadeia, o cartão nunca é
   persistido em texto plano em lugar nenhum (só o `creditCardToken` resultante é guardado em
   `tenants.asaas_card_token`), a function roda em ambiente serverless efêmero (Deno Edge Function,
   sem log do payload), e o objeto `cartao` nunca é gravado em nenhuma tabela/log da aplicação.

**Aceito como risco/dívida técnica consciente — não como decisão definitiva.** Revisitar se: (a) o
Asaas lançar tokenização client-side no futuro, (b) o volume de transações justificar certificação
PCI-DSS formal, ou (c) o gerente de conta Asaas confirmar uma opção não documentada publicamente.

## Consequências
- (+) Trial sai do papel dentro do prazo da V1.5, sem depender de uma funcionalidade que o Asaas não
  oferece.
- (+) Mitigações de higiene aplicadas: sem persistência do cartão cru, sem log, HTTPS obrigatório.
- (−) O projeto tecnicamente transita dados de portador de cartão pela própria infra — escopo
  PCI-DSS SAQ D não eliminado, só mitigado operacionalmente.
- (−) **Rate-limit/anti-abuso vira prioridade alta** (antes era só "antes de expor de verdade" pro
  `criar-checkout`; agora um dos dois endpoints públicos de cadastro também recebe dados de cartão) —
  implementado nesta mesma sessão, ver `docs/roadmap-v15.md`.
- (−) O formulário da landing precisa seguir higiene mínima no client: nunca logar/persistir o
  cartão (`localStorage`/`sessionStorage`/console), `autocomplete="cc-number"`/`cc-name"`/`cc-exp`/
  `cc-csc"` corretos, `inputmode="numeric"`, limpar o formulário logo após o envio, HTTPS (já
  garantido — GitHub Pages serve só HTTPS).

## Alternativas consideradas
- **Tokenização client-side via SDK do Asaas**: não existe hoje (confirmado na documentação oficial).
  Não descartada por preferência — descartada por não estar disponível.
- **Pausar o trial até confirmar com o gerente de conta Asaas**: rejeitada por risco ao prazo da V1.5;
  pode ser revisitada depois do lançamento se o volume justificar.
- **Adotar outro processador com tokenização client-side nativa** (ex.: Stripe): fora de escopo —
  trocar de processador de pagamento é uma decisão de produto/negócio muito maior que este ADR, não
  uma decisão técnica isolada.
