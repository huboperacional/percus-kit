## `Series.apply()` do pandas coage `None` em `NaT` quando a maioria dos retornos é datetime — `isinstance(x, datetime)` mente {#pandas-apply-coage-none-em-nat-isinstance-datetime-mente}

`tags: pandas, apply, NaT, isinstance datetime, coerção de tipo, dtype inference, cobertura de parse falsa`

**Sintoma:** uma função de parse (`def parse(v): return datetime(...) if válido else None`)
aplicada via `serie.apply(parse)` deveria produzir uma mistura de objetos `datetime` e `None` pra
linhas sem dado. Uma contagem de cobertura feita depois com
`sum(1 for p in resultado if isinstance(p, datetime))` reporta **100% de cobertura** mesmo quando o
dado bruto tem centenas de valores vazios/`"-"`/`NaN` que a função claramente deveria ter retornado
`None` pra eles (confirmado testando a função isoladamente, fora do pandas, com o mesmo input —
retorna `None` corretamente).

**Causa:** quando a maioria dos valores que `apply()` retorna são objetos `datetime.datetime` reais,
o pandas re-infere o dtype da Series resultante como `datetime64[ns]` — e nessa conversão, todo
`None` (e `float('nan')`) que a função retornou vira `pandas.NaT` (Not-a-Time), silenciosamente, sem
aviso. `pandas.NaT` **é uma instância de `datetime.datetime`** (`isinstance(pd.NaT, datetime) ==
True`) — então qualquer checagem de "isso é uma data real" feita com `isinstance(x, datetime)`
depois do `.apply()` conta os `NaT` (que representam justamente a AUSÊNCIA de data) como se fossem
datas reais.

**Como resolver:**
1. Force a Series resultante a ficar em `dtype=object`, o que impede a re-inferência: chame
   `.astype(object)` na Series de ENTRADA antes do `.apply()` (`serie.astype(object).apply(fn)`),
   não depois — depois já é tarde, a coerção já aconteceu.
2. Defesa em profundidade na função de checagem: nunca confie só em `isinstance(x, datetime)`.
   Barre `NaT`/`NaN` explicitamente primeiro:
   ```python
   def eh_data_real(v):
       if v is None or (isinstance(v, float) and pd.isna(v)):
           return False
       try:
           if pd.isna(v):
               return False
       except (TypeError, ValueError):
           pass
       return isinstance(v, datetime)
   ```
   (o `try/except` existe porque `pd.isna()` em certos tipos de objeto pode levantar em vez de
   devolver `False`.)

**Como pegar isso ANTES de reportar um número pro operador:** compare a contagem de `NaN`/`"-"`
no dado bruto (`serie.isna().sum()`, `(serie == "-").sum()`) contra a contagem de "reais" pós-
parse. Se o pós-parse dá 100% e o bruto tem qualquer vazio, é esse bug — não é o dado estando
completo por acaso.

**Ref:** Paid Media Automation, sessão de reconciliação D4U (2026-08-28) — cálculo de janela de
conversão (`PRIMEIRO CONTATO` → `DATA` de fechamento) sobre uma planilha de 950 linhas reportou
"950/950 (100%) com data real" antes da correção; o valor real, depois de forçar `object` dtype
e reforçar `eh_data_real`, era 655/950 (68,9%) — 295 linhas genuinamente sem `PRIMEIRO CONTATO`
(a maioria marcada `PREEXISTENTE`, campo `"-"`) estavam sendo contadas como se tivessem data.
