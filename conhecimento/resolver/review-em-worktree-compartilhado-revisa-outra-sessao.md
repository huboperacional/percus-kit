## Review de commit em worktree compartilhado revisa o trabalho da OUTRA sessão {#review-em-worktree-compartilhado-revisa-outra-sessao}

`tags: R11, deepseek-review, worktree compartilhado, git diff, cached, unstaged, sessoes paralelas, review poluido, escopo de review, percus-review`

**Contexto:** três sessões compartilham o mesmo worktree. Encenei **um** arquivo (`docs/STATUS.md`),
rodei `deepseek-review.ps1` para o gate do R11 e recebi dois findings sobre
`services/tracking/app/modules/dashboard/page_flow.py` — arquivo que eu não abri, de uma frente que
não é minha, com sugestões de testes para uma função que outra sessão estava escrevendo naquele
minuto.

**Causa raiz:** sem `-Base`, o script monta o diff como a soma de **dois** comandos
(`deepseek-review.ps1`, linhas 79-84):

```powershell
$cached   = (Invoke-GitSafe diff --cached) -join "`n"
$unstaged = (Invoke-GitSafe diff) -join "`n"
$diff     = "$cached`n$unstaged".Trim()
```

A metade `--cached` é minha. A metade **não-encenada é de quem mais estiver editando o worktree**.
Num repositório de uma sessão só, as duas descrevem a mesma intenção; com três sessões, a segunda é
ruído de terceiros — e ruído que **parece finding legítimo**, porque vem formatado igual.

**Por que é pior do que parece ruído:** o gate do R11 fica verde, o commit passa, e o registro diz
"revisado". Se você tratar os findings, mexe em código de outra sessão em pleno voo; se ignorar sem
dizer, o próximo leitor não sabe distinguir "achado não tratado" de "achado que não era meu". E na
direção oposta: **o SEU código pode ser revisado por uma sessão que não sabe nada dele**, gerando o
mesmo estrago simétrico.

**Como resolver:**

1. **Rode o review de dentro do SEU worktree**, não do compartilhado. É por construção limpo: só o
   seu trabalho está lá, `--cached` e não-encenado descrevem a mesma coisa. Foi o que fez os reviews
   de código da mesma sessão saírem limpos enquanto o de documentação saiu poluído — a diferença era
   só o diretório de onde rodei.
2. Quando o commit **precisa** sair do worktree compartilhado (arquivo que as três sessões editam,
   como um `STATUS.md`), o review vem poluído por construção. Nesse caso: encene tudo o que é seu,
   **declare no commit** que o review saiu poluído e quais findings eram de outra frente, e não trate
   o que não é seu.
3. Correção de raiz, no kit: um `-Staged` que monte o diff só de `git diff --cached`. Escopo de
   review deveria seguir a **intenção de commit** (o índice), não o estado do disco.

**Como confirmar em 5 segundos** antes de acreditar num finding: `git status --short` e veja se o
arquivo citado aparece com `M` na **segunda** coluna (não-encenado). Se aparece, e você não o
editou, o finding é de outra sessão.

Mesma família, e vale ler junto: [[gate-le-working-tree-nao-o-indice]] — o gate do commit tem o
mesmo defeito de escopo, lendo o disco em vez da intenção. E
[[indice-git-compartilhado-leva-trabalho-alheio]], que é a versão do problema no `git add`: nesta
mesma sessão, um `git add conhecimento/` varreu 5 verbetes não rastreados de outras sessões, e só
não virou commit porque o gate de tamanho barrou.
