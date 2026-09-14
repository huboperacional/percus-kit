## `deepseek-review` sai com exit 0 e "Cannot index into a null array" — API sobrecarregada devolveu 2xx sem `choices` e nenhuma review foi gravada {#deepseek-review-2xx-sem-choices-nao-grava-review}

`tags: deepseek, R11, review, pre-commit, hook, choices, null array, sobrecarga, falha silenciosa, cross-claude, R23`

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
- Com autorização do operador, faça a review com um subagente Cross-Claude de verdade (lendo o
  `git diff HEAD`) e grave o texto dela como marcador. O hash tem de sair do ARQUIVO de
  `git diff HEAD --output=<tmp>` (SHA-256, 12 hex) — igual ao hook — senão não casa.
- O marcador precisa existir ANTES da chamada do commit: o hook roda em PreToolUse.
- Melhoria do kit pendente: logar o corpo da resposta quando `choices` vier nulo.
