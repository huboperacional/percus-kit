## `responses` de módulo compartilhado entre rotas FastAPI vaza título e duplica o `anyOf` no OpenAPI {#fastapi-responses-de-modulo-compartilhado-vaza-titulo-e-duplica-anyof}

`tags: FastAPI, OpenAPI, responses, dicionario compartilhado, mutacao, anyOf, title, operationId, openapi-typescript, contrato, tipos gerados, R23`

**Sintoma:** no `openapi.json` gerado, a resposta 422 de uma rota traz o `title` de OUTRA rota (`Response 422 Concluirconexaodrive …`
dentro de `iniciarConexaoDrive`), e o `anyOf` repete as mesmas alternativas (`Recusa | Erro | Recusa | Erro`). Os tipos gerados
pelo `openapi-typescript` herdam a união repetida. Rotas irmãs com o mesmo desenho, declarado inline, saem certas.

**Causa:** um `RESPOSTAS = helper(...)` no nível do módulo, passado como `responses=RESPOSTAS` para duas rotas. Ao montar o
OpenAPI, o FastAPI escreve DENTRO do dicionário de cada resposta (`setdefault` no `content`, `deep_dict_update` do `anyOf`): a
segunda rota encontra o que a primeira já escreveu — título e alternativas acumulados.

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, guarda do documento):** `POST .../conexao-drive/inicio` e
`.../retorno` compartilhavam `RESPOSTAS`; varredura do `openapi.json` inteiro achou `anyOf` repetido **só** nessas duas rotas. O
helper do projeto (`respostasDeErro`) já avisava no docstring "dicionário novo a cada chamada" — a rota que o chamou uma vez só
anulou o aviso. Pego pelo review do contrato regenerado, não pelos testes de rota.

**Conserto:** chamar o helper por rota (`responses=_respostas()`), nunca guardar o resultado em constante de módulo. Teste de
contrato sobre `app.openapi()`: nenhum `anyOf` com alternativa repetida e o `title` de cada resposta contendo o `operationId` da
própria rota, com piso de quantas respostas foram conferidas. Sabotagem: voltar à constante de módulo → vermelho.
