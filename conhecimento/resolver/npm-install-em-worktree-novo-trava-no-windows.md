## `npm install` em worktree novo trava no Windows, e apagar o parcial é pior que o problema {#npm-install-em-worktree-novo-trava-no-windows}

`tags: npm install, git worktree, windows, node_modules, junction, mklink, vitest, worktree isolado, rm -rf lento, EPERM, deps compartilhadas`

**Contexto:** criei um `git worktree` para isolar uma feature (3 sessões compartilham o worktree
principal) e rodei `npm install` no `web/`. Ele escreveu ~700 pacotes, **parou de progredir** e
ficou 20 minutos sem terminar — `node_modules/.bin/` **vazio**, ou seja, nenhum binário utilizável:
sem `vitest`, sem `tsc`, sem nada. O log só tinha um `npm warn deprecated`.

**Causa raiz (provável, não fechada):** contenção de I/O do Windows com um `node_modules` grande —
provavelmente agravada por antivírus e por outro processo Node ativo no worktree irmão. O ponto
prático não é o diagnóstico: é que **você fica sem poder rodar teste nenhum**, que era a razão de
existir do worktree.

**A armadilha da limpeza:** matar o `npm` e apagar o `node_modules` parcial **não é rápido**. O
primeiro `rm -rf` levou mais de 400 s e ainda falhou com *"Directory not empty"* em ~11 pastas
(arquivos ainda abertos pelo processo recém-morto). Foram necessárias **três** tentativas, em
background, para o diretório sumir de fato. Se você tentar isso de forma síncrona, perde a sessão
esperando — e um `node_modules` **parcial** é pior que nenhum, porque `npx` falha com erro confuso
(`Cannot find package '@vitest/utils'`) em vez de dizer "não instalado".

**Como resolver:**

1. **Junction para o `node_modules` do worktree principal**, que já está instalado e íntegro:
   ```powershell
   cmd /c mklink /J "D:\...\_wt-feature\web\node_modules" "D:\...\principal\web\node_modules"
   ```
   Leitura concorrente entre worktrees é segura — ninguém escreve em `node_modules` durante um
   `vitest run`. Só vale enquanto os dois worktrees tiverem o **mesmo `package.json`**: se a sua
   branch mexe em dependência, a junction mente e o erro vai parecer bug de código.
   ⚠️ Antes de `git worktree remove`, apague a junction com `rmdir` (não recursivo) — remoção
   recursiva sobre junction segue o link e ataca o diretório de destino.

2. **Contorno quando nem a junction dá** (o alvo estava travado, por exemplo): rode os testes **no
   worktree principal**, copiando os fontes para lá — e proteja-os de serem varridos pelo
   `git add -A` de outra sessão com uma entrada em `.git/info/exclude`, commitando no seu worktree
   com `git add -f`. ⚠️ `.git/info/exclude` é **do repositório, não do worktree**: ele esconde o
   caminho em todos, inclusive naquele onde você quer commitar — por isso o `-f`. Remova a entrada
   e as cópias ao terminar, ou vira armadilha para a próxima sessão.

**Sinal de que é isto, e não build lento:** `node_modules/` com centenas de pastas e
`node_modules/.bin/` com **zero** entradas. O `.bin` é populado no fim; vazio com o diretório cheio
significa install que não concluiu, não install em andamento saudável.
