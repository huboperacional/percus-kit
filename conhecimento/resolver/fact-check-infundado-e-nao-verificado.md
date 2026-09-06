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

### 🔴 A causa mais comum não é acidente — é `git add -N`, receita deste mesmo canon

Este verbete trata "arquivo ausente" como azar. Em 2026-09-05 (Empresa Milionária) a causa foi
medida e é **estrutural**: para o review enxergar arquivo NOVO a receita é `git add -N`, e o `-N`
grava o **blob vazio** — o verificador abre 0 bytes e descarta **todos** os achados daquele
arquivo. As duas receitas de que você precisa se anulam.

**Magnitude no dia:** 3 achados descartados sobre um arquivo novo, **os três reais** (um deles um
`assert ... or True`, asserção incapaz de falhar, no único teste que justificava o arquivo). A
sessão vizinha, avisada, releu os reviews dela: numa task só havia **10** filtrados, ela tinha
lido **1**, e a releitura rendeu **6 correções reais**.

👉 **Mecanismo completo, tabela de discriminação e procedimento:**
[`INFUNDADO — arquivo ausente` é falha de MEDIÇÃO, não veredito](infundado-por-arquivo-ausente-e-falha-de-medicao-nao-veredito.md).

**Relacionado:** [Review que aborta com binário](revisor-aborta-com-binario.md) — outro jeito de a review sair vazia parecendo
limpa. E [Fact-check trunca path e descarta finding válido](fact-check-trunca-path-e-descarta-finding-valido.md), que é a mesma
família por outro mecanismo.
