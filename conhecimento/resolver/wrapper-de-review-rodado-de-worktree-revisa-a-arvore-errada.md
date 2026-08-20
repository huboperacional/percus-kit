## O wrapper de review rodado de dentro de um worktree revisa a ÁRVORE ERRADA {#wrapper-de-review-rodado-de-worktree-revisa-a-arvore-errada}

`tags: R11, review, worktree, powershell, cwd, set-location, hook, gate que aprova sem olhar, falso verde, percus-review-auto`

**Sintoma:** o hook de pré-commit insiste que a review está **stale** logo depois de você rodar o
wrapper. Você roda de novo, ele passa "limpo", e o hook continua reclamando. Ou pior: ele **para** de
reclamar — e a review "limpa" nunca olhou o seu código.

**Causa raiz:** a ferramenta PowerShell do harness abre no **checkout principal do projeto**, não no
worktree onde o trabalho está. E `Set-Location` **não persiste** entre chamadas separadas — cada
invocação cria um processo `pwsh` filho novo. Então o wrapper roda com `cwd` no repositório
principal: ele revisa o diff **de lá** (normalmente vazio ou de outra frente) e grava o resultado no
`.deepseek/reviews/` **de lá**. O hook, que lê o diretório do worktree, não acha review nenhuma.

**O que torna isto grave:** o modo de falha silencioso não é o hook reclamando — é o hook
**aceitando**. Um gate cross-provider que aprova tendo lido outra árvore é verde que não viu o
código, e ele parece idêntico a um verde legítimo.

**Conserto:** junte `Set-Location` e a chamada do wrapper na **mesma invocação**:

```powershell
Set-Location "<caminho-do-worktree>"; pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:PERCUS_CANON_DIR\scripts\percus-review-auto.ps1"
```

**Como confirmar que a review viu o que devia:** o wrapper informa **quantos arquivos** entraram no
escopo. Compare com o seu `git diff --cached --stat`. Se ele diz 0, 1 ou "13" quando você tem 16
staged, ele não está olhando a sua árvore — ou você esqueceu de `git add` nos arquivos novos (o
wrapper só vê o que o git rastreia).

**Achado em:** tiatendo, frente cidade-inteira (2026-08-20), durante execução em worktree isolado.
Duas rodadas inteiras do wrapper revisaram o repositório principal antes de alguém desconfiar do
"stale" persistente.

Ver [commit-com-review](../fazer/commit-com-review.md) e [subagent-driven-worktree-nativo](../fazer/subagent-driven-worktree-nativo.md).
