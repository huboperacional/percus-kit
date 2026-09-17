## Commit por pathspec de pasta esquece o arquivo irmão, e a conferência pela ausência do alheio não vê {#pathspec-de-pasta-esquece-o-arquivo-irmao}

`tags: git, commit, pathspec, literal, pasta, diretório, arquivo irmão, openapi.json, git show --stat, conferência pós-commit, arquivo faltando, tipos regenerados`

**Quando:** commit por pathspec (`git commit -- ':(literal)projeto/src'`) numa task que tocou arquivos em mais de
uma pasta, seguido de uma conferência com `git show --stat HEAD`.

**Sintoma:** o commit sai com exit 0, a mensagem diz "tipos regenerados", e um arquivo da task **não entrou**. Em
14/09 (Empresa Milionária), o pathspec `empresa-frontend/src` levou o `api-types.generated.ts` (que mora em
`src/lib/`) e deixou para trás o `openapi.json`, que mora em `empresa-frontend/`, um nível acima. A conferência logo
depois olhou a lista de 54 arquivos procurando backend e spec — que não deviam estar — e não procurou o que devia.
Quem achou foi outra frente, horas depois: o `openapi.json` do HEAD nem citava as rotas novas.

**Causa:** pathspec de pasta cobre os filhos, nunca o irmão da pasta. E conferir só pela **ausência** do alheio prova
que o pathspec não foi largo demais, não que foi largo o bastante.

**Passos:**

1. Monte a lista esperada a partir da task (o `Files:` do plano ou `git diff HEAD --name-only`, menos o que fica para
   outro commit) e passe **arquivos**, não pastas, cada um com `:(literal)` quando o caminho tem `[`, `(` ou espaço.
2. Depois do commit, compare nos dois sentidos:
   ```bash
   sort lista-esperada.txt > esperado.txt
   git show --name-only --format= HEAD | sort > real.txt
   comm -23 esperado.txt real.txt   # esperado e FORA do commit — tem de sair vazio
   comm -13 esperado.txt real.txt   # no commit e NÃO esperado — tem de sair vazio
   ```
3. Se escapou, declare no commit seguinte em qual commit o arquivo devia ter ido.

**Armadilhas:**

- Lista gerada por Python no Windows sai com `\r\n`; tire o `\r` (`tr -d '\r'`) antes do `sort`, senão nada casa.
- Pathspec protege contra índice compartilhado, não contra arquivo compartilhado — ver
  [commit-com-pathspec-leva-o-disco-nao-o-staged](commit-com-pathspec-leva-o-disco-nao-o-staged.md).
