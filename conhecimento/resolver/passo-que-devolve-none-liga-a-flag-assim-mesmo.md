## Passo que devolve `None` em vez de levantar liga a flag assim mesmo {#passo-que-devolve-none-liga-a-flag-assim-mesmo}

`tags: gate, retorno ignorado, None, savepoint, best-effort, falha silenciosa, invariante, onboarding, tela que mente, SQLAlchemy`

**Sintoma:** um endpoint grava o estado "ligado" de um modo/feature mesmo quando o passo que
deveria preparar esse estado **não fez nada**. A resposta HTTP diz que deu certo. Ninguém vê erro
— nem log de exceção, nem 4xx, nem aviso na tela.

**Causa:** a função preparadora sinaliza falha **devolvendo `None`**, não levantando. Quem chama
descarta o retorno e segue:

```python
async with db.begin_nested():
    await ensure_generic_cliente_for_bootstrap(db, org.id)   # devolve None quando nao ha o que promover
    org.client_project_mode = True                           # liga mesmo assim
```

O `async with` não aborta porque **não houve exceção**. O savepoint fecha com sucesso, a flag é
gravada e o commit externo a persiste.

**Caso medido (2026-09-18, Plexco Tasks, Task 18 do plano cliente-projeto-vinculo):** o preparador
promove o Projeto-base a par do Cliente genérico e devolve `None` quando não existe Projeto-base
promovível. O bloco anterior do mesmo endpoint cria o Projeto-base em savepoint **best-effort**, que
engole falhas de propósito — e há teste consagrando esse comportamento. Combinando os dois: seed do
Projeto-base falha → savepoint 1 reverte → savepoint 2 recebe `None` sem exceção → organização
commitada em "modo vinculado" com **zero Projeto e zero Cliente**, e a resposta dizendo
`client_project_mode: true`. O aviso que o frontend mostra quando o modo não liga nunca dispara,
porque o backend afirmou que ligou.

**Conserto:** ligar o retorno ao invariante, levantando **dentro** do savepoint:

```python
generico = await ensure_generic_cliente_for_bootstrap(db, org.id)
if generico is None:
    raise RuntimeError("sem Projeto-base promovível: modo vinculado não pode ligar")
org.client_project_mode = True
```

E reportar o valor **real** lido da linha, nunca o que foi pedido no corpo da requisição.

**Como achar antes de produção:** o teste que morde é o que **combina os dois caminhos de falha** —
sabotar o passo anterior (que é best-effort) *e* pedir a feature. Testar cada um sozinho passa: o
caminho feliz cria tudo, e o caminho "pedido ausente" não liga nada. A combinação é que revela a
mentira.

**Regra geral:** contrato que sinaliza falha por valor de retorno só funciona se **todo** call-site
verificar. Num passo que estabelece invariante, prefira exceção — ela é verificada por construção.
A mesma classe já apareceu no envio de mensagem: um kill switch que **devolvia** `(False, "blocked")`
em vez de levantar deixou o chamador gravar "já avisei" a partir de um retorno que ele não conferia.
Para o limite dos savepoints, ver [[add-fora-do-savepoint-nao-e-isolado-por-ele]].
