## `Agent` com `isolation:worktree` pode nascer dezenas de commits atrás da `main` — nunca confie no HEAD sem checar {#isolation-worktree-nasce-stale}

`tags: agent tool, isolation worktree, subagent-driven-development, git worktree, stale, cache, harness, claude code, worktree antigo, dezenas de commits atras, ff-only`

**Contexto:** duas ondas de subagents paralelos (`Agent` tool, `isolation: "worktree"`) contra o
repo tiatendo, sessão 2026-08-03 — 17 tasks no total.

**Sintoma:** **10 dos 17 worktrees nasceram dezenas a ~90 commits atrás da `main` real** — um
chegou a faltar 250 arquivos / +39079 linhas (migrations inteiras, features inteiras). Agentes
sem instrução explícita descobriram sozinhos (comparando `git log --oneline -3` com o que a
tarefa descrevia — números de linha não batiam, funções-modelo que a tarefa citava como "já
corrigidas" ainda não existiam naquela forma) e se autocorrigiram com `git merge main --ff-only`
antes de trabalhar — sempre fast-forward limpo, sem commits divergentes pra perder (nenhum
worktree tinha trabalho próprio ainda).

**Causa raiz:** o mecanismo de `isolation: worktree` do harness aparentemente pode reaproveitar
um worktree/branch em cache de sessão anterior em vez de sempre partir do HEAD atual da `main`.
Comportamento observado da ferramenta, não bug do projeto nem do git.

**Solução:** ao escrever prompts para `Agent` com `isolation: "worktree"` em qualquer repo com
histórico ativo, inclua como **PASSO 0 obrigatório, antes de qualquer leitura de código**:
`git log --oneline -3` seguido de `git merge main --ff-only` (fast-forward puro — seguro por
padrão, só aborta se houver commits locais divergentes, o que não deveria acontecer numa worktree
recém-criada sem trabalho prévio). Isso eliminou o problema por completo na 2ª onda de 11 agentes
desta sessão (todos já chegaram atualizados ou se autocorrigiram sem intervenção). Ao revisar o
retorno de um subagent que trabalhou em worktree isolado, sempre conferir `git log --oneline -3`
do worktree antes de montar/aplicar o patch dele.

**Ref:** sessão tiatendo 2026-08-03, backlog cirúrgico + auditoria da classe (17 fixes,
subagent-driven-development).
