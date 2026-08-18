## Hook PowerShell roda sob `powershell.exe` 5.1, não `pwsh` — arquivo produzido sem BOM (ou teste com acento literal no source) corrompe/quebra silenciosamente {#hook-powershell-51-sem-bom-corrompe}

`tags: powershell 5.1 vs 7, BOM UTF-8, encoding ANSI codepage, Get-Content sem encoding, hook cmd wrapper, ps51-compat, caractere acentuado literal em ps1, mojibake`

**Contexto:** ao construir dois scripts (`autorizar-acao-externa.ps1`,
`registrar-uso-autorizacao.ps1`) que produzem/consomem um arquivo JSON lido por um hook
PreToolUse (`external-action-guard.ps1`), um campo de texto livre com acento (`motivo`) voltava
corrompido (`"correção"` virava `"correÃ§Ã£o"`) quando o hook processava o arquivo.

**Causa raiz (duas camadas do mesmo problema):**
1. O `.cmd` wrapper do hook (`external-action-guard.cmd`) invoca `powershell.exe`
   (Windows PowerShell 5.1), não `pwsh` (PowerShell 7) — mesmo em máquina com PS7 instalado. O
   `.ps1` do hook lia o arquivo via `Get-Content $authFile -Raw | ConvertFrom-Json`, **sem**
   `-Encoding` explícito. O script produtor gravava com
   `[IO.File]::WriteAllText(..., New-Object System.Text.UTF8Encoding($false))` (UTF-8 **sem**
   BOM) — a convenção "ASCII puro" já estabelecida no kit pra outros scripts. Sem BOM, o 5.1
   decide o encoding por heurística e cai no codepage ANSI do Windows pra texto acentuado — os
   dois bytes UTF-8 de um caractere acentuado viram dois caracteres ANSI errados (mojibake), não
   um erro visível.
2. Ao escrever um teste de regressão pra esse bug, o próprio texto acentuado de teste
   (`"correção-urgente-acentuada"`) foi digitado como caractere literal no **código-fonte** do
   arquivo `.tests.ps1`. Isso reintroduziu o MESMO problema numa camada diferente: o teste-guarda
   já existente no kit (`ps51-compat.tests.ps1`, "nenhum .ps1 do kit tem caractere não-ASCII sem
   BOM") pegou o arquivo de teste como violação — porque ele também não tinha BOM.

**Solução:**
- Quando um script PRODUZ um arquivo que um hook (ou qualquer coisa rodando sob `powershell.exe`
  5.1) vai LER: grave com BOM (`New-Object System.Text.UTF8Encoding($true)`), quebrando a
  convenção "sem BOM" só nesse ponto específico, com comentário explicando por quê. **E** o lado
  que lê deveria usar `-Encoding UTF8` explícito de qualquer forma (defesa em profundidade) — mas
  como o hook já estava em produção e mudar hook de segurança é escopo maior, o BOM no lado
  produtor resolveu sem tocar no hook.
- Quando for escrever TEXTO acentuado dentro do código-fonte de um `.ps1` (não em dado de
  runtime, no próprio arquivo), nunca usar o caractere literal — construir via `[char]0x00E7`
  (ç), `[char]0x00E3` (ã), etc., concatenados. Mantém o arquivo-fonte ASCII puro (parseia igual
  em 5.1 e 7, sem risco de BOM) enquanto ainda testa o comportamento de runtime com acento de
  verdade.
- Pra confirmar qual PowerShell um `.cmd` wrapper realmente invoca, ler o `.cmd` direto — não
  assumir que "a máquina tem PS7 instalado" significa que o hook roda nele.

**Trade-off:** nenhum real — BOM no arquivo de dado JSON produzido por um script não quebra nada
que já lê esse arquivo (JSON com BOM é tolerado por `ConvertFrom-Json` em ambas as versões); só
quebraria se algo fizesse comparação byte-a-byte estrita do conteúdo, o que não é o caso aqui.

**Ref:** percus-kit, plano `docs/superpowers/plans/2026-08-06-r20-autorizacao-lote.md`, Tasks 4-5
(sessão 2026-08-07, achado em code review + confirmado empiricamente contra `powershell.exe` 5.1
real).
