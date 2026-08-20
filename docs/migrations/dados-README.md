# Migrations do projeto analítico (`dados-*`)

Estas migrations **não rodam no projeto de produção**. O prefixo `dados-` marca que o alvo é o
projeto Supabase separado, criado depois do incidente de 19/08 (ver `docs/adr/0005-onde-mora-a-area-de-dados.md`).

| | |
|---|---|
| Organização | **Mimba Lab** (`nlcyadrzcjdwyhzlfupk`) — org de tudo que NÃO é produção |
| Projeto | **mimba-analytics** (`njynlsugmvtuvcczmuld`) |
| URL | `https://njynlsugmvtuvcczmuld.supabase.co` |
| Região | South America (São Paulo) |
| Plano | Free |

A skill `nova-migration-tenant` **não se aplica** aqui: não existe schema `cab_*` neste projeto,
e `public` não é template de nada. É um banco comum.

## Por que a org chama "Mimba Lab"

Na Supabase, organização é fronteira de **plano e cobrança** — e a plataforma não deixa misturar
projeto pago e gratuito na mesma org. Como produção precisa ir para Pro (o plano Free **não tem
backup automático nenhum**, lição do incidente) e o analítico fica no Free, os dois têm
obrigatoriamente que morar em orgs diferentes. Não é preferência de organização, é imposição.

Daí a divisão ser por **ambiente**, não por assunto:

| Org | Plano | O que mora |
|---|---|---|
| `Mimba` *(a criar, quando produção sair da conta pessoal do Luciano)* | Pro | produção |
| **`Mimba Lab`** *(esta)* | Free | tudo que **não** é produção |

Nomes por feature (`mimba-dados`, `mimba-analytics`) foram descartados de propósito: esta org
deve caber também homologação e experimentos. Hoje homologação divide o banco de produção — o
que obrigou o filtro `ambiente_teste` para esconder cabanhas reais de quem testa. Um projeto de
homologação aqui elimina esse remendo e torna impossível um teste encostar em dado de cliente.

## Ordem de aplicação

| # | Arquivo | Quando |
|---|---|---|
| 0 | `dados-2026-08-20-fase0-staff.sql` | primeiro — todo o resto pendura RLS neste gate |
| 1 | `dados-2026-08-20-fase1.sql` | tabelas, RLS, bucket, RPCs de catálogo |
| 2 | `dados-2026-08-20-fase2-abccc.sql` | importador da ABCCC (pg_net + decodificador DSR) |
| 3 | `dados-2026-08-20-fase3-analises.sql` | view tipada e RPCs de análise |
| 4 | `dados-2026-08-20-fase3b-matview.sql` | materialized view + refresh |
| — | **carregar os dados** | pela tela, ou pelo importador da ABCCC |
| 5 | `dados-2026-08-20-fase4-indices-pos-carga.sql` | **só depois da carga** |

Entre a fase 0 e a fase 1 há um **passo manual**: criar os usuários do staff em
Authentication → Users e rodar o `insert` comentado no fim da fase 0.

## O que mudou em relação às originais

As `2026-08-19-area-dados-fase*.sql` continuam no repo como registro do que rodou em produção.
Estas são as mesmas, com três correções — todas atacando a causa do incidente, que foi **padrão
de escrita**, não volume (84 mil linhas é pouco; o problema era como estavam sendo inseridas):

1. **`insert ... select` no lugar do loop** (fase 2). O `abccc_importar_coletar` fazia um INSERT
   por linha dentro de um loop plpgsql. Agora acumula num `jsonb[]` e grava tudo de uma vez.
   Semântica idêntica: `linha` continua sendo `v_base + posição`.

2. **Índices de expressão saem para depois da carga** (fase 1 → fase 4). Eram criados junto da
   tabela, então cada INSERT reavaliava 4 extrações de jsonb e mexia em 5 árvores de índice.
   Agora entram com `create index concurrently` depois que os dados já estão lá.

3. **`refresh materialized view concurrently`** (fase 3b). O refresh normal pega `ACCESS
   EXCLUSIVE` e trava qualquer leitor enquanto reconstrói 83.778 linhas e 7 índices. O
   concorrente exige índice unique — daí `registro_id` (a PK de `dados_registros`) ter entrado
   na projeção da matview. Nenhuma combinação das colunas de negócio é confiavelmente única.

## Invariante do ADR 0005 — não quebrar

> Nenhuma requisição originada de uma cabanha pode tocar este projeto — nem direta, nem por proxy.
> Se ele estiver pausado, morto ou inexistente, o app de produção continua funcionando por inteiro.

Na prática: o `index.html` **não** ganha um segundo client Supabase apontando pra cá, e **não**
existe edge function em produção fazendo proxy pra cá. O app lê um artefato JSON estático
publicado no GitHub Pages, gerado a partir daqui. As RPCs `ref_abccc_animal` e
`ref_abccc_reprodutor` existem neste projeto para uso do staff, não para o app.

## Diferenças de plataforma que vão morder

- Este projeto nasceu com as **chaves novas** (`sb_publishable_…` / `sb_secret_…`), enquanto
  produção usa as legadas (`anon` / `service_role` em JWT). Código copiado de lá não roda aqui
  sem ajustar isso. Existe aba "Legacy anon, service_role API keys" se um dia interessar uniformizar.
- **"Automatically expose new tables" está desligado** e **"Enable automatic RLS" ligado**, ao
  contrário do padrão da Supabase. Tabela nova aqui **não** aparece sozinha na API e **já nasce**
  com RLS ligada — é preciso conceder acesso de propósito. Isso é intencional: este projeto
  recebe SQL ad-hoc, inclusive gerado por LLM, que cria tabela sem pensar em policy.
- A **senha do banco** foi gerada pela Supabase na criação e não foi registrada em lugar nenhum.
  Para obter a connection string direta (necessária para plugar num MCP), use
  Settings → Database → **Reset database password** e guarde no gerenciador de senhas.
- `pg_net` precisa estar habilitado para o importador da ABCCC funcionar (fase 2).
  Database → Extensions → `pg_net`.
