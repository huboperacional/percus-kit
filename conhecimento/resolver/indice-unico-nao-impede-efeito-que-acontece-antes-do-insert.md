## Índice único não impede o efeito que acontece ANTES do INSERT {#indice-unico-nao-impede-efeito-que-acontece-antes-do-insert}

`tags: postgres, índice único, corrida, dedupe, savepoint, idempotência, migration, sqlalchemy`

**Sintoma:** você tem `SELECT count(...)` seguido de `INSERT` como dedupe, descobre que o lock que
o protegia é best-effort, e resolve com um índice `UNIQUE`. A migration promete que "o efeito
duplicado não acontece mais". **Não é verdade** se o efeito ocorre antes do INSERT.

**A corrida real, quando o INSERT vem depois do efeito:**

```
A conta 0 → A ENVIA → B conta 0 → B ENVIA → A commita → B estoura IntegrityError
```

As duas mensagens já saíram. O índice único converte **"duas linhas"** em **"uma linha + uma
exceção"** — ele protege a **contabilidade**, não o efeito externo.

**Decida a ordem sabendo o que cada uma custa:**

| Ordem | Protege | Falha assim |
|---|---|---|
| efeito → INSERT | nunca marca como feito algo que não foi | efeito duplicado sob concorrência |
| INSERT → efeito → DELETE se falhar | efeito não duplica | processo morre no meio: linha **fantasma** diz "feito", e nunca acontece |

▶ Para aviso ao cliente, **duplicado é irritante e perdido é dinheiro** — a ordem efeito→INSERT
costuma ser a certa. Escreva a razão na migration, senão a próxima pessoa "conserta" ao contrário.

🚨 **O índice único sozinho pode PIORAR as coisas.** Se o laço faz `session.add()` por item e **um**
`commit()` no fim, uma colisão em UM item derruba a transação inteira — perdem-se os registros de
todos os outros, **inclusive os cujo efeito externo já aconteceu**. Isole cada item:

```python
try:
    async with session.begin_nested():      # dá flush ao SAIR: o erro nasce aqui dentro
        session.add(Registro(...))
except IntegrityError as e:
    if not ehAColisaoEsperada(e):
        raise                                # NOT NULL / FK não são "corrida benigna"
    continue
```

🔎 *"`add()` não dá flush, então o `except` nunca é alcançado"* é um finding comum e **falso**:
`begin_nested()` flusha ao sair do contexto. Prove por mutação — troque o `async with` por `if
True:` e veja o teste da colisão reprovar.

🪤 **Classificador de exceção nasce largo.** `except IntegrityError` pega NOT NULL e FK também.
Filtre pelo nome do constraint, **derivado do metadata do modelo** (nunca cravado), e devolva
"não é a colisão esperada" na dúvida. Cuidado com fallback por substring: `NOT NULL constraint
failed: tabela.coluna` contém o nome da coluna e passaria por unicidade — exija também
`UNIQUE constraint failed`.

Irmão: [[teste-escrito-junto-com-o-codigo-herda-a-premissa-errada]]
