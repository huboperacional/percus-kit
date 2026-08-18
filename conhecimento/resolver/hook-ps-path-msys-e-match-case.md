## Hook em PowerShell bloqueia commit legítimo vindo do git-bash (path `/d/...` e `-c` ≠ `-C`) {#hook-ps-path-msys-e-match-case}

`tags: hook, pre-commit, powershell, git-bash, msys, /d/, cygdrive, path windows, -match case-insensitive, -cmatch, falso positivo, PERCUS_HOOKS_DISABLED, exit 128`

**Sintoma:** o hook barra o commit dizendo que não há review — mas o review existe e está fresco. A
mensagem de diagnóstico mostra um caminho estranho, tipo `\d\Claud Automations\repo\.deepseek\reviews`,
ou um "git root" que nem é diretório (`commit.gpgsign=false`).

**Causa raiz (duas, independentes):**
1. O agente roda `cd "/d/Claud Automations/repo" && git commit`; o hook extrai o dir e entrega esse
   path **MSYS** para o `git` do **Windows** → `exit 128`, o hook cai no fallback e vai procurar o
   review num caminho inexistente.
2. `-match` do PowerShell é **case-insensitive**: em `git -c commit.gpgsign=false commit`, o `-c` de
   configuração casa no padrão de `-C <dir>` e o "repo target" vira `commit.gpgsign=false`.

**Solução:** normalizar `/d/...` e `/cygdrive/d/...` para `D:\...` antes de qualquer chamada a
binário Windows, e usar `-cmatch` onde a distinção maiúscula/minúscula **é** semântica (`-C` vs
`-c`). Vale a regra geral: **flag que muda de significado com o case exige `-cmatch`**.

Por que isso importa mesmo falhando "pro lado seguro": gate que bloqueia o caminho legítimo ensina a
desligar o gate (`PERCUS_HOOKS_DISABLED`) — e aí ele deixa de existir de verdade. Falso positivo
recorrente custa a proteção inteira.

**Ref:** `CANON_VERSION.md` v6.31.1; testes em
`plugin/percus-review/tests/pre-commit-path-resolution.tests.ps1`.
