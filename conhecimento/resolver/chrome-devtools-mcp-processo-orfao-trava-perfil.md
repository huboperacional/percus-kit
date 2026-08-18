## Chrome DevTools MCP recusa `new_page`/`navigate_page` com "browser already running" mesmo quando o próprio MCP perdeu o rastro do processo {#chrome-devtools-mcp-processo-orfao-trava-perfil}

tags: chrome-devtools mcp, browser already in use, userDataDir, processo orfao, sessao longa, playwright, mcp desconectado, chrome.exe travado

**Sintoma:** numa sessão de agente muito longa (muitas horas, dezenas de chamadas de browser MCP),
uma chamada a `new_page`/`navigate_page` do Chrome DevTools MCP falha com `Error: the browser is
already running for <userDataDir>, use --isolated to run multiple instances`. `list_pages` falha com
o mesmo erro. Não é concorrência com outra sessão/humano (ver
[Browser MCP sessão ao vivo do operador](browser-mcp-sessao-ao-vivo-operador.md) pra esse caso
diferente) — é a MESMA sessão de agente que já tinha usado o browser MCP com sucesso antes.

**Causa raiz:** o processo `chrome.exe` real (mais os processos filhos: gpu-process, renderer,
utility, crashpad-handler) sobreviveu no SO enquanto o servidor MCP, por algum motivo (idle timeout,
reciclagem interna, etc.), perdeu o handle/rastro dele. O lock do `userDataDir` (perfil do Chrome)
continua ativo no processo órfão, então quando o MCP tenta abrir um novo browser apontando pro mesmo
perfil, o Chrome real recusa (é o comportamento normal do Chrome pra 2 instâncias no mesmo perfil,
não um bug do MCP) — mas o MCP não tem mais o processo pra reconectar.

**Solução:**
1. Identifique o processo `chrome.exe` PAI (não os filhos) que referencia o `userDataDir` do MCP:
   `Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like
   "*<nome-do-perfil-mcp>*" }` (Windows) — o processo pai tem `--remote-debugging-pipe` na linha de
   comando; os filhos (`--type=gpu-process`, `--type=renderer`, etc.) são descartáveis e morrem em
   cascata quando o pai morre.
2. Mate o processo pai: `Stop-Process -Id <pid> -Force`. Não precisa matar os filhos manualmente.
3. Repita a chamada MCP (`new_page`/`navigate_page`) — o servidor detecta que precisa reconectar e
   sobe um browser novo. A resposta costuma incluir uma nota tipo "the browser was restarted or
   reconnected since the last call" confirmando a reconexão.
4. Isso é seguro de fazer mesmo achando que "pode ser sessão de outro processo" — SE o `userDataDir`
   na linha de comando bate com o perfil dedicado do MCP (não o perfil pessoal do Chrome do
   operador), matar esse processo específico não afeta nada fora da automação do agente.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158, sessão de várias horas com dezenas de
chamadas de Playwright/Chrome DevTools MCP pra smoke tests). `new_page` falhou com "browser already
running for C:\Users\...\chrome-devtools-mcp\chrome-profile"; `Get-CimInstance` achou o processo pai
(PID com `--remote-debugging-pipe`) mais ~12 processos filhos (gpu, renderer×5, utility×3, audio,
video-capture, crashpad-handler). `Stop-Process -Id <pai> -Force` seguido de `new_page` reconectou
com sucesso, sem precisar reiniciar a sessão inteira.
