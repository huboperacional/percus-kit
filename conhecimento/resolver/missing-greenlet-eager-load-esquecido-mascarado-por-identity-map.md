## MissingGreenlet esporádico: falta eager-load, mas só estoura quando o objeto não está por acaso já na sessão {#missing-greenlet-eager-load-esquecido-mascarado-por-identity-map}

`tags: sqlalchemy, async, MissingGreenlet, selectinload, eager load, identity map, lazy load, pydantic model_validate, FastAPI, 500 silencioso, teste manual mascara bug, react-query error handling`

**Contexto:** duas rotas GET servem "a mesma tela" (ex.: um badge de contagem e a lista que ele
resume) via duas queries SQLAlchemy diferentes. Uma tem `selectinload(Model.relationship)` na
serialização de resposta; a outra, esquecida no mesmo refactor, não tem. O sintoma NÃO parece "erro
de carregamento" — parece **filtro**: o badge mostra N, a lista mostra 0 (ou menos que N), e o
frontend não distingue "a API deu erro" de "a API devolveu vazio" (React Query: `data` fica
`undefined` nos dois casos se o componente só checa `tasks.length === 0`).

**Causa raiz:** `Pydantic.model_validate(orm_object)` acessa um relationship não eager-loaded durante
a serialização (fora do `await`). Em SQLAlchemy async, isso dispara `MissingGreenlet:
greenlet_spawn has not been called` — o lazy-loader precisa do `await` explícito que só existe
dentro do `session.execute(...)`, e a serialização síncrona do Pydantic não está mais dentro dele.

**Por que é ESPORÁDICO, não sempre**: SQLAlchemy resolve relationships many-to-one via *identity
map* antes de tentar I/O — se o objeto alvo (ex.: o `User` autor de uma linha) já está carregado na
MESMA sessão por OUTRO caminho (o `current_user` da request, ou um assignee de outra linha da mesma
página), o acesso "funciona" sem lazy-load real, sem erro. Só estoura quando o objeto referenciado
NÃO está por acaso já resident — e isso é comum acontecer só pra ALGUNS registros de dados reais
(ex.: uma linha criada por um terceiro que nunca aparece em nenhum outro relationship carregado da
página), nunca pros dados de teste manual/dev (você só cria SUAS próprias coisas, então o
`current_user` sempre cobre o caso).

**Diagnóstico (a ordem que funciona):**
1. Comparar as `.options()` das duas queries lado a lado — o relationship que falta é o campo que a
   serialização (`Response.model_validate`) usa e uma das duas não pré-carrega.
2. Reproduzir chamando a FUNÇÃO DA ROTA inteira (não só a query SQL) contra dado real — um script
   dentro do container, com `db`/`org_id`/`current_user` reais, chamando a função do endpoint direto.
   A query sozinha "parece perfeita"; o traceback só aparece na hora de serializar a resposta.
3. Achar QUAL registro dispara: geralmente é o que tem uma FK apontando pra algo fora do conjunto já
   eager-loaded (ex.: criado por alguém que não é assignee de nada na página).

**Fix:** adicionar o `selectinload()` faltante, igual ao da rota que já funcionava.

**Teste que prova (e não mascara pela sorte da identity map):** seed um registro cuja FK relevante
aponta pra um TERCEIRO objeto — não o ator do teste, não algo já tocado por outro eager-load do
mesmo teste. Sem isso o teste passa com o bug vivo, pelo mesmo motivo que o bug passa despercebido
em uso manual.

**Corolário de UX:** se o frontend não distingue "erro" de "lista vazia" (comum: `catch` genérico ou
simplesmente checar `.length === 0` sem olhar `isError`), um 500 nesse endpoint produz um estado
vazio silencioso e enganoso pro usuário — nenhum toast, nenhuma pista.

**Ref:** Plexco Tasks s163 — `GET /tasks/mine` faltava `selectinload(Task.creator)` que `GET /tasks`
já tinha; "Minhas tarefas" mostrava fila vazia pro usuário real (14 tarefas, badge certo) porque UMA
das 14 tinha sido criada por outra pessoa.
