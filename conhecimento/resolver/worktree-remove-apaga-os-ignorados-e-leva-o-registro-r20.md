## `git worktree remove` apaga também os IGNORADOS — o log R20 e as evidências da worktree vão junto {#worktree-remove-apaga-os-ignorados-e-leva-o-registro-r20}

`tags: git worktree remove, worktree, ignorados, gitignore, .percus, autorizacoes-usadas.jsonl, R20, evidencia, playwright, .superpowers, limpeza, teardown, perda de dado`

**Sintoma.** Depois de uma feature feita em worktree, a limpeza parece segura: `git status --short`
da worktree vazio, branch mesclada, `git worktree remove` sem `--force`. A pasta some — e com ela
arquivos que nenhuma conferência mostrou: o `.percus/autorizacoes-usadas.jsonl` com os usos das
janelas R20 abertas de dentro da worktree, os screenshots do `.playwright-mcp/` que o ledger cita
como evidência, o workspace do SDD com os scripts de rollback.

**Causa.** Para o git, worktree limpa é **sem modificação em rastreado e sem untracked**. Arquivo
**ignorado** não conta como sujeira — por isso não impede a remoção —, mas mora dentro do diretório
que o `remove` apaga inteiro. E é justamente o que o canon manda deixar ignorado (`.percus/`,
`.superpowers/sdd/`, `.playwright-mcp/`) que carrega o registro de autorização e a evidência.

**Antes de remover, inventarie os ignorados e copie o que é registro:**

```sh
git -C <worktree> status --short --ignored | grep '^!!'    # o que o status normal esconde
```

Copie para a raiz principal o que precisa sobreviver — o workspace do SDD (ledger, scripts de
rollback), o `.percus/autorizacoes-usadas.jsonl` ou as janelas arquivadas em `docs/historico/`, a
evidência citada — e confira contagem e bytes **antes** do `remove`. `node_modules` e `.next` podem ir.

**Um detalhe do Windows que confunde a leitura:** o `remove` pode terminar com `Permission denied`
depois de já ter apagado todo o conteúdo e desregistrado a worktree — só o diretório vazio fica,
preso por outro processo (observador de arquivos do editor). O erro não quer dizer que nada foi
apagado.

**Medido:** LiliCalc, limpeza da worktree `tipos-de-ficha` (2026-09-14). O workspace do SDD foi
copiado antes (45 arquivos, mesmos bytes); o log de usos da janela R20 `62c89689` e os PNGs do
`.playwright-mcp` não foram inventariados e se perderam.

**Relacionado:** [Arquive toda janela R20 ao consumi-la](../fazer/arquivar-a-janela-r20-porque-o-registro-e-git-ignored.md),
[worktree remove falha com junction](worktree-remove-junction-windows.md).
