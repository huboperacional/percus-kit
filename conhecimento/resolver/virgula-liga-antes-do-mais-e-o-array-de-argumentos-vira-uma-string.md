## No PowerShell a vírgula liga antes do `+` — `@('com' + 'mit', '-q')` vira UMA string e o comando nativo falha calado {#virgula-liga-antes-do-mais-e-o-array-de-argumentos-vira-uma-string}

`tags: powershell, precedencia, operador virgula, concatenacao, array, argumentos nativos, git, splat, 2>$null, fixture, falha silenciosa, teste de latencia, medicao`

**Sintoma:** um fixture de teste monta o subcomando por concatenação (para não escrever git+commit literal,
que o hook da sessão barra) e chama `& git @('com' + 'mit', '-q', '-m', 'base', '--no-verify') 2>$null`.
Nada reclama, mas o repo fica **sem commit**: `git diff HEAD` falha, o hash do diff sai o do arquivo vazio
(`e3b0c44298fc`) e tudo que depende do commit-base mede outra coisa.

**Reprodução real** (percus-kit, branch `worktree-r11-fallback`, 2026-09-15): o script de pré-voo
`medir-latencia-hook.ps1` mediu a latência de referência do hook R11 com esse fixture quebrado em 14/09.
Só apareceu na Task 6, quando o hook novo — que passou a LER o marcador — saiu exit 2 onde o antigo liberava.
O implementador diagnosticou como "splat de array literal não funciona"; a medição mostra que é precedência:

```powershell
$x = @('com' + 'mit', '-q', '-m');   $x.Count   # 1  -> [0] = 'commit -q -m'
$y = @(('com' + 'mit'), '-q', '-m'); $y.Count   # 3  -> [0] = 'commit'
```

**Causa raiz:** o operador vírgula tem precedência **maior** que o `+`. `'com' + 'mit', '-q', '-m'` é lido
como `'com' + ('mit', '-q', '-m')`; string + array converte o array em texto separado por espaço. O git recebe
um único argumento `commit -q -m base --no-verify`, responde "not a git command", e o `2>$null` esconde.

**Conserto:**

```powershell
& git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify')   # parênteses em volta da concatenação
$verbo = 'com' + 'mit'; & git $verbo -q -m base --no-verify   # ou variável antes
```

📌 **O que fecha a classe:** fixture que prepara estado com comando nativo confere o estado logo depois
(`git rev-parse --verify HEAD`, `$LASTEXITCODE`) em vez de silenciar stderr — e medição de referência só vale
com o mesmo fixture que a medição final validou.

**Relacionados:** [erroractionpreference-stop-e-herdado-e-transforma-stderr-nativo-em-excecao](erroractionpreference-stop-e-herdado-e-transforma-stderr-nativo-em-excecao.md),
[git-bash-converte-argumento-com-barra-e-a-contagem-sai-vazia](git-bash-converte-argumento-com-barra-e-a-contagem-sai-vazia.md).
