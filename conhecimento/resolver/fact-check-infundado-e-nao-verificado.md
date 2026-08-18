## Fact-check da review marca finding REAL como "INFUNDADO" porque não conseguiu verificar {#fact-check-infundado-e-nao-verificado}

`tags: fact-check, F3, INFUNDADO, nao verificado, finding filtrado, review, cross-provider, deepseek, latest.jsonl, bloco Audit, falso negativo, escopo de mudanca, cp1252, PYTHONIOENCODING`

**Origem:** tiatendo, 2026-07-31 — 4 findings de review cross-provider filtrados numa sessão; **2
eram reais** e viraram código.

O pipeline de fact-check (F3) classifica findings e **remove do output principal** os que marca como
`INFUNDADO`. O motivo mais comum não é "a alegação é falsa" — é **"não foi possível verificar (sem
path verificável ou arquivo ausente)"**. São coisas diferentes, e o filtro trata igual.

- **A regra:** *"não consegui verificar"* ≠ *"infundado"*. **Sempre leia o bloco Audit** e os findings
  filtrados antes de commitar. O custo de ler 4 parágrafos é minúsculo perto do de perder o achado.
- **Onde ficam:** `.deepseek/reviews/latest.jsonl` (o campo `findings` traz o texto integral).
  ⚠️ No Windows, `print` estoura em `cp1252` — use `PYTHONIOENCODING=utf-8` +
  `sys.stdout.reconfigure(errors="replace")`.
- **Padrão dos que sobrevivem ao filtro:** findings sobre **escopo de mudança** ("você trocou a
  semântica de X, varreu todos os callers?") e sobre **ambiguidade de entrada** — justamente os que
  exigem olhar fora do diff, que é o que o verificador automático não consegue fazer.

**Relacionado:** [Review que aborta com binário](revisor-aborta-com-binario.md) — outro jeito de a review sair vazia parecendo
limpa.
