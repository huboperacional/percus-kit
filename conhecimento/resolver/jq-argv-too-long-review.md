## `deepseek-review.sh` morre com "jq: Argument list too long" (diff > ~30KB no Windows) {#jq-argv-too-long-review}

`tags: deepseek-review, jq, argument list too long, argv 32kb, windows, git-bash, diff grande, package-lock, commit em lotes, git stash, PreToolUse, hook R11`

**Sintoma:** R11 falha em `line 123: jq: Argument list too long`. Não é bug do jq — é o **limite de argv
do Windows/git-bash (~32KB)**: o script passa `AGENTS.md` + o diff inteiro via `--arg`. Um `package-lock.json`
no diff (ou ~500 linhas de código novo) já estoura.

**Solução:** dividir o trabalho em **lotes menores, cada um com sua própria review** (respeita R11) —
`git stash push -- <paths do lote 2>`, revisa e fecha o lote 1, `git stash pop`, revisa e fecha o lote 2.
Lockfile vai isolado (`chore:`, sem lógica). **NÃO** bypasse o hook: o gate continua válido, só o
transporte é que não cabe.

**Gotcha do hook (PreToolUse):** ele bloqueia o **comando Bash inteiro** antes de executar. Se você
encadeou `git add X && git ...`, o `git add` **NUNCA roda** — então a correção que você acabou de fazer
no arquivo continua fora do stage e o hook reclama do mesmo problema em loop. **Rode o `git add` sozinho**,
confirme com `git show :<arquivo>`, e só então feche. (Idem: o hook casa por TEXTO — escrever a palavra
num heredoc de documentação já dispara o gate.)

**Ref:** Micro Investors F2 (2026-07-18), plugin percus-review 6.28.0.
