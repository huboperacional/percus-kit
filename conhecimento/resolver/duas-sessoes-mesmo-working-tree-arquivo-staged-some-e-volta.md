## Duas sessões Claude no MESMO working tree: arquivo staged pode sumir do disco por um instante e voltar sozinho {#duas-sessoes-mesmo-working-tree-arquivo-staged-some-e-volta}

`tags: multi-sessao, working tree compartilhado, git index, race condition, staged file, colisao transiente, R20, sessao concorrente`

**Sintoma:** duas sessões Claude Code (não worktrees separados — o MESMO diretório de trabalho,
apontando pro mesmo `.git`) trabalhando em paralelo. Uma sessão tem um arquivo `git add`-ado
(staged, novo, ainda não commitado). No meio de uma sequência de `Read`/`Edit` nesse arquivo, uma
chamada devolve **"File does not exist"** — e uma checagem via `ls`/`wc -l` confirma: o arquivo
sumiu do disco por completo, staged ou não. Segundos depois, sem nenhuma ação de recuperação, o
arquivo **reaparece sozinho**, staged, com o conteúdo correto.

**O que estava acontecendo ao mesmo tempo:** a outra sessão, no mesmo working tree, estava rodando
uma sequência de `git commit`s dela (visível depois via `git log --oneline`: 5 commits novos que
não eram desta sessão, intercalados no tempo). Working tree e índice do git são recursos
**compartilhados pelo SO**, não por sessão — duas sessões commitando/editando ao mesmo tempo no
mesmo diretório competem pelo mesmo `.git/index` e pelos mesmos arquivos em disco. Uma janela de
inconsistência transitória (leitura no meio de uma operação de escrita da outra sessão) é possível,
mesmo sem nenhum comando destrutivo de nenhum dos dois lados.

**O que NÃO era a causa:** nenhuma das duas sessões rodou `git reset`, `git clean`, `git checkout
--` ou qualquer comando destrutivo — confirmado por `git log` (só commits normais, sem reflog de
reset) e pelo fato do arquivo ter voltado sozinho com o conteúdo certo (destruição real não se
autocorrige). Foi puramente uma leitura no timing errado.

**Mitigação, não solução:** não há como uma sessão "travar" o working tree contra a outra neste
setup (sem worktrees `git worktree add` separados). Quando um arquivo staged parece ter sumido:
1. Re-verifique com `ls`/`git status --short` antes de concluir perda — pode ser transitório.
2. Se o conteúdo depende de edits complexos já aplicados nesta sessão, o HISTÓRICO DA CONVERSA (as
   chamadas de `Write`/`Edit` já feitas) é uma fonte de recuperação mais confiável que arqueologia
   de `git fsck`/`git cat-file` sob pressão de tempo — reescrever do que já se sabe correto é mais
   rápido que caçar blob solto no object store.
3. Depois que o arquivo confirmar presente de novo, commit o quanto antes — reduzir a janela de
   arquivo staged-mas-não-commitado é a única defesa real contra este tipo de colisão.
4. Ver também `[[isolation-worktree-branches-from-primary-head]]` (verbete existente) — se a colisão
   virar recorrente, a resposta estrutural é usar `git worktree add` de verdade pra cada sessão, não
   compartilhar o diretório.

**Ref:** Plexco Tasks, s162 (2026-08-31) — `backend/scripts/import_ekyte_ads4pros.py` staged, sessão
secundária commitando fixes de tema no mesmo working tree; arquivo sumiu do disco entre um `Read` e
o próximo, voltou ~1 minuto depois com o conteúdo intacto (438 linhas, edits anteriores presentes).
