## UUID sentinela só com dígitos vira inteiro na volta, e quebra o `TypeDecorator` {#uuid-sentinela-so-digitos-vira-inteiro-no-sqlite}

`tags: sqlite, uuid, type-affinity, typedecorator, sqlalchemy, teste, sentinela, empresa-milionaria`

**Contexto:** Empresa Milionária, 08/09/2026, escrevendo um teste que precisava de um UUID
"conhecido" para comparar ordem — por exemplo `uuid.UUID("00000000-0000-0000-0000-000000000000")`
(o nulo canônico) ou qualquer sentinela parecido, todo em dígitos decimais.

**O sintoma:** `AttributeError: 'UUID' object has no attribute 'int'`, ou
`uuid.UUID(hex=0)` explodindo dentro do processador de resultado do SQLAlchemy — no meio de um
`session.execute()` que não tem nada de especial, numa tabela que já guarda UUID em outras
dezenas de linhas sem problema.

**A causa:** o SQLite tem **afinidade de tipo por coluna** (`NUMERIC`, `TEXT`, etc.), não tipo
fixo. Um `TypeDecorator` de UUID tipicamente grava o valor como o hex de 32 caracteres, sem
hífens. Se esse hex é composto **só de dígitos decimais** (`"00000000000000000000000000000000"`,
ou qualquer combinação usando apenas `0`-`9`), o SQLite o reconhece como "texto que parece um
literal numérico bem formado" e, sob afinidade `NUMERIC`, **converte e armazena como inteiro** —
silenciosamente, sem erro no `INSERT`. Na leitura de volta, o processador de resultado do
`TypeDecorator` espera uma string e recebe um `int` (`0`, no caso do UUID nulo), e a reconstrução
do objeto `UUID` quebra.

**Por que só alguns UUIDs disparam isso:** a chave é ter APENAS caracteres `0`-`9` no hex — um
UUID com qualquer letra `a`-`f` no meio (a maioria dos UUIDs aleatórios, na prática) não "parece"
um literal numérico e permanece `TEXT`. É por isso que o defeito só aparece com sentinelas
CONSTRUÍDOS À MÃO (nulo, ou variações tipo `...0001`, `...0002`) — nunca com `uuid.uuid4()`, cuja
saída quase sempre contém alguma letra hex.

**Correção:** ao construir um UUID sentinela para teste, use hex com letras, nunca só dígitos:

```python
# ARRISCADO — 32 dígitos decimais, SQLite pode converter pra int na volta
uuid.UUID("00000000-0000-0000-0000-000000000000")

# SEGURO — hex com letras, fica TEXT garantido
uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
uuid.UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")
```

**Regra prática:** se um teste precisa de um UUID "legível"/determinístico (não
`uuid.uuid4()` aleatório) para comparar ordem, identidade ou string, prefira hex só com letras
(`a`-`f`) ou misto — nunca só dígitos decimais. Vale para qualquer projeto Percus que rode a
suíte padrão em SQLite com um `TypeDecorator` de UUID (ou qualquer tipo cuja representação em
texto possa "parecer" numérica).

### Complemento (Empresa Milionária, 17/09/2026): `UUID(int=n)` é o mesmo defeito, com outra mensagem

**Reprodução:** teste de **ordem** de trava (V2.3 Task 4) precisava de ids crescentes e intercalados entre dois
pedidos, e usou `uuid.UUID(int=1)`, `uuid.UUID(int=2)`... O hex de `UUID(int=n)` com `n` pequeno é **só dígitos**
(`00000000000000000000000000000001`). O `INSERT` passou calado, e a leitura quebrou no processador de UUID do
SQLAlchemy 2 com **`AttributeError: 'int' object has no attribute 'replace'`** (`sqltypes.py`, `_python_UUID(value)`),
mensagem diferente das duas citadas acima. Quem procura pela mensagem não acha este verbete, e por isso ele fica aqui.

**Receita que preserva a ORDEM** (o caso em que o sentinela precisa ser comparável, não só identidade): prefixo fixo
com letra e sufixo numérico de largura fixa.

```python
def _uuid(n: int) -> uuid.UUID:
    return uuid.UUID(f"aaaaaaaa-0000-4000-8000-{n:012d}")   # TEXT garantido; ordena por n
```

A ordem continua a mesma no SQLite (texto hex de largura fixa) e no Postgres (`uuid` compara byte a byte).
