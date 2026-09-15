## `deepseek-review` sai com exit 0 e "Cannot index into a null array" — API sobrecarregada devolveu 2xx sem `choices` e nenhuma review foi gravada {#deepseek-review-2xx-sem-choices-nao-grava-review}

`tags: deepseek, R11, review, pre-commit, hook, choices, null array, sobrecarga, falha silenciosa, cross-claude, R23`

**Status: RESOLVIDO em 2026-09-14** pela feature `r11-sem-ponto-unico` (spec
`docs/superpowers/specs/2026-09-14-r11-sem-ponto-unico-design.md`): o cliente passou a ter timeout e
1 retry, mostra no stderr os primeiros 2 000 caracteres do corpo (chave mascarada), grava
`.deepseek/reviews/ultimo-erro.txt` e sai **exit 4** sem marcador; a review Cross-Claude é gravada
com `registrar-review`. O texto abaixo descreve o comportamento ANTERIOR, mantido como histórico.

**Sintoma:** `scripts/deepseek-review.ps1` fica 10–15 min pendurado e termina com
`[deepseek-review] ERRO: Cannot index into a null array.`, **exit 0**, e nenhum
`.deepseek/reviews/*.jsonl` novo. O commit seguinte é barrado pelo `pre-commit-check` ("último
review tem N min"). Repete em tentativas seguidas.

**Causa:** o wrapper lê `$response.choices[0].message.content`. `Invoke-RestMethod` lança exceção em
4xx/5xx, então chegar nessa linha com `choices` nulo significa que a API respondeu **sucesso com corpo
vazio** — padrão de sobrecarga (medido com 4 reviews simultâneas de sessões diferentes na mesma
chave). **Não é** o bug de unicode (aquele volta 400 "invalid unicode"). O `catch` imprime só a
exceção de índice e esconde o corpo real.

**O que fazer:**
- Não confie no exit 0: confira se apareceu `.deepseek/reviews/d-<hash>.jsonl` / `latest.jsonl` novo.
- Não insista mais de 2 vezes; confira se outras sessões estão rodando `deepseek-review` ao mesmo tempo.
- Com autorização do operador, faça a review com um subagente Cross-Claude e registre com
  `registrar-review` (a linha pronta vem no marcador `__PERCUS_NEEDS_CROSS_CLAUDE__`); não calcule
  hash à mão.
- O marcador precisa existir ANTES da chamada do commit: o hook roda em PreToolUse.
- ~~Melhoria do kit pendente: logar o corpo da resposta quando `choices` vier nulo.~~ Feita (ver Status).
