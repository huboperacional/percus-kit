## `grep -iF` aborta com SIGABRT no Git Bash: a combinação quebra, cada flag sozinha funciona {#grep-if-aborta-git-bash}

`tags: grep, git bash, msys, windows, SIGABRT, rc=134, Aborted, -i, -F, fixed string, case insensitive, gate, pipeline, integer expression expected`

**Sintoma:** um script shell que funcionava passa a falhar com mensagem que não fala de `grep`. O sintoma típico é uma variável de contagem vindo **vazia** e o teste seguinte explodindo:

```
line 234: [: : integer expression expected
```

Rodando o comando na mão aparece o que realmente aconteceu:

```
140841 Aborted    grep -ciF "{#slug}" arquivo.md
rc=134
```

`134` é `128 + 6` (SIGABRT): o `grep` **não retornou 1 por não achar** — ele **abortou**.

**Causa raiz:** neste build de `grep` do Git Bash / MSYS, a combinação **`-i` com `-F`** aborta. Cada uma sozinha funciona: `grep -cF padrao` devolve a contagem normalmente, `grep -ci padrao` idem. É a interação das duas que quebra.

Como a contagem vinha de `$( ... )`, o abort virou **string vazia** em vez de erro visível, e o defeito só apareceu duas camadas adiante, num `[ "$x" -gt 0 ]`. Comando substituído que aborta não faz barulho: quem lê o script vê uma comparação numérica quebrada e procura o bug no lugar errado.

**Solução:** não peça case-insensitive ao `grep` quando também precisar de string fixa. Baixe a caixa dos dois lados:

```sh
alvo_lc=$(printf '%s' "$alvo" | tr '[:upper:]' '[:lower:]')
n=$(cat arquivo.md | tr '[:upper:]' '[:lower:]' | grep -cF "$alvo_lc")
```

Portável, sem depender do build de `grep`, e o resultado é o mesmo.

⚠️ **Não troque `-F` por regex para poder usar `-i`:** se o padrão tem `{`, `}`, `.`, `[`, `*` — âncora markdown `{#slug}` tem — você passa a depender de escapar tudo, e o primeiro slug com caractere especial vira falso negativo silencioso.

**Pegadinha vizinha, mesma família:** `grep -q` em pipeline sai no primeiro casamento e manda **SIGPIPE** para quem está a montante; o bash então imprime `Done ... | Aborted ...` no meio da saída do script. Em gate, isso polui o diagnóstico e faz parecer que o gate quebrou. Prefira `grep -c` e compare o número.

**Como reconhecer na hora:** `rc=134` ou a palavra `Aborted` na saída, ou variável de `$( )` inexplicavelmente vazia seguida de `integer expression expected`. Teste o comando isolado antes de suspeitar da lógica em volta.

**Ref:** percus-kit 6.36.6, 2026-08-16 — bloco 3c do `percus-gate.sh`, checagem de slug duplicado.
