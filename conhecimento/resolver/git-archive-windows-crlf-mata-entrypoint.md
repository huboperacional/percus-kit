## Imagem buildada de `git archive` feito no WINDOWS morre sem log: `entrypoint.sh` em CRLF {#git-archive-windows-crlf-mata-entrypoint}

tags: docker, swarm, entrypoint, crlf, autocrlf, git archive, windows, exit 255, no such file or directory, rollback_completed, gitattributes

**Sintoma.** Task do Swarm falha com `task: non-zero exit (255)`, container fica em `Created` e
produz **zero linha de log**. `docker service update` termina com "converged" — mas
`UpdateStatus` diz `rollback_completed`. `docker run` na imagem revela:
`exec /usr/local/bin/entrypoint.sh: no such file or directory`, com o arquivo presente.

**Causa.** `git archive` rodado no Windows com `core.autocrlf=true` e sem `.gitattributes` grava o
shell script em CRLF. O shebang vira `#!/bin/sh\r` e o kernel procura o interpretador `/bin/sh\r`,
que não existe. A mensagem "no such file or directory" fala do INTERPRETADOR, não do script.

**Diagnóstico em 1 comando:**
```
docker run --rm --entrypoint /bin/sh <img> -c 'head -1 /usr/local/bin/entrypoint.sh | od -c | head -1'
# bom:      # ! / b i n / s h \n
# quebrado: # ! / b i n / s h \r \n
```

**Correção.** Não transferir contexto de build via tarball feito no Windows. Bundle → checkout no
Linux → build de lá:
```
git bundle create x.bundle <sha-da-vps>..<branch>     # use o NOME da branch; SHA solto = "empty bundle"
# upload em chunks de 256KB (write unico de >2MB quebra em silencio)
git -C /opt/<repo> fetch /tmp/x.bundle 'refs/heads/<branch>:refs/heads/tmp'
git -C /opt/<repo> worktree add --detach /tmp/wt-<sha> <sha>   # worktree: nao suja o clone
docker build -t <img> /tmp/wt-<sha>/<contexto>
```

**Dois ruídos que fazem perder tempo neste diagnóstico:**
1. `pulling image failed ... pull access denied` aparece para TODA imagem local sem registry,
   **inclusive nas que sobem normalmente**. É ruído, não a causa.
2. **Serviço irmão saudável não é evidência sobre a imagem.** Um worker cujo spec define
   `entrypoint: ["arq", ...]` **substitui** o entrypoint da imagem e nunca executa o `.sh` quebrado —
   ele roda liso enquanto a API recusa a mesma imagem. Compare o caminho de boot, não o resultado.

**Não "conserte" trocando `update_failure_action` de `rollback` para `pause`:** o rollback estava
certo, barrou uma imagem que de fato não sobe. Se trocar para diagnosticar, **devolva** no fim.
