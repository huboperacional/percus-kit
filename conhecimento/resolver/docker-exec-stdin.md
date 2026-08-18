## `docker exec` sem `-i` engole o stdin — e vazio parece resposta {#docker-exec-stdin}

`tags: docker exec, stdin, heredoc, psql, resultado vazio, falso negativo, linha de controle, CRLF, git bash, VPS`

**Sintoma:** você roda uma checagem via heredoc (`docker exec pg psql -f /dev/stdin <<SQL`) e o
retorno vem **vazio**. Vazio parece "não há dependências", "não há linhas", "está limpo".

**Causa:** sem `-i`, o `docker exec` não conecta o stdin; o `psql` lê EOF e não executa nada. O
comando retorna 0.

**O que fazer:** `docker cp` do arquivo `.sql`/`.py` e execute por caminho — e **inclua sempre uma
linha de CONTROLE** no output (`SELECT 'CONTROLE: total='||count(*)`). Se ela não aparecer, o vazio
era do canal e não do banco. Corolário: script enviado de máquina Windows chega com **CRLF** e o
bash da VPS morre com `$'\r': command not found` — rode do worktree clonado pelo git, não do arquivo
enviado.
