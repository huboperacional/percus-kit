## `ofxparse2` converte o `DTPOSTED` para UTC e descarta o fuso: a data do movimento muda de dia se você usar `.date()` {#ofxparse2-converte-dtposted-para-utc-e-a-data-do-movimento-muda-de-dia}

`tags: ofxparse2, ofxparse, OFX, DTPOSTED, fuso, timezone, UTC, America/Sao_Paulo, zoneinfo, tzdata, data do movimento, extrato bancario, importacao`

**Medido (Empresa Milionária, 2026-09-14, `ofxparse2 0.2.2`, extrato real anonimizado do C6 com 98 transações).**
O `DTPOSTED` do banco vem com o fuso no próprio campo (`20260605235900[-3:BRT]`). O `ofxparse2` devolve `t.date` como
`datetime` **com tz UTC** — `2026-06-06 02:59:00+00:00` — e o fuso original some. `t.date.date()` dá **06/06**, e o
banco lançou em **05/06**. Na fixture, **8 das 98 transações mudam de dia** assim: tudo que o banco registrou entre
21:00 e 23:59 de Brasília.

**Os três formatos, medidos:**

| `DTPOSTED` | O que o `ofxparse2` devolve |
|---|---|
| `20260605235900[-3:BRT]` (com fuso) | `datetime` UTC com tz — `2026-06-06 02:59+00:00` |
| `20260605122957` (hora, sem fuso) | `datetime` **tratado como UTC**, com tz — conforme o padrão OFX (sem fuso = GMT) |
| `20260605` (só a data) | `datetime` **ingênuo**, sem tz — `2026-06-05 00:00` |

**Como aplicar:**

```python
from zoneinfo import ZoneInfo

def dataLocal(dataHora: datetime, fuso: str) -> date:
    if dataHora.tzinfo is None:          # DTPOSTED só com data: o dia é o dele
        return dataHora.date()
    return dataHora.astimezone(ZoneInfo(fuso)).date()
```

- O fuso é o **da empresa** (o dono do caixa), não o do servidor. Converter o ingênuo também jogaria o dia para a
  véspera (00:00 UTC é 21:00 do dia anterior em Brasília) — por isso o ramo separado.
- "Hoje", para recusar data futura, também no fuso da empresa: 02:00 UTC do dia 15 ainda é dia 14 em São Paulo.
- No Windows, `ZoneInfo` exige o pacote `tzdata` instalado; sem ele o código passa no container Linux e quebra no dev.
- O teste que discrimina escolhe uma transação que **muda de dia** e afirma os dois lados: a data UTC (controle de que
  o caso existe) e a local (a regra). Uma transação ao meio-dia passa com ou sem a conversão.

Primos: [motivo-de-dominio-pela-ausencia-do-dado-nao-pela-frase-do-parser](motivo-de-dominio-pela-ausencia-do-dado-nao-pela-frase-do-parser.md)
(a outra armadilha do mesmo leitor, na mesma noite).
