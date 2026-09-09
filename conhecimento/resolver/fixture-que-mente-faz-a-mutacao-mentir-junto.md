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

---

### Variante MAIS PERIGOSA: o fake que **COMPENSA** o defeito (tiatendo, 06/09)

Nas ocorrências acima a fixture **mente** sobre o dado. Nesta, ela **supre o que o código deveria
fazer** — e aí não há texto errado em lugar nenhum: a prova em si é oca, e passa em verde para
sempre. Duas sessões acharam a mesma forma no mesmo dia, com uma hora de diferença, em fakes
escritos independentemente:

- **Fake aplicando o predicado por conta própria.** O teste guardava o SQL
  `WHERE id > $2`, e o `_fetchFalso` filtrava com `r["id"] > afterId` **fixo em Python**, ignorando
  a query capturada. Mutar o SQL para `id >= $2` não mudava o resultado: só o `assert "id > $2" in
  query` matava o mutante, enquanto o comentário ao lado anunciava a asserção de comportamento como
  prova do predicado. **Duas provas prometidas, uma entregue.**
- **Fake normalizando a entrada por conta própria.** O corpus falso aplicava `afterId or 0`
  sozinho, então mutar o `or 0` do código de produção **sobrevivia a tudo**. E o alvo não era
  cosmético: `closeEpisode` passa `None` exatamente quando a conversa ainda **não tem episódio**, e
  em SQL `id > NULL` não é falso — é NULL, zero linhas. Sem o `or 0`, **nenhuma conversa ganharia
  jamais o primeiro episódio**, sem erro e sem log.

🔑 **Como procurar, e é uma pergunta só:** para cada operação que o CÓDIGO faz (filtrar, ordenar,
normalizar, defaultar), pergunte *o meu fake faz essa mesma operação por conta própria?* Se faz, ele
**não pode** provar aquela operação — no máximo prova o texto dela. O fake tem que **honrar a
entrada** (ler a query capturada, respeitar o parâmetro recebido) em vez de reimplementar a regra.

🪤 **O sinal de alerta barato:** um fake que honra UMA dimensão e não a outra. No caso medido, o
mesmo `_fetchFalso` já honrava a ordenação (`reverse=` lido da query) e **não** honrava o predicado
— a inconsistência estava visível o tempo todo e ninguém a leu como defeito.

**Conserto aplicado:** o fake passou a derivar o operador da query (`operator.ge` quando
`id >= $2` aparece, senão `gt`); a mutação que antes sobrevivia passou a falhar por
**comportamento** (`[25,26,…] != [26,…]`), não mais só por texto. Do outro lado, o alvo do `or 0`
entrou no runner de mutação contra Postgres real (7/7 → 8/8) e ganhou teste passando `None`.

**Corolário que se soma ao de cima:** o produtor testa a fixture, mas **quem denuncia o fake que
compensa é a mutação do alvo que o fake supre** — e ela só existe se alguém listar aquele alvo.
Alvo não listado é buraco que nenhuma das três camadas vê.
