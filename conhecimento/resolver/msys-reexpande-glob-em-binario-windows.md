## MSYS re-expande glob nos argumentos de binário Windows — mesmo entre aspas e com `set -f` {#msys-reexpande-glob-em-binario-windows}

`tags: git bash, msys, glob, asterisco, jq.exe, argumento, aspas nao protegem, set -f, noglob, binario nativo windows, null silencioso`

Passar `*` como **valor de argumento** para um binário Windows a partir do Git Bash não entrega `*`:

```bash
jq -n --arg t "*"  '$t'    # -> null      (o * virou a lista de arquivos do diretorio)
jq -n --arg t "a*" '$t'    # -> jq: error: AGENTS/0 is not defined   (expandiu pra AGENTS.md)
jq -n --arg t "TODOS" '$t' # -> "TODOS"   (ok)
```

As aspas **não** protegem, e `set -f` (noglob do bash) **também não** — quem expande é o CRT do lado Windows, depois que o bash já entregou os argumentos. Vale para qualquer `.exe` nativo chamado do Git Bash, não só o `jq`.

**Por que dói mais do que parece:** o `jq` devolveu `null` em vez de erro. Num hook que decide por `grep '"deny"'` na saída, `null` **libera** — fail-open por acidente de quoting, exatamente no caminho mais perigoso.

**Solução:** nunca use `*` como valor sentinela/coringa em argumento entregue a binário Windows — use uma palavra (`TODOS`, `ALL`). Se precisar do literal, **valide a saída do binário** em vez de confiar nela (checar que o JSON tem a chave esperada, não só que a string aparece).

**Vizinhos:** [#crlf-mata-regex-git-bash](crlf-mata-regex-git-bash.md) — mesma família: a camada de tradução Windows↔POSIX altera o dado em trânsito sem avisar.

**Ref:** Paid Media Automation, 2026-08-15 — escrevendo o `deploy-guard.sh`; o coringa `*` fazia o guard virar no-op silencioso em `docker stack deploy`, que é o comando que toca todos os serviços.
