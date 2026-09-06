## Anotar o retorno de um handler FastAPI **cria** um `response_model` — e muda o contrato publicado sem ninguém ver {#anotar-handler-fastapi-cria-response-model-e-muda-o-contrato}

`tags: fastapi, response_model, openapi, contrato de api, mypy, tipagem, anotacao, validacao de resposta, ResponseValidationError, review que le diff, R23`

**Sintoma:** uma task de **tipagem** ("nenhuma mudança de comportamento", só anotação) é revisada,
aprovada e deployada. Semanas depois descobre-se que o `/openapi.json` mudou e que rotas passaram a
validar a resposta. Ninguém escreveu lógica nova. O diff parecia trivial: `async def f(...)` virou
`async def f(...) -> dict[str, str]`.

**Causa raiz:** o FastAPI **infere** o `response_model` a partir da anotação de retorno quando o
decorator não traz um `response_model=` explícito. As três situações são diferentes e só a primeira
é inócua:

| Antes | Depois de anotar | Efeito |
|---|---|---|
| decorator com `response_model=X` | qualquer anotação | **nada** — o explícito vence |
| retorno já anotado (ex.: `-> dict`) | `-> dict[str, Any]` | **nada** — schema idêntico |
| **sem anotação de retorno, sem `response_model=`** | `-> dict[str, str]` | **cria** o `response_model` |

No terceiro caso: `route.response_model` vai de `None` para o tipo, `has_response_field` vai de
`False` para `True`, o schema no `/openapi.json` sai de `{}` para um schema real, e passa a existir
um passo de validação de resposta. Enquanto todos os branches devolverem algo compatível, nada
quebra — mas um branch futuro fora do tipo vira **`ResponseValidationError` → 500** onde antes
serviria 200.

E não é só o schema: `response_model=None` e o inferido **não serializam igual**. Com `Decimal` no
payload, `None` devolve número JSON (`10.5`) e o inferido devolve string (`"10.50"`).

**Por que escapa da review:** porque o efeito **não está no diff**. Está na diferença entre dois
estados da aplicação montada. Um revisor que lê o diff vê uma anotação e conclui "é só tipo" — e
está lendo certo; o que falta é a medição.

**Medido em Plexco Tasks (2026-09-06):** duas fatias de tipagem (`05edf36`, `aa43908`) mudaram o
contrato de **9 rotas em produção**. Passaram por **2 reviews Opus e 2 conselhos 3/3 do R11** — seis
assentos, todos lendo o diff. A lição já estava **escrita** no plano do projeto desde a terceira
task. Escrita não bastou: só apareceu quando alguém montou a app nos dois estados e diffou o
`/openapi.json`.

**Como resolver:**

1. **Restaure**, não "melhore". Nas rotas que ganharam `response_model` do nada, acrescente
   `response_model=None` ao decorator, mantendo a anotação (o mypy precisa dela).
2. **Caso especial:** rota que *já tinha* implícito (via `-> dict` puro) e foi **estreitada**
   (`-> dict[str, bool | str]`) não volta com `response_model=None` — volta **alargando** para
   `dict[str, Any]`, cujo schema é idêntico ao de `dict`.
3. **Prove por medição**, não por leitura: extraia o commit anterior (`git archive <sha> | tar -x -C
   <dir>`), monte a app nos dois estados e compare o `/openapi.json` inteiro (md5 basta). **Com
   controle positivo antes** — compare primeiro contra o estado quebrado e confirme que o harness
   acha exatamente as rotas esperadas; sem isso, um zero pode ser só o harness mudo.

**Como impedir a recorrência:** lição escrita não vira verificação. Crie um teste que fixe a
superfície `{(método, path) -> (response_model, status_code)}` num fixture versionado, com mensagem
de falha que nomeia a rota e diz como regenerar de propósito. Dois cuidados:

- Se o teste **reconstrói** a lista de `include_router()` do `main.py` (porque importar o `main`
  puxa dependência ausente no ambiente local), acrescente um **segundo teste que lê o `main.py` com
  `ast`** e compara com esse espelho. Sem ele, um router novo no `main` sai da cobertura **em
  silêncio** — e a guarda passa a afirmar uma superfície que não é a real.
- Saiba o que a guarda **não** pega: fixando a *identidade* do `response_model`, ela não vê mudança
  no *conteúdo* de um schema explícito (apagar um campo passa batido). Fechar isso é guardar o
  schema inteiro no fixture, ao custo de churn de regeneração.

**Ver também:** `zero-so-vale-com-controle-positivo`, `fazer/medir-a-superficie-da-api-antes-e-depois`.
