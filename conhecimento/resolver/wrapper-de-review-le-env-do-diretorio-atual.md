## O wrapper de review lê o `.env` do diretório ATUAL, e `$env:` vence o arquivo {#wrapper-de-review-le-env-do-diretorio-atual}

`tags: R11, percus-review, deepseek, DEEPSEEK_API_KEY, .env, worktree, variavel de ambiente, credencial expirada, hook pre-commit, bloqueio de commit`

**Contexto:** o `deepseek-review.ps1` começou a devolver `Authentication Fails, Your api key:
****d818 is invalid`. Como o hook `pre-commit` exige review fresco (< 5 min), **nenhum commit
passava** — a sessão inteira travou por uma credencial, não por código.

**Causa raiz:** a chave daquele projeto tinha sido revogada. Outra chave, já presente em outro
projeto da mesma máquina (`auth-service/.env`) e na variável de **usuário** do Windows, respondia
200 normalmente.

**Duas pegadinhas que fazem a troca "não pegar":**

1. **O script carrega `.env` do `Get-Location`** — o diretório de onde você o chamou. Rodar do
   **worktree** (que normalmente não tem `.env`, porque ele é gitignored e não é copiado) faz o
   script cair na variável de ambiente. Trocar a chave no `.env` do repo principal **não afeta** a
   execução feita de dentro do worktree.
2. **`$env:DEEPSEEK_API_KEY` tem PRECEDÊNCIA sobre o arquivo** (`if (-not $env:...) { carrega .env }`).
   Um shell que subiu **antes** da troca continua com a chave velha em memória e a repassa para
   todo processo filho — inclusive o `pwsh` do wrapper. O `.env` novo fica correto e ignorado.

**Como resolver:**
```bash
# do worktree, ou de qualquer shell antigo: force a chave na chamada
export DEEPSEEK_API_KEY=$(grep -m1 "^DEEPSEEK_API_KEY=" "<repo-principal>/.env" | cut -d= -f2 | tr -d '\r"')
pwsh -NoProfile -File ".../deepseek-review.ps1"
```

**Como diagnosticar em 10 segundos:** a mensagem de erro traz os **4 últimos caracteres** da chave
usada. Compare com o sufixo do `.env` (`k=$(grep ...); echo "...${k: -4}"`). Se diferirem, o script
não está lendo o arquivo que você editou — é uma das duas pegadinhas acima, não uma chave errada.

**Antes de sair caçando chave nova:** teste a que você já tem em outro projeto com um request
mínimo (`curl` em `/chat/completions` com `max_tokens: 1`). Foi o que evitou abrir o painel do
provedor.

**Segunda ocorrência, 2026-08-26 — sincronizar não bastou.** Chave rotacionada de novo, e desta
vez o operador já tinha trocado o `.env` **e** o valor persistido a nível de USUÁRIO do Windows
(`[Environment]::SetEnvironmentVariable(...,'User')`) antes de qualquer chamada nova. Mesmo assim,
uma chamada NOVA do PowerShell tool ainda herdava a chave mais antiga das três. O processo pai que
segura o valor velho não é "o shell onde você editou o `.env`" — é mais acima na árvore (o
launcher do harness), e nem editar o arquivo nem sincronizar o registro do usuário alcança um
processo já vivo. **A única correção que funciona em toda chamada nova é ler o `.env` e fazer
`$env:X = $valor` DENTRO da mesma chamada que usa o valor** — nunca confiar no ambiente herdado,
mesmo depois de "consertado" nas outras duas fontes.
