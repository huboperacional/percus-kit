## `git -C "$W" commit`: o hook lê o texto do comando, não expande `$W`, e barra por review "inexistente" {#git-c-com-variavel-o-hook-le-o-texto-e-procura-o-repo-errado}

`tags: hooks, PreToolUse, pre-commit-check, R11, git -C, variavel de shell, bash, worktree, falso bloqueio, Get-CommitTargetDir, latest.jsonl`

**Sintoma:** num worktree com review R11 recém-gravada, o commit pela ferramenta Bash é barrado com
`BLOCK: nenhum /percus-review:review em .deepseek/reviews/ do repo target` e a mensagem mostra
`git root: $W` e `searched: $W\.deepseek\reviews` — o nome da variável, não o caminho.

**Reprodução real** (percus-kit, worktree `trilhos-pmg`, 2026-09-15): `W="D:/.../worktrees/trilhos-pmg"`
seguido de `git -C "$W" commit -m ...` na mesma chamada. O mesmo commit passou na hora com
`git -C "D:/Claud Automations/percus-kit/.claude/worktrees/trilhos-pmg" commit ...`.

**Causa raiz:** o `pre-commit-check` roda no `PreToolUse`, **antes** do shell executar. Ele recebe o
comando como texto e extrai o repositório-alvo por regex (`Get-CommitTargetDir`: `git -C <dir>`,
`cd <dir> &&`). Nenhuma expansão de variável acontece nesse momento, então o alvo vira a string `$W`,
que não existe, e não há `.deepseek/reviews/` para achar.

**Conserto:** no comando que contém o commit, escreva o caminho **literal** em `-C` (ou `cd` literal
antes). Variável pode ser usada em qualquer outra chamada.

📌 **O que fecha a classe:** guarda de `PreToolUse` enxerga o comando **antes** do shell — variáveis,
subshells e aliases ainda não existem para ela. Tudo que a guarda precisa ler (repo-alvo, mensagem de
escape como `MOCK-OK:`, flag) tem de estar literal no texto do comando.

**Relacionados:** [hook-le-o-cwd-nao-a-raiz-do-git](hook-le-o-cwd-nao-a-raiz-do-git.md),
[virgula-liga-antes-do-mais-e-o-array-de-argumentos-vira-uma-string](virgula-liga-antes-do-mais-e-o-array-de-argumentos-vira-uma-string.md).
