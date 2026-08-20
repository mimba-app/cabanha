# Painel de resultados ABCCC — extração

Fonte: <https://www.cavalocrioulo.org.br/eventos/painel_resultados>
(a página é só um wrapper; o conteúdo é um relatório Power BI *publish-to-web*)

## Como os dados são obtidos

O visual de tabela do relatório é virtualizado e carrega os dados em segmentos de 500
linhas — raspar o DOM com auto-scroll funciona, mas é lento e frágil. Em vez disso,
`extrair.mjs` replica a própria requisição `querydata` do relatório (`query.json`),
pedindo uma janela de 30.000 linhas por página e paginando pelos *restart tokens*.
A resposta vem no formato DSR compactado do Power BI (dicionários de valores +
bitmasks `R` de repetição e `Ø` de nulo), que o script decodifica.

Nenhuma credencial é necessária: o relatório é público e a única chave usada
(`X-PowerBI-ResourceKey`) é a que está no próprio link de embed da ABCCC.

## Uso

```bash
node extrair.mjs                 # ciclo 2026 (o padrão do painel)
node extrair.mjs --ciclo=all     # série histórica completa
node extrair.mjs --ciclo=2024,2025 --saida=recorte.csv
```

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `painel-resultados-2026.csv` | 3.448 linhas — o que o painel mostra por padrão |
| `painel-resultados-todos-ciclos.csv` | 83.778 linhas — ciclos 1982 a 2026 |

Colunas: `SBB, Animal, Sexo, Pai, Mãe, Criador, Ciclo, Cidade, Prova, Colocação`.
CSV em UTF-8 com BOM (abre direto no Excel).

## Filtros embutidos na query

São os filtros que o próprio painel aplica — não é a base bruta da ABCCC:

- `Prova` ∈ 17 provas (morfologias, credenciadoras, classificatórias, Bocal de Ouro, Final Freio de Ouro)
- `pontos > 0`
- `Colocação` ∈ 18 premiações (campeão/reservado de categoria, grande campeão, 1º a 8º lugar, 3º/4º melhor)
- `Ciclo = 2026` — este é o único removido/alterado pelo `--ciclo`

## Validação feita

- 12 linhas lidas do DOM renderizado conferem 1:1 com o CSV, na mesma ordem
- 0 duplicatas exatas (páginas de continuação repetem a linha do restart token; o script descarta)
- O recorte de 2026 dentro do arquivo completo é idêntico ao arquivo de 2026

`Criador` vem vazio em 1.864 linhas — é nulo na origem (o painel tem a opção "(Em branco)" nesse filtro).
