## Quando a fixture mente, a contra-prova de mutação mente junto {#fixture-que-mente-faz-a-mutacao-mentir-junto}

`tags: fixture, mutacao, contra-prova, falso verde, produtor real, teste que nao testa, review, cobertura ilusoria, deploy`

**Sintoma:** um caminho tem teste verde **e** alvo de mutação **morto** — as duas garantias mais
fortes que a casa tem — e mesmo assim ele está quebrado em produção, em **toda** chamada real.

**Causa raiz:** a fixture inventa a forma do dado. O teste mede o produtor que **imaginamos**, não o
que responde. E como o alvo de mutação roda **contra a mesma fixture**, ele morre lindamente — sobre
um caminho que produção nunca percorre. A mutação não valida a fixture; ela herda a mentira dela.

**O caso (tiatendo, frente cidade-inteira, 2026-08-20):** o juiz de área lia `tenantConfig.get("city")`
e `.get("uf")` da row do banco para restringir o geocoding à cidade do tenant. A tabela `tenants`
**não tem** essas colunas — conferido no DDL e em todo `ALTER TABLE` de 034 a 118. Em produção os
dois chegavam `None`, o filtro nunca era enviado, e o defeito que o requisito existia para matar
(*"Centro"* devolvendo Albacete/Espanha) seguia vivo — com dano ativo: endereço sem cidade podia
virar recusa de venda legítima.

Passou por **13 reviews de task**. A fixture montava `{"ibge_municipio_code": …, "city": …, "uf": …}`
à mão. E o alvo de mutação daquele `if` **morria** contra ela.

**Como achar:** pergunte de cada fixture **de onde vem a forma**. Se a resposta for "escrevi olhando
o código que consome", é candidata. Prova barata: rode o produtor real uma vez e compare as
**chaves** — não os valores. Num caso irmão da mesma frente, três espelhos de CEP devolviam `ibge`
(um deles como **dict aninhado**) e a fixture inventava `city_ibge`, chave que **nenhum** deles
devolve; nove testes verdes sobre código que estourava `TypeError` em toda consulta real.

**O conserto que fecha a classe (não a ocorrência):** faça a fixture **nascer do produtor** — rode
`fetchTenant`/o cliente HTTP/a query de verdade contra o banco efêmero e use o que voltou. E depois
**apague o lugar onde dava para inventar**: no caso do tiatendo, os parâmetros `tenantCity`/`tenantUf`
saíram da assinatura da função. Enquanto o parâmetro existir, existe onde inventar chave.

**Corolário, e é o mais caro:** **review lê código; mutação testa o teste; só o produtor testa a
fixture.** Nenhuma das três substitui as outras. Na mesma frente, uma review cuidadosa aprovou — com
razão sobre o código — uma gravação que podia ser **apagada** com a suíte continuando verde; quem
pegou foi a mutação. E a mutação só não pegou o caso `city`/`uf` porque a fixture mentia para as
duas.

Ver [[golden-de-regressao-que-guarda-caminho-morto]].
