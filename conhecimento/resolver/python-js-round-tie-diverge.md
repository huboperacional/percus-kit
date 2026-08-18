## Python `round()` (half-to-even) e JS `Math.round()` (half-up) divergem em empate exato — "fonte única" que só cobre a tabela, não a função {#python-js-round-tie-diverge}

`tags: banker's rounding, half to even, half up, Math.round, python round, arredondamento, empate exato, tie, dual language, fonte unica incompleta, calculadora`

**Contexto:** feature client-side (calculadora tiatendo) com fórmula "fonte única" — a tabela de
taxas vive em Python e é injetada como JSON pro JS ler, evitando 2 cópias divergentes da TABELA.
Mas a função de arredondamento (`roundToNearestTen`) foi escrita separadamente nas 2 linguagens,
com a MESMA lógica pretendida (`round(v/10)*10`). Um caso de QA manual real (20 pedidos/dia ×
R$20,50 × 15% × 30 = R$1.845,00 exato) revelou: Python devolvia R$1.840, o navegador mostrava
R$1.850 — a mesma fórmula, dois resultados.

**Causa raiz:** `round()` do Python usa banker's rounding (round-half-to-even): `round(184.5)` =
184 (par mais próximo). `Math.round()` do JS sempre arredonda empate pra CIMA: `Math.round(184.5)`
= 185. "Fonte única" cobriu a TABELA (dado), não a FUNÇÃO (lógica) — o mesmo número de entrada
produz saídas diferentes em cada linguagem sempre que o valor intermediário cai num múltiplo exato
de 5 (não só de 10) — bem mais comum do que parece com valores de ticket médio "redondos".

**Solução:** ao portar uma função (não só uma tabela) pra 2 linguagens, teste especificamente o
CASO DE EMPATE (`valor / divisor` terminando em `.5`), não só casos "arredondados por sorte" —
testes com números aleatórios raramente batem numa fração exata de coincidência. Se as 2
linguagens precisam concordar, escolha explicitamente UMA convenção e implemente a MESMA fórmula
nas duas (ex.: `floor(v/10 + 0.5)*10` é half-up em ambas, sem depender do `round()`/`Math.round()`
nativo de nenhuma — assume `v >= 0`; pra domínio com valor negativo, half-up-away-from-zero exige
tratar o sinal à parte).

**Ref:** revisão final holística (subagent), sessão tiatendo 2026-08-03, calculadora de demora
(S4) — `execution/dashboard/publicContent.py::roundToNearestTen` vs
`execution/dashboard/static/js/calculadoraPedidoPerdido.js`, fix no commit `a355e1a`.
