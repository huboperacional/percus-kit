## Regex `(?m)...$` não casa em arquivo CRLF: o `\r` fica sobrando e a linha inteira é dada como inválida {#regex-multiline-crlf-dollar-nao-casa}

`tags: regex, .net, powershell, multiline, CRLF, \r\n, ancora $, fim de linha, markdown, parser, casou zero, windows`

**Sintoma:** um regex multilinha que parece obviamente certo casa **zero** ocorrências num arquivo do Windows. O mesmo padrão testado num literal digitado à mão funciona. Tipicamente aparece como "esperava 1 título, achei 0" num validador que lê `.md`.

**Causa raiz:** no .NET (e portanto no PowerShell), com `RegexOptions.Multiline`, o `$` casa **antes do `\n`** — não depois do `\r`. Num arquivo CRLF a linha termina em `\r\n`, então na posição em que o `$` casa **ainda falta consumir o `\r`**. Se o padrão exigir algo que não aceite `\r` imediatamente antes do `$`, ele não casa:

```powershell
# arquivo CRLF, linha: "## Titulo {#slug}\r\n"
'(?m)^##\s+(.+?)\s*\{#([^}]+)\}[^\S\r\n]*$'   # NAO casa: [^\S\r\n] exclui o \r
'(?m)^##[ \t]+(.+?)[ \t]*\{#([^}]+)\}[ \t]*\r?$'  # casa
```

A armadilha é que a classe "espaço horizontal" escrita como `[^\S\r\n]` — que é o jeito canônico de dizer "branco menos quebra de linha" — **exclui justamente o `\r`** que precisa ser consumido.

**Solução:** termine o padrão com `\r?$` sempre que for casar fim de linha em arquivo que pode ser CRLF. Alternativas: normalizar o texto para LF antes de casar (só se você **não** for reescrever o arquivo — normalizar e gravar de volta produz diff de arquivo inteiro), ou usar `\s*$`, que aceita `\r` mas também atravessa linhas em branco e costuma casar demais.

**Onde mais morde:** `$` em `-split`, `-match`, `Select-String -Pattern` e validadores de formato que leem `.md`/`.csv`/`.txt` versionados no Windows. Se o repo tem `core.autocrlf` ligado, o arquivo no disco é CRLF mesmo que no git seja LF — o script vê CRLF.

**Como reconhecer na hora:** "casou 0" num padrão que você consegue verificar visualmente na linha. Antes de reescrever o regex, teste com `\r?$` no fim — se passar a casar, era isto.

**Ref:** percus-kit 6.36.6, 2026-08-16 — validador do mesclador de conhecimento recusava toda entrada como "sem título".
