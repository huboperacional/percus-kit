## Crase na mensagem de commit por `-m` some do commit (shell executa como comando) {#crase-em-commit-m-some}

tags: command not found no meio do commit, mensagem de commit truncada, backtick shell
substitution, markdown na mensagem de commit, palavra sumiu da mensagem

**Sintoma:** a mensagem aparece no histórico com uma frase **faltando uma palavra**, e no output
do git aparece um `command not found` solto que passa por ruído. O commit é criado normalmente,
com exit 0 — nada indica erro.

**Causa raiz:** a mensagem foi passada por `-m` num shell POSIX e continha **crase** — o idioma
natural de quem escreve markdown (`` `tabela` ``). O shell trata crase como *command substitution*:
executa o conteúdo e **substitui pelo stdout**, que é vazio. A palavra some da mensagem, e o
`command not found` vai para o stderr do shell, não do git.

O mesmo vale para `$` (expansão de variável) e, em shell interativo, `!` (history expansion).

**Solução:** mensagem longa vai por **`-F <arquivo>`**. Escreva o texto num arquivo temporário e
aponte o `-F` para ele — imune a crase, cifrão e aspas.

⚠️ **Exceção onde `-F` NÃO serve:** gate que lê a **linha de comando** (no Percus, o `mock-scan`
procurando o prefixo `MOCK-OK:`). Nesses casos o `-m` é obrigatório — então tire as crases do
texto, não troque o mecanismo.

**Como confirmar depois:** `git log -1 --format=%B` e leia. Se a frase perdeu o sujeito, foi isto.
Conserto com `--amend -F <arquivo>`, seguro enquanto não houve push.

**Irmã desta, mesma causa:** o hook `pre-commit-check` do Percus é *PreToolUse* e casa a string do
comando na linha inteira — um script que apenas **cite** o comando de commit dentro de um heredoc
é bloqueado como se fosse commitar. Escreva o script em arquivo e execute o arquivo.

**Ref:** Empresa Milionária, Fase B Task 6, 2026-08-14.
