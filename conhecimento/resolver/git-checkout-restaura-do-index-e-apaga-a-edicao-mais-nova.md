## `git checkout -- <arquivo>` restaura do ÍNDICE, e apaga a edição mais nova sem avisar {#git-checkout-restaura-do-index-e-apaga-a-edicao-mais-nova}

`tags: git, mutation testing, restaurar mutacao, index vs HEAD, staged, perda silenciosa, checkout`

**Sintoma:** você aplica uma correção, ela some, e nada no terminal disse que sumiu. O teste que a cobria continua verde (porque o arquivo de teste sobreviveu), então a perda só aparece — se aparecer — num `grep` depois.

**Quando morde:** o ciclo padrão de **teste de mutação** manda restaurar com `git checkout -- <arquivo>`, *nunca* com `str.replace` cego. A recomendação está certa, mas tem um pressuposto não dito: **`checkout` restaura do ÍNDICE quando o arquivo está staged**, não do `HEAD` nem da sua última edição. A sequência que perde trabalho é banal:

1. `git add <arquivo>` (para rodar o review, que lê o diff staged);
2. você aplica **mais uma correção** no arquivo — agora o working tree está à frente do índice;
3. você muta o arquivo para provar uma trava;
4. `git checkout -- <arquivo>` → volta para o **passo 1**, e a correção do passo 2 evapora.

**Caso medido (2026-08-18):** correção real perdida exatamente assim; o commit seguinte foi feito com a versão antiga do código e uma **mensagem que descrevia a versão nova** — mensagem e conteúdo divergindo sem nenhum sinal.

🔑 **Por que é difícil de ver:** `checkout` não imprime nada, `git status` volta a "limpo" (que é o esperado depois de restaurar uma mutação), e o teste focado passa. Os três sinais que você normalmente usaria dizem "está tudo certo".

**Solução:**
- Depois de qualquer `git checkout -- <arquivo>`, **grepe o símbolo da sua última edição** no arquivo restaurado. É uma linha e fecha o buraco.
- Ou mute **antes** de dar `git add`, mantendo índice e working tree iguais durante o ciclo de mutação.
- Ou restaure com `git stash push --keep-index` + `git stash pop`, que preserva a edição não-staged.
- Antes de commitar depois de um ciclo de mutação, confira `git diff --cached` de verdade — não confie no `git status` limpo.

⚠️ Irmão do erro oposto, já catalogado: restaurar mutação com `str.replace` cego corrompe os sítios irmãos. Os dois têm a mesma raiz — **a restauração é um passo com estado, e ninguém a verifica**.
