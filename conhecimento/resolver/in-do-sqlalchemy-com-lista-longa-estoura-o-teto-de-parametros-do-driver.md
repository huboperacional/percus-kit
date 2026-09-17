## `IN` do SQLAlchemy com lista longa estoura o teto de parâmetros do driver — e teto de BYTES no upload não limita a CONTAGEM {#in-do-sqlalchemy-com-lista-longa-estoura-o-teto-de-parametros-do-driver}

`tags: sqlalchemy, in_, IN, bind parameters, asyncpg, 32767, sqlite, too many SQL variables, dedup, importacao, OFX, upload, teto de arquivo, fatia, chunk`

**Medido (Empresa Milionária, 2026-09-14, importação de extrato OFX).** O dedup buscava os identificadores já gravados
num `select(...).where(coluna.in_(identificadores))` único, com o comentário *"5 MB de OFX são ~20 mil transações, abaixo
do teto de 32.767 parâmetros do asyncpg"*. O revisor cross-provider (R11) apontou; a medição confirmou:

| O quê | Resultado |
|---|---|
| `asyncpg/protocol/prepared_stmt.pyx:130` (asyncpg da venv do projeto) | `if len(args) > 32767:` → `the number of query arguments cannot exceed 32767` |
| SQLite 3.49.1 (Python 3.12), `IN` com 40.000 `?` | `sqlite3.OperationalError: too many SQL variables` |
| O mesmo `in_()` do SQLAlchemy, 40 mil identificadores, na suíte SQLite | vermelho com `too many SQL variables` — o `in_()` gera **um parâmetro por item** |

**A premissa errada é ligar os dois tetos.** O limite do upload é de BYTES; o do driver, de CONTAGEM de parâmetros. Nada
liga um ao outro: a estimativa "~20 mil em 5 MB" vale para o arquivo típico do banco, e uma transação OFX mínima
(`<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260901<TRNAMT>-1.00<FITID>F000001<MEMO>X</STMTTRN>`) tem ~85 bytes — **calculado,
não medido com arquivo real**: ~60 mil transações cabem em 5 MB. Estourar o teto vira erro 500 no lugar da resposta
esperada.

**Como aplicar:**

```python
FATIA_DO_IN = 10_000   # folga larga sob 32.767 (asyncpg) / 32.766 (SQLite), somando os demais parâmetros da consulta

ids = sorted(conjuntoDeIdentificadores)
achados: set[str] = set()
for inicio in range(0, len(ids), FATIA_DO_IN):
    achados.update((await session.execute(
        select(Modelo.identificador).where(Modelo.contaId == contaId,
                                           Modelo.identificador.in_(ids[inicio:inicio + FATIA_DO_IN]))
    )).scalars())
```

- A fatia divide o espaço com os OUTROS parâmetros da mesma consulta (tenant, conta): não use o teto cheio.
- **O teste que discrimina tem duas condições:** mais itens que o teto (senão não há fatia) **e** acertos em fatias
  DIFERENTES. Com acerto só na primeira, um laço que consulta uma fatia só passa verde. Medido: sabotar para "só a
  primeira fatia" deu `assert (1, 39999) == (2, 39998)`; sabotar a fatia para 40 mil voltou ao `too many SQL variables`.
- **A suíte SQLite reproduz a falha do asyncpg** (mesma classe, teto quase igual): o vermelho não precisa de Postgres.
- Em Postgres puro, `coluna = ANY(:array)` manda a lista num parâmetro só — **não medido aqui**, e não serve a uma
  suíte que roda em SQLite.

Onde apareceu: `empresa-api/app/casos_uso/importar_extrato.py` (`classificarContraOBanco`) e o teste
`test_dedup_com_mais_identificadores_que_o_teto_de_parametros_nao_estoura` em `tests/pj/test_importar_extrato_envio.py`.

Primos: [ofxparse2-converte-dtposted-para-utc-e-a-data-do-movimento-muda-de-dia](ofxparse2-converte-dtposted-para-utc-e-a-data-do-movimento-muda-de-dia.md)
(o mesmo leitor de extrato, na mesma noite).
