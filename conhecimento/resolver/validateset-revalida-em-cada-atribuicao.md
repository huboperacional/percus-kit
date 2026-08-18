## `ValidateSet` de parâmetro revalida em CADA atribuição — a lista velha derruba o código novo {#validateset-revalida-em-cada-atribuicao}

`tags: powershell, ValidateSet, parametro, atribuicao, revalidacao, router por modo, cannot validate argument, lista de modelos, guarda de entrada, quebra em runtime`

**Sintoma:** você troca os valores que uma função produz internamente (ex.: um `switch` que escolhe
modelo por modo) e tudo parece certo — mas a função passa a estourar `The variable cannot be
validated because the value X is not a valid value` em **toda** invocação, não só quando alguém
passa o parâmetro.

**Causa raiz:** em PowerShell, um atributo de validação declarado num **parâmetro** fica colado na
**variável**, não só na entrada. Toda atribuição posterior àquela variável é revalidada:

```powershell
function T { param([ValidateSet("a","b")][string]$M = "a") ; $M = "novo" }   # <-- estoura AQUI
```

Isso inverte a intuição: você lê `[ValidateSet]` como "quem me chama tem que passar um destes", e
ele também significa "eu mesmo nunca posso atribuir outra coisa". Um router que resolve o default
internamente (`$M = switch (...) {...}`) é exatamente o caso que quebra.

**Solução:** ao mudar os valores que o corpo da função atribui, atualize o `ValidateSet` na mesma
edição — ou tire o atributo do parâmetro e valide explicitamente no corpo, se a lista de saída for
mais rica que a de entrada. Guarde com teste que extraia **os dois** do arquivo e exija que todo
valor produzido esteja permitido; sem anti-vacuidade esse teste nasce verde (ver
[#teste-nasce-verde-vazio-regex-primeiro-match](teste-nasce-verde-vazio-regex-primeiro-match.md)).

**Como detectar antes de doer:** verificação estrutural não pega — o arquivo parseia, o atributo
existe, os valores existem. Só runtime. Rode a função uma vez com cada caminho que atribui.

**Ref:** percus-kit 6.36.2, 2026-08-15. O router por modo do `council-orchestrator.ps1` passou a
atribuir `claude-sonnet-5`/`claude-opus-5` enquanto o `ValidateSet` listava só a geração 4 — o
conselho inteiro cairia em toda chamada. Achado pelo revisor cross-provider (R11), confirmado em
runtime com uma função de três linhas.
