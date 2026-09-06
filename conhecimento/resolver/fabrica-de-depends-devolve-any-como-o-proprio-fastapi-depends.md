## Fábrica de `Depends` devolve `Any`, como o próprio `fastapi.Depends` — `-> User` "de propósito" quebra o outro idioma {#fabrica-de-depends-devolve-any-como-o-proprio-fastapi-depends}

`tags: fastapi, depends, mypy, strict, dependency factory, require_role, Any, no-any-return, dependencies, anotacao mentirosa, R23`

**Sintoma:** ao tipar uma fábrica de dependência do FastAPI (`def require_role(*roles) -> ???:
... return Depends(_check)`), o implementador anota `-> User` "para o idioma
`_user: User = require_role(...)` continuar tipando" e cala o `no-any-return` com um
`# type: ignore`. Parece o único jeito.

**Causa raiz:** é um falso dilema. `fastapi.Depends` é declarado `-> Any` (`param_functions.py`)
justamente para poder ser valor-default de parâmetro de **qualquer** tipo. A fábrica que devolve
`Depends(...)` tem a mesma função e a mesma assinatura honesta: `-> Any`. Com `-> User`, o **outro**
idioma vivo — `@router.post(..., dependencies=[require_role(...)])`, tipado
`Sequence[params.Depends]` — dá `List item 0 has incompatible type "User"; expected "Depends"`. O
erro fica mascarado enquanto os routers que usam esse idioma ainda estão no baseline, e explode na
fatia seguinte.

**Medido em Plexco Tasks (2026-09-05, fatia 8a1):** o revisor escreveu uma sonda com os dois idiomas
e rodou `mypy --strict`: com `-> User`, erro em `me_billing.py:262,306,360,415`; com `-> Any`, exit 0
sem nenhum ignore. `require_role` tinha 41 usos em 9+ módulos, não "2 arquivos" como o relatório
dizia.

**Como aplicar:** fábrica de dependência → `-> Any` com comentário dizendo que espelha
`fastapi.Depends`. Quando a anotação honesta parece "perder" o tipo, procure a assinatura que a
própria biblioteca usa para o mesmo papel antes de mentir e calar.
