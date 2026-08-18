## Hook `.ps1` quebra com erro de parser / acento vira caractere estranho {#ps51-ascii-hooks}

`tags: powershell, ps1, hook, parser error, encoding, cp1252, em-dash, emoji, acento, BOM, cmd`

**Contexto:** um hook `.ps1` do canon falha com erro de parse, ou strings com acento/emoji aparecem
corrompidas, **só quando rodado via `.cmd`** (não no pwsh direto).

**Causa raiz:** PowerShell 5.1 (invocado via `powershell.exe` dentro de um `.cmd`) lê `.ps1` **sem BOM**
como **cp1252**, não UTF-8. Em-dash (—), emoji ou qualquer não-ASCII num literal string quebra o parser.
O detalhe que faz o erro parecer insano: em cp1252, o **último byte** do em-dash (`E2 80 94`) é `94`,
que é a **aspa curva** `”` — e o PowerShell aceita aspa curva como delimitador de string. Dentro de uma
string, ela fecha a string cedo e o arquivo inteiro desanda. Os erros de parse apontam para linhas
**sem defeito nenhum**, às vezes dezenas de linhas depois. Em comentário é inofensivo (comentário vai
até o fim da linha) — o que explica por que alguns arquivos com acento nunca quebraram.

**Solução (mudou em 2026-07-30):** o `.ps1` pode ter não-ASCII, **desde que tenha BOM**. Grave como
UTF-8 **com** BOM e o 5.1 lê certo. Para adicionar BOM num arquivo existente, prepend de bytes —
nunca `Set-Content`/`Out-File`, que reescrevem o fim de linha e transformam um diff de 1 linha num
diff de arquivo inteiro:

```powershell
$b = [IO.File]::ReadAllBytes($f); [IO.File]::WriteAllBytes($f, (@(0xEF,0xBB,0xBF) + $b))
```

**A regra anterior era "100% ASCII" e é por isso que ela mudou:** regra sem gate é sugestão. Medido em
2026-07-30, **34** `.ps1` do kit violavam a regra ASCII — 16 deles nem parseavam no 5.1, e **3 eram
guardas de `PreToolUse`** (`external-action-guard`, `auth-import-pre-commit`, `types-check-pre-commit`)
que ficaram semanas **respondendo verde sem rodar**, porque o wrapper `.cmd` da época traduzia "script
morreu" em `exit 0`. A suíte não via nada disso: ela roda em pwsh 7, que lê UTF-8 por default.

Agora quem enforça é teste, não disciplina: `plugin/percus-review/tests/ps51-compat.tests.ps1` tem um
`It` que parseia **todo** `.ps1` do kit sob o `powershell.exe` real, e outro que barra **qualquer** byte
`> 0x7F` sem BOM — inclusive nos arquivos que hoje parseiam e só imprimem lixo, que o primeiro `It` não
enxerga.

**Ref:** spec `docs/superpowers/specs/2026-07-30-guardas-mortas-powershell-51-design.md`. A memória
`feedback_ps51_ascii_hooks` está **desatualizada** neste ponto. Relacionado:
[guarda-fonte-strip-string](guarda-fonte-strip-string.md) — a mesma família de "guarda que dá verde sem guardar".
