## Conversa longa com muitos screenshots: imagem nova passa a ser rejeitada mesmo pequena — é acúmulo, não tamanho do arquivo {#conversa-longa-limite-imagem-cumulativo}

tags: image dimensions exceed max allowed size, many-image requests, 2000 pixels, screenshot rejeitado,
chrome devtools mcp screenshot, ocr windows fallback, winrt powershell falha, conversa longa limite

**Sintoma:** numa conversa já longa (dezenas de screenshots tirados via browser MCP ao longo da
sessão), o usuário tenta colar um print no chat e a API rejeita com "At least one of the image
dimensions exceed max allowed size for many-image requests: 2000 pixels" — mesmo pra imagens
pequenas (ex. 1091×282, bem abaixo de 2000px em qualquer lado). Redimensionar o arquivo NÃO resolve:
o mesmo arquivo, lido sozinho (`Read` isolado, sem nenhuma outra imagem na chamada), falha do mesmo
jeito, com um `request_id` novo a cada tentativa — não é reuso de um erro em cache.

**Causa raiz:** o limite não é por-arquivo, é o ORÇAMENTO TOTAL de pixels/imagens da requisição — que
inclui o HISTÓRICO da conversa inteira sendo reenviado ao modelo, não só a imagem nova. Uma conversa
que já acumulou muitas capturas de tela (comum em sessões de smoke test / co-design ao vivo via
Playwright/Chrome DevTools MCP) satura esse orçamento; a partir daí, QUALQUER imagem nova — não
importa o tamanho dela sozinha — estoura o total.

**O que NÃO funciona (testado e descartado nesta sessão):**
1. Redimensionar/cortar a imagem antes de enviar — o gargalo é cumulativo, não individual.
2. OCR local via `Windows.Media.Ocr` (WinRT) rodado em `pwsh` (PowerShell 7/Core) — falha com
   `Operation is not supported on this platform (0x80131539)` ao tentar refletir
   `IAsyncOperation<T>.AsTask` via `System.WindowsRuntimeSystemExtensions`: a projeção WinRT usada
   pelo type-accelerator `[Tipo, Assembly, ContentType=WindowsRuntime]` não é suportada no CLR do
   PowerShell 7/.NET moderno, só no Windows PowerShell 5.1 clássico.
3. Chamar `powershell.exe` (5.1 legado) heredoc'ado de DENTRO do Bash (Git-Bash/MSYS) — o script passa
   por 2 camadas de escaping (Bash → powershell.exe) e corrompe encoding/backtick, o mesmo erro de
   "matriz nula" aparece mesmo rodando no runtime correto.

**Solução que funciona:** peça o dado em TEXTO em vez de imagem (transcrição manual do que a pessoa
está vendo) — sem gargalo nenhum. Se a imagem for indispensável, ela precisa ser lida **cedo na
conversa**, antes do orçamento saturar com outras capturas — ou numa conversa nova/`/clear`.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158). 3 arquivos salvos em disco
(`C:\Users\...\Lixo\aaaa\*.png`, 1085-1480px de largura) falharam ao ler depois de ~20 screenshots já
tirados via chrome-devtools MCP na mesma conversa; tentativa de OCR local (WinRT via pwsh e via
Bash→powershell.exe) falhou nos dois runtimes por motivos diferentes.
