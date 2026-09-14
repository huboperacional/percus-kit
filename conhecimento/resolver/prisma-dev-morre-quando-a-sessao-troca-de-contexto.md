## `prisma dev` em background morre quando a sessão do agente troca de contexto {#prisma-dev-morre-quando-a-sessao-troca-de-contexto}

`tags: prisma, prisma dev, pglite, windows, background, processo, worktree, EnterWorktree, Start-Process, cmd start, Win32_Process, P1001, ECONNREFUSED, vivo mas surdo, ConnectionClosed, migrate status trava, Lock file is already being held, globalThis, next dev 500`

**Contexto:** projeto Prisma 7 no Windows usando `npx prisma dev` como Postgres local. O servidor
precisa ficar de pé enquanto o agente trabalha, então é lançado "desanexado".

**Sintoma:** o banco funciona por minutos e depois some. O Next responde 500 com `ECONNREFUSED`, e
o CLI responde `P1001: Can't reach database server` — às vezes numa porta que o `Test-NetConnection`
acabou de dar como aberta. Nenhuma mensagem diz que o processo morreu.

**Causa:** tanto `Start-Process -WindowStyle Hidden` quanto `cmd.exe /c start "" /MIN cmd /c "npx prisma dev …"`
criam o processo **dentro da árvore de processos da sessão do agente**. Quando o harness recicla o
host do shell, o processo vai junto. Medido em 2026-09-13 (LiliCalc): dois `prisma dev` com nomes e
portas diferentes pararam **no mesmo segundo** (último write do WAL de cada um), exatamente quando
a sessão entrou numa worktree — e um deles era o banco de que outra sessão dependia.

**Correção:** crie o processo fora da árvore da sessão, pelo WMI:

```powershell
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine      = "cmd.exe /c npx prisma dev --name lilicalc -p 51213 -P 51214 --shadow-db-port 51215"
  CurrentDirectory = "D:\caminho\do\app"
}
```

Fixe as portas com `-p/-P/--shadow-db-port`: ao religar, o `.env` continua valendo. Os dados ficam
em `%LOCALAPPDATA%\prisma-dev-nodejs\Data\<nome>` e voltam intactos.

**Confira que aceita conexão, não que escuta:** `npx prisma migrate status` precisa responder com a
contagem de migrations. Porta em LISTEN logo após o start não prova banco utilizável.

**Se derrubou o banco de outra sessão:** religue com o mesmo nome e as mesmas portas — o estado
anterior volta do disco — e registre que fez isso.

**Sabor mais comum: "vivo mas surdo".** Sob carga (dev server, Playwright e scripts sobre o mesmo
banco), o processo e a porta ficam de pé, mas as queries falham com `ConnectionClosed` ou o
`prisma migrate status` fica pendurado — enquanto outro `prisma dev` sem carga segue saudável por
horas. Medido em 2026-09-13 (LiliCalc): 5+ vezes no banco da worktree, nenhuma no outro, mesmo
lançados pelo WMI. Recuperação: matar a árvore do processo dono da porta
(`taskkill /PID <raiz> /T /F`) e relançar pelo WMI; se vier `Lock file is already being held`
(`%LOCALAPPDATA%\prisma-dev-nodejs\Data\<nome>\server.json` com pid morto), tente de novo em alguns
segundos. **Depois relance o `next dev`:** o `PrismaClient` guardado em `globalThis` fica com o pool
morto, e as rotas dão 500 até o restart. Rode o `migrate status` com prazo (job + timeout), porque
ele trava em vez de falhar.
