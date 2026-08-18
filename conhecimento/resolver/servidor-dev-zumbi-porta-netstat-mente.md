## `[5-T]` manual mostra página vazia/velha: `netstat` mente sobre qual PID escuta a porta, servidor local zumbi de sessão anterior {#servidor-dev-zumbi-porta-netstat-mente}

`tags: uvicorn, reload, watchfiles, multiprocessing, zombie process, porta presa, netstat mente,
5-T manual, servidor dev, TestClient diverge do browser, PID errado, Windows taskkill`

**Contexto:** tiatendo, 2026-08-03. Ao fazer o `[5-T]` manual de `/roadmap` (`SKIP_DB_BOOT=1
REDESIGN_V2=1 python run.py`, porta 3110), o browser (via Playwright) e `curl` mostravam as 3
seções novas da página **completamente vazias** — só eyebrow/lede, zero fases/features/radar.
Um `TestClient` fresco no MESMO processo Python, importando o app diretamente, mostrava o
conteúdo **correto e completo**. Isso provou que o código estava certo e o servidor rodando
estava servindo outra coisa.

**Causa raiz:** uvicorn com `--reload` roda 2+ processos (reloader + worker, e o worker pode ter
filhos `multiprocessing.spawn`). Uma sessão anterior no mesmo dia tinha deixado processos presos
na porta 3110 sem morrer de verdade. `taskkill //F //PID <X>` no PID que `netstat -ano | grep
3110` reportava **não resolvia** — depois de matar, `netstat` continuava mostrando a MESMA porta
LISTENING, às vezes com o MESMO PID reportado (Windows reaproveita/cacheia essa informação de
forma não-confiável neste ambiente Git-Bash/Windows híbrido). O processo real que estava servindo
a request já tinha um PID diferente do que `netstat` mostrava.

**Solução:** não confie em `netstat -ano` sozinho pra achar o processo certo. Use
`Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Select ProcessId,CommandLine`
(PowerShell) pra ver a **command line completa** de cada processo — isso revela: (a) qual é
literalmente `python.exe run.py`, (b) quais são filhos `multiprocessing.spawn(parent_pid=X)` —
e X aponta pro PID pai que também precisa morrer, mesmo que ele já não apareça mais no
`tasklist`/`netstat` (processo pai pode ter saído mas deixado filho órfão vivo, ou vice-versa).
Mate a ÁRVORE inteira (todos os PIDs relacionados, não só o primeiro que `netstat` apontar),
espere 1-2s, e SÓ ENTÃO confirme porta livre e suba um servidor novo — validando com `curl`
direto (bypassa cache de browser) antes de abrir o Playwright.

**Sinal de alerta pra generalizar:** sempre que um `[5-T]` manual via browser/curl mostrar
resultado DIFERENTE de um teste automatizado que testa a mesma rota (`TestClient` em processo),
suspeite primeiro de servidor local desatualizado/zumbi antes de suspeitar do código — é mais
barato de descartar (kill + restart + `curl` de novo) do que investigar um "bug" que não existe.

**Ref:** tiatendo, sessão 2026-08-03/04, `[5-T]` de `/roadmap` por fases, PIDs 51468/54036/60736/
41148/32520/48836 numa sequência de kills até a árvore inteira morrer.
