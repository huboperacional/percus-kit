## Teste "flaky" que é `ORDER BY` de timestamp empatado — o relógio não tem resolução para desempatar {#order-by-timestamp-empatado}

tags: teste flaky, intermitente, ordem indefinida, ORDER BY, criadoEm, created_at, timestamp igual, resolucao do relogio, Windows 15ms, desempate, tie-break, ultimo registro, mais recente, sqlite, passa isolado falha na suite

**Contexto:** um teste passa isolado, passa com o arquivo inteiro, e falha de vez em quando na
suíte completa. A asserção é sobre "o mais recente" — `assert achados[0].descricao == "X"` — e
vem o outro registro.

**Causa raiz:** a query ordena por um campo de **auditoria** (`criadoEm`/`created_at`), e os dois
registros do teste são criados na mesma transação. `datetime.now()` chamado duas vezes seguidas
devolve **o mesmo valor** — no Windows a resolução do relógio é de ~15 ms, e as duas inserções
caem no mesmo tick. Com o campo de ordenação empatado e **sem critério de desempate**, a ordem é
indefinida: o banco devolve na ordem que quiser, e o teste passa por sorte.

Confirme em dois segundos, antes de investigar qualquer outra coisa:

```python
from datetime import datetime, timezone
a, b = datetime.now(timezone.utc), datetime.now(timezone.utc)
print(a == b)          # True => o empate é real, e o "flaky" está explicado
```

**Solução:** acrescente um desempate estável e **monotônico** à ordenação.

```python
.order_by(Modelo.criadoEm.desc(), Modelo.id.desc())
```

⚠️ **O desempate por `id` só funciona se `id` for monotônico** (sequence/autoincrement).
**Com PK UUID4 ele NÃO conserta nada** (refutado em revisão, 2026-08-12): uuid4 é aleatório,
então a ordem fica determinística *dentro* do run mas **sorteada entre runs** — o teste continua
flaky, agora com cara de consertado. Com UUID4, o fix é outro:

- **No teste:** garanta timestamps distintos entre as criações (timestamp explícito na fixture ou
  tick de relógio forçado) — não exige tocar no código de produção.
- **No produto:** ordene por critério de negócio, ou adicione coluna monotônica (sequence) se
  "ordem de chegada" for semântica de verdade.

**Não é só teste.** O mesmo empate acontece em produção sempre que dois registros entram no mesmo
tick — importação em lote, criação em cascata, parcelamento que gera N irmãos. "O último" devolve
o errado, silenciosamente, e ninguém liga o defeito ao relógio.

**Irmão conceitual:** [#lista-data-auditoria-vs-negocio] — ali o erro é *qual* campo datar; aqui é
ordenar por um campo que empata. Nos dois casos, campo de auditoria fazendo trabalho de campo de
negócio.

**Ref:** Empresa Milionária, 2026-08-12, `whatsapp/service.py` (`_searchLancamentos`). Falha
aparecia 1 vez a cada N execuções da suíte de 2.7 mil testes.
