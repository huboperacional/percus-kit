## Mock do DAO esconde erro de CHAVE e de serialização — se a mudança é de banco, o teste é de banco {#mock-dao-esconde-chave}

`tags: mock dao chave lookup normalizacao jsonb serializacao teste banco postgres`

tags: mock esconde bug, DAO, chave de lookup, normalizacao de telefone, E164, JSONB volta string, set_type_codec, teste de banco, postgres efemero, ida e volta, invariante de persistencia

**Sintoma:** a feature tem testes de sobra (dezenas, todos verdes) e não funciona contra o banco
real. Ou pior: funciona hoje e quebra quando o caller muda de formato.

**Causa concreta que apareceu:** a fachada GRAVAVA com a chave crua (`+5567999…`) e LIA com a chave
normalizada (só dígitos). Escrita e leitura em chaves diferentes → o estado some **em silêncio**.
Todo teste passava porque mockava o DAO: o mock devolve o que você guardou, na chave que você usou.
Havia ainda o irmão da mesma família: JSONB que volta como **string** quando o driver não tem codec,
e o `.get()` do consumidor levanta `AttributeError` atrás de um `try/except` fail-open.

**Como resolver:** ao mudar invariante de persistência (o que grava, o que apaga, qual a chave),
escreva UM teste que faça a **ida e volta no banco de verdade** — gravar, ler, e usar o valor lido
no consumidor real. Num projeto onde os testes de DB pulam sem DSN, isso significa rodar o recorte
num Postgres efêmero antes de considerar pronto.

**Regra prática:** mock prova FLUXO; banco prova CHAVE, TIPO e DEFAULT. Mudou fluxo, mocke. Mudou
schema/chave/serialização, não tem jeito: banco.
