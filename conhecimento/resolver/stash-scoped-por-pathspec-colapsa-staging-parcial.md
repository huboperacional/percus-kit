## `git stash push -- <pathspec>` + `pop` + `git add` colapsa staging PARCIAL (`MM`) em `M` sem perder conteúdo {#stash-scoped-por-pathspec-colapsa-staging-parcial}

`tags: git stash, pathspec, staging parcial, MM, git add, R11, review-router, duas sessoes mesmo working tree, colisao transiente, git diff cached`

**Contexto:** duas sessões no MESMO working tree (não worktrees separados — ver
[r11-mistura-diff-subagentes-paralelos.md](r11-mistura-diff-subagentes-paralelos.md), que documenta
a mesma classe pra subagentes em paralelo). A sessão A precisa rodar `review-router.ps1`/
`deepseek-review.ps1` só do PRÓPRIO diff, mas a sessão B tem arquivos dirty (alguns `MM` — staged
E com edição adicional não-staged em cima) que contaminam o cálculo (`git diff --cached` + `git
diff`, soma tudo). A técnica padrão é isolar a sessão B com `git stash push -u -- <paths da sessão
B>`, revisar/commitar o próprio diff, depois `git stash pop` + `git add <mesmos paths>` pra
devolver o estado dela.

**O que ninguém nota:** o `stash pop` restaura o CONTEÚDO exato do working tree de cada arquivo
(a combinação staged+não-staged de antes) — mas ele volta pro índice como estava DEPOIS do
`stash push` (ou seja, TOTALMENTE unstaged, porque o `push` removeu do índice junto). Rodar
`git add <path>` genérico depois do `pop` estagia o conteúdo INTEIRO daquele arquivo de uma vez —
se ele estava `MM` antes (parte já staged, parte só no working tree), ele volta como `M ` (tudo
staged). **Conteúdo idêntico, byte a byte** (confirmável com `git diff HEAD --stat -- <path>` antes
e depois) — só a DIVISÃO staged/não-staged daquele arquivo específico é perdida.

Isso não é um bug do `stash` em si — é o efeito esperado de `git add` sem seletividade aplicado
depois. Mas é fácil não perceber, porque `git status --short` só mostra a letra (`MM` → `M `), e
"conteúdo igual" engana quem só confere `git diff` combinado.

**Por que importa:** se a sessão B pretendia commitar SÓ a parte staged (deixando a edição extra
de fora, de propósito — um workflow real, não hipotético), o `add` genérico da sessão A colapsou
essa intenção sem avisar. A sessão B, ao voltar, vê tudo staged e pode commitar mais do que
pretendia.

**Mitigação, se precisar preservar o split exato:** antes do `stash push`, salvar o diff staged de
cada arquivo `MM` separadamente (`git diff --cached -- <path> > /tmp/staged-<n>.patch`); depois do
`pop`, em vez de `git add <path>` genérico, rodar `git reset -- <path>` (garante unstaged) seguido
de `git apply --cached /tmp/staged-<n>.patch` pra reconstituir só a fração que estava staged antes.

**Mitigação mais simples, se o split não for crítico:** avisar explicitamente a outra sessão/o
operador que o arquivo `X` tinha staging parcial e virou totalmente staged — deixa a decisão de
"o que entra no próximo commit" pra quem é dono daquele diff, em vez de silenciosamente presumir
que tanto faz.

**Ref:** Plexco Tasks, sessão secundária (tema/visual) coexistindo com a sessão primária
(backend/Onda 7) no mesmo `d:\Claud Automations\Plexco Tasks`, 2026-08-31. `backend/app/api/v1/
internal.py` (e depois `backend/scripts/import_ekyte_ads4pros.py`) foram os arquivos afetados —
nenhum dado perdido, só a divisão de staging, sinalizado ao operador no chat.
