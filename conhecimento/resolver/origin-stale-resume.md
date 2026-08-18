## Declarei versão errada ao retomar sessão (origin já estava à frente) {#origin-stale-resume}

`tags: git, origin, retomar, resume, versao, version, fetch, behind, stale local, declarar errado`

**Contexto:** ao retomar trabalho, declarei "estamos na vX.Y.Z" mas o `origin/main` já tinha uma versão
mais nova — trabalhei em cima de estado defasado.

**Causa raiz:** confiei no estado local sem comparar com o remoto.

**Solução:** **sempre `git fetch` + comparar com `origin/main`** antes de declarar versão/estado ou
retomar. Em projeto canon, ler `.percus-version` local **e** `origin/main:.percus-version`.

**Ref:** memória `feedback_check_origin_before_resume`.
