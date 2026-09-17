## Guarda por AST que confere "a função chama X" aceita `X(...)` sem `await` — a corrotina nunca roda e a guarda fica verde {#guarda-por-ast-de-chamada-async-aceita-a-corrotina-sem-await}

`tags: ast, guarda, teste de forma, async, await, corrotina, trava, with_for_update, sqlalchemy async, sabotagem, R23`

**Contexto:** Empresa Milionária, 17/09/2026, V2.3 Entregas. Várias guardas liam o AST de casos de uso async para garantir
invariantes que o SQLite da suíte não vê. Por exemplo: `travarItensDePedidos` é chamada, é chamada **antes** de somar,
é chamada **uma vez** e fora de laço, e o `refresh` vem depois da trava. Todas coletavam `ast.Call` pelo nome e comparavam
posição.

**O defeito:** `ast.Call` existe do mesmo jeito em `await travar(...)` e em `travar(...)`. Sem `await`, a chamada a uma
função `async def` só **cria a corrotina**: nada roda, nenhuma linha é travada, nenhum `refresh` acontece. Python emite
`RuntimeWarning: coroutine ... was never awaited`, e o pytest só mostra isso no resumo de warnings. A guarda de forma
continua verde, e os testes de comportamento **também**, porque uma transação só não precisa da trava para dar o
resultado certo.

**Medido (sabotagem, tirando só a palavra `await`):**

| Onde | Teste de forma antigo (`ast.Call`) | Teste de forma novo (`ast.Await` → `ast.Call`) | Testes de comportamento |
|---|---|---|---|
| trava em `situacao_entrega.py` | **verde** (1 passed) | vermelho | verdes |
| trava em `concluir_entrega.py` | **verde** (1 passed) | vermelho | verdes |
| `refresh` depois da trava | — | vermelho | verdes |

Só onde o retorno é **usado** (`travados = travar(...)` e depois `for item in travados`) o comportamento quebra sozinho,
com 22 vermelhos. É o caso que menos precisava da guarda.

**Conserto:** conte só a chamada **aguardada**.

```python
aguardadas = {id(n.value) for n in ast.walk(funcao) if isinstance(n, ast.Await)}
travas = [c for c in chamadas if nomeDe(c) == "travarItensDePedidos" and id(c) in aguardadas]
```

Aplique o mesmo às funções-núcleo chamadas pelos `executar` (`await _entregaTravada(...)`), e não só à trava.

**Prova de que o conserto discrimina:** rode a sabotagem "tire o `await`" contra a versão **antiga** da guarda (trocada
temporariamente por `git show HEAD:`) e confirme que ela passa verde. Sem essa negativa, "a guarda nova fica vermelha" não
prova que havia buraco.

**Regra geral:** toda guarda por AST sobre código async que afirma "X acontece" tem de afirmar "X é **aguardado**". Chamada
sem `await` a função async é a forma mais barata de desligar um efeito colateral e manter o texto do código "certo".

**Relacionados:** `conjunto-a-travar-lido-antes-da-trava-fica-velho.md`,
`guarda-por-ast-nao-casa-o-proprio-docstring` (memória do projeto).
