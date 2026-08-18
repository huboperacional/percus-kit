## Um fix commit que não re-roda a suíte de regressão enterra um RED sob "[5-T] local verde" {#fix-commit-sem-re-rodar-suite}

`tags: regressao, suite stale, 5-T, handoff verde, fix commit tardio, assert substring, html renderizado, style, emoji, glifo, checar marcacao`

**Sintoma:** handoff dizia "103 testes verdes / [5-T] local", mas ao retomar, `test_lojaCardE1` estava
RED. O fix commit anterior (badge no compacto) adicionou um comentário CSS com uma **estrela literal**,
e um teste PRÉ-EXISTENTE fazia checagem crua `"estrela" not in html` sobre o HTML inteiro (inclui o
`<style>` sempre renderizado). O commit de fix não re-rodou a suíte daquele arquivo → o RED passou
despercebido sob o "[5-T]" anterior.

**Solução:**
- Depois do ÚLTIMO commit de uma branch (inclusive fix commits tardios), **re-rode a suíte de
  regressão do alvo** — não confie no "[5-T]" tirado ANTES do último commit.
- Antes de deployar branch "pronta de sessão anterior", rode a suíte relevante uma vez — o "verde"
  do handoff pode estar stale.
- Asserção de presença/ausência em HTML renderizado: **cheque a marcação** (`class="x"`), NUNCA a
  substring crua do glifo/emoji — `<style>` sempre contém nomes de classe e comentários podem conter
  o glifo (foi um comentário CSS com emoji que quebrou o teste sem o produto mudar).

**Ref:** tiatendo E3-E6 loja (2026-07-17). Fix `390cece`. Memória `project-vitrine-e3-e6-loja-2026-07-17`.
