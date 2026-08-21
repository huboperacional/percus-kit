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


**Terceira forma, medida em 2026-08-21 (tiatendo, frente N27) — o fake esconde a SEMANTICA DE
SELECAO, e o mecanismo e pior que o do mock comum.** A query nova
`getLastRecoverableByConversation` escolhia "o ultimo pedido recuperavel da conversa" com
`ORDER BY updated_at DESC LIMIT 1`. Faltava `AND EXISTS (SELECT 1 FROM order_items ...)`, entao um
rascunho **VAZIO** mais recente **SOMBREAVA** o pedido abandonado que tinha itens: o bot respondeu
*"nao tenho esse pedido aberto aqui pra retomar"* com **R$ 42,90 recuperaveis na mesa**. A suite
estava verde, **inclusive o teste escrito de proposito para esse cenario**.

🔑 **Por que este e mais dificil de ver que o mock comum:** o fake e a query foram escritos **na
mesma sessao, pela mesma pessoa, a partir do mesmo modelo mental**. O fake encoda a **INTENCAO**
("o rascunho aberto vence; senao o abandonado"), a query encoda a **IMPLEMENTACAO** (`ORDER BY`
sem filtro). Quando as duas divergem, o teste mede a intencao e **passa por construcao** — ele
**nao pode** falhar. Nao e mock preguicoso; e mock *correto demais*.

**Detecção:** quando o teste do cenario que voce acabou de descobrir passa **sem voce ter tocado no
codigo de producao**, pare. Ou o comportamento ja existia, ou o teste esta medindo o dublê. Se o
dublê substitui uma **query**, e a segunda opcao ate prova em contrario.

**Regra prática (extensao):** o mock tambem esconde **QUAL LINHA** o banco escolhe — `WHERE`,
`ORDER BY`, `LIMIT`, join e filtro de candidato. Query nova com criterio de selecao **nao fica
provada por teste que a substitui**: rode-a contra dados reais e **compare as duas versoes** (com e
sem o filtro) no MESMO estado — se as duas concordam, a sonda nao prova nada. E escreva **no
docstring da funcao** que ela nao tem teste que execute o SQL, para o proximo leitor nao confiar no
verde da suite.

**Regra prática:** mock prova FLUXO; banco prova CHAVE, TIPO e DEFAULT. Mudou fluxo, mocke. Mudou
schema/chave/serialização, não tem jeito: banco.
