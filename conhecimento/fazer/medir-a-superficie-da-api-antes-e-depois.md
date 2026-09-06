## Medir a superfície da API antes e depois de um refactor que "não muda comportamento" {#medir-a-superficie-da-api-antes-e-depois}

`tags: fastapi, openapi, contrato de api, refactor, tipagem, verificacao, controle positivo, git archive, procedimento, R23`

**Quando usar:** todo refactor que toca a camada de rotas e se declara neutro — tipagem, rename,
extração de helper, troca de dependência. "Parece só anotação" é exatamente o caso em que o diff
engana: o efeito não está nas linhas, está na diferença entre duas aplicações montadas.

**Pré-requisito:** um interpretador com as deps da app. Se a app real não importa no ambiente local
(dependência de observabilidade ausente, por exemplo), monte uma sonda: um `FastAPI()` novo com os
mesmos `include_router()` do `main.py`.

### Procedimento

1. **Extraia o estado ANTES sem tocar a working tree** (outra sessão pode estar trabalhando nela):

   ```bash
   git archive <sha-antes> | tar -x -C /tmp/antes
   ```

2. **Cuidado com o CWD.** Se a raiz do repo tem um `.env` com chaves que o `Settings` do projeto
   rejeita (`extra=forbid`), montar a app da raiz explode com `extra_forbidden`. Rode com o CWD
   dentro do diretório de código (`backend/`, `src/`, o que for).

3. **Dump da superfície nos dois estados.** Por rota: `path`, `methods`, `repr(response_model)`,
   se há `response_field`, e `status_code`. Se conseguir gerar `app.openapi()`, melhor: compare o
   JSON inteiro (`md5` já resolve).

4. **Controle positivo ANTES de confiar em qualquer zero.** Compare primeiro dois estados que você
   *sabe* que diferem (ex.: o estado quebrado contra o original) e confirme que o harness acha
   exatamente as rotas esperadas — nem mais, nem menos. Só então o zero da comparação seguinte
   significa alguma coisa. Sem esse passo, "nada mudou" e "o harness está mudo" são
   indistinguíveis.

5. **Compare as dimensões separadamente**, porque elas falham de jeitos diferentes:
   `response_model` · `has_response_field` (a validação ligou?) · `status_code` · o schema em si.

### Exemplo de saída que fecha o caso

```
md5  antes/openapi.json   50de03b970708b7d57368b3a87c10e8b   (203 paths, 329 schemas)
md5  depois/openapi.json  50de03b970708b7d57368b3a87c10e8b
diff -> 0 linhas
has_response_field: 0 divergencias em 281 rotas
status_code:        0 divergencias em 281 rotas
```

### Depois de medir: transforme em guarda

Medição manual não sobrevive à próxima pessoa. Congele a superfície num fixture versionado com um
teste que falhe nomeando a rota que mudou e dizendo como regenerar de propósito. Dois cuidados que
já custaram caro:

- Se a sonda **reconstrói** a lista de routers, acrescente um teste que leia o arquivo real com
  `ast` e compare com esse espelho — senão um router novo escapa da cobertura em silêncio, e a
  guarda passa a afirmar uma superfície que não é a real.
- **Diga no docstring o que a guarda NÃO pega.** Guarda superestimada é pior que guarda ausente,
  porque compra confiança que ela não sustenta.

**Ver também:** `resolver/anotar-handler-fastapi-cria-response-model-e-muda-o-contrato`,
`zero-so-vale-com-controle-positivo`.
