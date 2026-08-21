## Mutação que não casa o padrão finge que o gate não reprova {#mutacao-que-nao-casa-finge-que-o-gate-nao-reprova}

`tags: teste, gate, mutacao, perl, sed, sed -i, perl -0pi, falso negativo, prova de gate, R11, TDD, verificacao, windows, /tmp, backup`

**Contexto:** a regra é que *gate que nunca foi visto REPROVANDO não é gate*. A técnica para provar
um teste é reintroduzir o defeito e confirmar que a suíte fica vermelha.

**O defeito está na ferramenta de mutação, não no teste.** `perl -0pi -e 's/X/Y/'` e `sed -i` **saem
com código 0 quando o padrão não casa** e deixam o arquivo intacto. Multi-linha, indentação e
caracteres que precisam de escape fazem o padrão errar com facilidade.

**Como isso engana:** o modo de falha produz **exatamente o mesmo sinal** que "o teste é fraco" —
suíte verde depois da mutação. As duas leituras possíveis são opostas:

- o teste não protege nada → *e a reação é afrouxá-lo ou reescrevê-lo*;
- a mutação nunca aconteceu → *e o teste estava certo o tempo todo*.

Nada na saída distingue as duas. A conclusão errada leva a **enfraquecer um teste correto**, que é
pior do que não ter feito a verificação.

**Ocorrido:** 2026-08-20, duas vezes na mesma sessão. Mutei o campo que distingue `null` de `0`,
rodei a suíte, **60 passaram**, e quase registrei "este gate não reprova". Refeito com verificação
explícita, a mutação aplicou e **3 testes reprovaram** — o gate sempre esteve correto.

**Correção — mutação sempre com ferramenta que falha alto:**

```python
s = io.open(p, encoding="utf-8").read()
assert alvo in s, "ALVO NAO ENCONTRADO — a mutacao nao foi aplicada"
io.open(p, "w", encoding="utf-8").write(s.replace(alvo, novo, 1))
print("mutacao aplicada de verdade")
```

Imprima a linha de confirmação **antes** de rodar a suíte. Se ela não aparecer, o resultado da suíte
não significa nada e não deve ser registrado como evidência.

⚠️ **Armadilha irmã, no backup:** `io.open("/tmp/x.bak","w")` no Python **do Windows** grava num
`/tmp` diferente do `/tmp` do git-bash. O `cp /tmp/x.bak <arquivo>` de restauração falha com
`cannot stat` — e **o arquivo fica mutado**, com o defeito dentro. Restaure pelo mesmo interpretador
que fez o backup, ou use caminho absoluto do scratchpad, e **confira o arquivo depois de restaurar**.

**Regra geral:** toda verificação por mutação precisa provar **duas** coisas, não uma: que o defeito
entrou, e que a suíte reagiu. Provar só a segunda é provar nada.
