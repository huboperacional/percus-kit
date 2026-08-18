## Junction de node_modules compartilhada entre worktrees corrompe e trava Turbopack {#junction-node-modules-worktree-risco}

tags: node_modules, junction, symlink, worktree, npm ci, turbopack, next dev, windows, corrupção

**Sintoma:** múltiplos `npm ci` concorrentes em worktrees diferentes no mesmo disco Windows
corrompem uns aos outros (`ENOTEMPTY`, pacote sem `package.json`). A solução óbvia — apontar
`node_modules` de cada worktree pra uma cópia já saudável via junction (`New-Item -ItemType
Junction`) — resolve a lentidão mas introduz dois problemas novos, não óbvios até acontecerem.

**Causa raiz:** (1) Turbopack (bundler default do Next 16) valida que `node_modules` fica DENTRO da
raiz do projeto e recusa symlink/junction apontando pra fora — não é um bug, é validação
proposital. (2) qualquer processo que ESCREVA em `node_modules` (ex.: `next dev` auto-instalando um
`@types/*` que falta) mexe no alvo real da junction, corrompendo a cópia compartilhada pra TODOS os
worktrees que apontam pra ela — inclusive a sessão principal.

**Solução:** trate a junction como estritamente READ-ONLY — `tsc`/`vitest`/`next build` leem sem
escrever, então funcionam. Nunca rode `npm install`/`next dev` (que pode auto-instalar) contra uma
junction compartilhada; se precisar de dev server, use `next dev --webpack` (Turbopack recusa a
junction com `Symlink [project]/node_modules is invalid, it points out of the filesystem root`). Se
um subagent detectar escrita acontecendo no meio da tarefa, o certo é matar o processo na hora e
trocar pra uma cópia isolada (`npm ci` de verdade), não insistir na junction.

**Ref:** Paid Media Automation, sessão cont.157 (2026-08-07) — 3 subagents paralelos usando a mesma
junction; um pegou o `next dev` tentando `npm install --save-dev @types/node` através dela e matou
o processo antes de corromper.
