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

🔑 **CONSERTO DE VERDADE, 2026-08-19 (6.44.0): `--rawfile` em vez de `--arg`.** O texto acima
prescreve **contorno** (dividir em lotes com `git stash`) porque, em 2026-07-18, o transporte era
tratado como fato da vida. Não é: `jq --rawfile nome ARQUIVO` lê do disco e **não cruza o argv**.
O `deepseek-review.sh` foi consertado assim; os **três wrappers de provider**
(`cross-claude.sh`, `deepseek.sh`, `groq-llama.sh`) ficaram com `--arg usr "$USER_PROMPT"` por mais
um mês.

**Como se manifestava lá, e por que ninguém ligou os pontos:** com prompt de ~8000 tokens o `jq`
morre com exit 126, **stdout sai vazio**, e o orquestrador não consegue parsear — a perna vira
`status: error` **sem mensagem nenhuma**. O sintoma não se parece com "argv estourou"; se parece
com "o provider não respondeu". E só acontecia em prompt grande, ou seja, exatamente quando a
terceira voz faz mais falta.

⚠️ **O comentário sobre esta classe já estava DENTRO dos arquivos** — aplicado ao corpo do `curl`
(`--data-binary @arquivo`), logo abaixo do bloco `jq` defeituoso. Consertaram um lado da mesma
fronteira e deixaram o outro. Guarda atual: `provider-limites.tests.ps1` exige `--rawfile` e proíbe
`--arg usr`/`--arg sys` nos três wrappers, com strip de comentário e anti-vacuidade.

🔴 **A varredura falhou na primeira tentativa, e o modo de falhar é a lição.** Corrigi os três
wrappers, escrevi aqui "grep em TODOS os `.sh`" — e deixei o `jq` FINAL do
`council-orchestrator.sh` com `--arg`, **no arquivo que eu estava editando**. Ali era pior: se
aquele `jq` morre, o `RESULT` inteiro sai vazio e o conselho some depois de as três pernas terem
respondido. Quem pegou foi a review R11, não o grep que eu tinha acabado de prescrever.
**Declarar a classe varrida não varre; rodar o grep varre.**

⏳ **Ainda aberto (2026-08-20):** o system prompt continua indo por argv até os wrappers
(`--system-prompt "$SYS"`). Com o F2 injetando código dentro dele, o argv estoura igual. Conserto
previsto: `--system-prompt-file`, análogo ao `--prompt-file` que já existe.

**Ao trocar transporte de texto grande, `grep` pelo padrão em TODOS os `.sh` que falam com API — não
só no arquivo que você está editando.** É a mesma lição de [#conserto-num-sitio-nao-varre-os-irmaos],
e esta foi a terceira reincidência dela neste kit.

**Ref:** Micro Investors F2 (2026-07-18), plugin percus-review 6.28.0. Conserto por `--rawfile` e varredura dos wrappers: 6.44.0 (2026-08-19).
