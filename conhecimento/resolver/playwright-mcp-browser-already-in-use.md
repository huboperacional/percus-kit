## Playwright MCP recusa qualquer ação com "Browser is already in use... use --isolated" {#playwright-mcp-browser-already-in-use}

tags: playwright mcp browser already in use, use isolated to run multiple instances, browser_navigate fails, browser_click fails, browser_tabs fails, stale chrome process holding profile lock, mcp-chrome profile locked

**Sintoma:** QUALQUER tool do Playwright MCP (`browser_navigate`, `browser_snapshot`,
`browser_tabs`, etc.) falha imediatamente com
`Error: Browser is already in use for <path>\ms-playwright-mcp\mcp-chrome-<hash>, use --isolated
to run multiple instances of the same browser` — mesmo sendo a primeira chamada da sessão atual,
sem nenhum outro uso aparente do MCP nesta conversa.

**Causa raiz:** uma sessão ANTERIOR (dias atrás, inclusive) deixou um processo Chrome real rodando
com o mesmo `--user-data-dir` do profile de automação do Playwright MCP, sem fechar limpo. O
profile fica com lock de arquivo enquanto QUALQUER processo Chrome (inclusive renderers filhos)
segue vivo apontando pra ele — não importa se a sessão que o abriu já terminou há muito tempo.

**Solução:** achar e matar o processo Chrome PAI (não renderer) que referencia esse
`user-data-dir`, depois retentar a call do MCP (funciona imediatamente, sem restart de nada).
No Windows: `Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object {
$_.CommandLine -like "*<hash-do-profile>*" -and $_.CommandLine -notlike "*--type=*" } | Select
ProcessId` acha o processo principal (renderers/gpu-process têm `--type=` na command line, o
processo raiz do browser não tem). `Stop-Process -Id <pid> -Force` mata a árvore inteira (Chrome
derruba os filhos quando o processo pai morre). É seguro matar sem confirmar — é sempre um
artefato órfão da própria automação, nunca o browser pessoal do operador (perfil dedicado só do
MCP, path contém `ms-playwright-mcp`).

**Ref:** Paid Media Automation, sessão 2026-08-09 — processo órfão de 08/08 (mais de 24h),
`browser_navigate` bloqueado até matar PID da árvore Chrome do profile `mcp-chrome-426029c`.
