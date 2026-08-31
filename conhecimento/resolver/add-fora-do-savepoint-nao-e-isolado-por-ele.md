## `session.add()` fora do `begin_nested()` não é desfeito por ele — o objeto continua pendente e o próximo flush refalha {#add-fora-do-savepoint-nao-e-isolado-por-ele}

`tags: sqlalchemy, savepoint, begin_nested, IntegrityError, PendingRollbackError, autoflush, unit of work, corrida, UNIQUE, 409, transacao unica`

**Sintoma:** o padrão de traduzir colisão de UNIQUE em 409 — `try: async with
session.begin_nested(): await session.flush()` / `except IntegrityError:` — funciona
quando a exceção é propagada na hora, e **quebra** assim que o `except` faz mais uma
consulta antes de levantar. O erro que chega não é o `IntegrityError` esperado: é
`PendingRollbackError: This Session's transaction has been rolled back due to a previous
exception during flush`. Variante próxima: quem tenta consertar com `session.expunge(obj)`
ganha um `InvalidRequestError` **em cima** do `IntegrityError` — dois erros para um fato só.

**Causa raiz:** o SAVEPOINT desfaz o que foi ESCRITO dentro dele, não o que foi ANEXADO à
sessão fora dele.

```python
session.add(linha)                      # <- pendente na SESSÃO, fora do savepoint
try:
    async with session.begin_nested():  # SAVEPOINT
        await session.flush()           # INSERT -> IntegrityError
except IntegrityError:
    ...consulta para descobrir quem venceu...   # <- autoflush REINSERE `linha`
```

Depois do rollback do savepoint, `linha` **continua no `session.new`**. Qualquer flush
posterior a reinsere e bate no mesmo índice — inclusive o flush AUTOMÁTICO que uma
`select()` dispara. A leitura de recuperação recria exatamente o erro que estava tratando.

**Correção — as duas coisas, e a primeira é a que importa:**

```python
try:
    async with session.begin_nested():
        session.add(linha)              # <- DENTRO: o rollback do savepoint o descarta
        await session.flush()
except IntegrityError as erro:
    with session.no_autoflush:          # <- a consulta não dispara flush por conta própria
        vencedora = (await session.execute(select(...))).scalar_one()
    raise JaExiste(f"... em {vencedora.criadoEm:%d/%m/%Y}") from erro
```

Nada de `expunge()`: o rollback do savepoint já descartou a linha, e chamá-lo depois
levanta `InvalidRequestError`.

**Por que isto passa despercebido:** o mesmo helper, sem a consulta no `except`, funciona
perfeitamente — é o padrão que a maior parte do código usa, porque quase sempre basta
traduzir a exceção e sair. O defeito só aparece quando alguém precisa **ler algo depois da
colisão**, que é justamente o caso em que a mensagem de erro fica boa ("já existe, aplicado
em 30/08") em vez de genérica.

**Caso medido (Empresa Milionária, 2026-08-30, FR-136):** aplicar template de nicho recusa
a re-aplicação com 409 nomeando a data da aplicação existente. A conferência prévia por
`SELECT` cobre o caso comum; o `except IntegrityError` existe para a CORRIDA — dois cliques
no mesmo botão, em que a segunda transação ainda não enxerga a primeira. O teste da corrida
foi escrito depois de um review apontar que o docstring do modelo já descrevia esse
comportamento **antes de ele existir no código**, e foi ele que expôs os três degraus:
`IntegrityError` cru → `PendingRollbackError` → `InvalidRequestError` do `expunge`, um a
cada tentativa de conserto, até o `add` mudar de lugar.

**Como testar a corrida sem concorrência de verdade:** grave a linha vencedora, depois
neutralize a conferência prévia (é o que a concorrência faz — a perdedora não vê a
vencedora quando consulta) e deixe só o índice de pé. ⚠️ Não neutralize as OUTRAS
conferências junto: se as tabelas dependentes também colidirem, o teste morre no índice
errado e passa verde sem nunca exercitar o caminho que existe para provar.

Relacionado: [[sem-relationship-o-unit-of-work-nao-ordena-insert]],
[[commit-num-handler-pj-mata-o-contexto-de-rls]].
