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

---

**Reincidiu em 2026-08-23, por CRLF, e num gate de SQL — 12 verdes seguidos.** A injeção era
`sed '/^BEGIN;$/a ALTER TABLE … DROP CONSTRAINT <nome>;'`, uma constraint por vez, contra um canário
rodado no Postgres real. As **13 passaram com a constraint derrubada**. O `sed` não injetou nada: o
arquivo saíra de `io.open(..., "w")` do Python no Windows, que traduz `
` → `
`, a linha era
`BEGIN;`, e o âncora `^BEGIN;$` nunca casou. 🔑 **Âncora de regex é a superfície onde CRLF
morde** — `$` casa fim de linha, e o `` está antes dele.

Verificação da injeção, no mesmo molde do `print` de confirmação acima:

```bash
sed "/^BEGIN;\$/a ALTER TABLE public.$T DROP CONSTRAINT $C;" canario.sql > variante.sql
test $(grep -c 'ALTER TABLE' variante.sql) -eq 1 || { echo "INJECAO FALHOU em $C"; continue; }
```

**E o resultado esperado tem de ser exato, não só "ficou vermelho".** Com o defeito posto, o gate
reprova **exatamente** os casos mapeados, e o placar fecha no mesmo total de sempre:

| o que se observa | o que significa |
|---|---|
| nenhum caso caiu | a injeção não aconteceu |
| caíram os casos mapeados, total fecha | ✅ o gate protege aquilo, e só aquilo |
| caíram casos **a mais** | o gate está **acoplado** — no caso real, com o `CHECK` derrubado o `INSERT` passa e **grava**, e dois casos dividindo o mesmo sujeito faziam o segundo colidir na chave primária, com exceção de outra classe, matando o bloco antes dos casos seguintes |

**Trave o transporte, não só a lógica:** `.gitattributes` com `*.sql text eol=lf` / `*.sh text eol=lf`
em toda pasta cujo conteúdo é lido por âncora de regex ou executado como shell.
