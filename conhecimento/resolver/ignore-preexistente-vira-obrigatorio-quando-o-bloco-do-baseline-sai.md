## `# type: ignore` pré-existente vira obrigatório quando o bloco do baseline sai — e chega sem motivo {#ignore-preexistente-vira-obrigatorio-quando-o-bloco-do-baseline-sai}

`tags: mypy, strict, type ignore, warn_unused_ignores, baseline, ignore_errors, debito de tipos, motivo na linha, comentario copiado, fato falso, R23`

**Sintoma:** ao pagar um módulo do baseline de `mypy --strict` (apagar o bloco `ignore_errors = True`),
o módulo fica verde sem que ninguém tenha escrito um `# type: ignore` novo — e o revisor encontra
ignores **antigos**, sem motivo na linha, que o diff nem mostra.

**Causa raiz:** enquanto o módulo estava sob `ignore_errors`, os `# type: ignore` que já existiam
eram decoração inerte. `--strict` liga `warn_unused_ignores`; com o bloco removido, o `exit 0` prova
que cada um deles agora é **necessário** — são a única coisa mantendo o módulo verde. A task "paga"
o módulo entregando dívida sem justificativa, e o grep do diff (`^+.*type: ignore`) diz "zero
ignores adicionados", o que é verdade e engana.

**Medido em Plexco Tasks (2026-09-05, fatia 8a2):** `weekly_review.py:45` e `integrations.py:53`
tinham `# type: ignore[arg-type]` sem motivo desde antes do baseline. Causa real dos dois: coluna
`status` como `Mapped[str]` enquanto o schema Pydantic usa `Literal[...]`. O implementador
justificou os dois copiando o mesmo texto — "coluna é str livre (CHECK no banco)" — e a
re-revisão leu as migrations: o CHECK existia em `weekly_review_snapshots` (mig 039) e **não existia**
em `org_integrations` (mig 020, `String(20)` puro). Um fato falso entrou num comentário permanente
por copiar o motivo entre linhas.

**Como aplicar:**

1. Ao pagar um módulo, procure ignores no **arquivo**, não só no diff: `grep -n "type: ignore" <arquivo>`.
2. Cada um ganha a causa real na mesma linha (`# type: ignore[codigo]  # motivo`) ou sai. Se a causa é
   um tipo errado a montante (coluna larga demais), o motivo cita isso e o estreitamento vira achado.
3. Nunca copie o motivo entre linhas sem verificar cada afirmação factual (constraint no banco,
   nulabilidade, quem chama).
4. `cast` que apaga a dívida é pior que ignore com motivo: o ignore fica greppável.
