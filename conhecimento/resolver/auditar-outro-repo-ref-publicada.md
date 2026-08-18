## Auditar código de OUTRO repo: leia a ref publicada, nunca o working tree {#auditar-outro-repo-ref-publicada}

tags: auditoria cross-repo, working tree engana, evidencia circular, git show origin, ref publicada,
branch default nao e main, symbolic-ref, grep por stack, falso-negativo, retirada de suspeita

**Origem:** mesma sessão. Custou uma "retirada de suspeita" errada, que quase encerrou um defeito
real que estava deslogando usuário em produção.

O checkout local de outro projeto pode conter **trabalho em andamento de outra sessão**. Eu li o
working tree, vi o fix que o time estava escrevendo **em resposta ao meu próprio alerta**, e reportei
como prova de que o alerta era desnecessário — **evidência circular**.

- ✅ `git show origin/<ref>:<arquivo>` · ❌ abrir o arquivo do checkout.
- ⚠️ **A ref publicada nem sempre é `main`.** Num dos repos o `origin/main` era um snapshot antigo e
  a branch deployada era `origin/onda-minus-1/migracao-supabase`; noutro o default era `master`.
  Confirme com `git branch -r --contains <commit>` ou `git symbolic-ref refs/remotes/origin/HEAD`.
- Ao varrer um padrão em N repos, **greppe por stack**: `clearTokens|clearCookie` não acha Python
  (`delete_cookie`) — deu falso-negativo justamente no repo que tinha o bug.
