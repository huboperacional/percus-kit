## Review volta vazia parecendo limpa: o revisor ABORTOU por causa de um binário no diff {#revisor-aborta-com-binario}

`tags: review, deepseek, abort, binario, mp3, asset, diff, review vazia, sem findings, falso verde, commit separado, codigo nao revisado`

**Origem:** tiatendo, 2026-07-31.

O revisor cross-provider (DeepSeek) tem regra de **recusar diffs que contenham binários**. Ao incluir
3 `.mp3` num commit, ele abortou a revisão inteira e devolveu **um único finding procedural** — o
código do mesmo commit **não foi revisado**, e o resultado tinha a aparência de uma review limpa.

- **A regra:** asset binário vai em **commit separado**. Código e binário no mesmo diff = código sem
  revisão, silenciosamente.
- **Sintoma:** review devolve só um finding falando do próprio binário/da própria regra, sem citar
  nenhuma linha de código. Isso é abort, não aprovação.
