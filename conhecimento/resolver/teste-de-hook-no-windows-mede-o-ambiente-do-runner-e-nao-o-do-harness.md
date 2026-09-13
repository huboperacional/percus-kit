## Teste de hook no Windows mede o ambiente do RUNNER, não o do harness: codepage herdada, `chcp` que come stdin, lançador do Git que devolve o PATH {#teste-de-hook-no-windows-mede-o-ambiente-do-runner-e-nao-o-do-harness}

`tags: teste, pester, Start-Process, NoNewWindow, WindowStyle Hidden, codepage, OEM, 850, 65001, chcp, stdin, set /p, BOM, cmd.exe, hook, git bash, bash.exe, lancador, launcher, HOME bin, PATH, jq, pre-condicao, Skipped, sem bash, pwsh, paridade sh, dispatcher, rodar-suite, OutputEncoding, stdout nativo, mojibake, cp850, verde no terminal vermelho na suite`

**Sintoma:** o teste de um hook `.cmd`/`.sh` dá um resultado rodado de um jeito e outro rodado de
outro, ou passa num cenário que nunca aconteceu. Não aparece erro nenhum. O teste está certo sobre o
ambiente **dele**, e esse ambiente não é o do hook.

**Contexto (2026-09-13, paridade `.sh` dos dispatchers, 6.53.0):** na mesma tarefa, o teste mediu
**cinco vezes** o processo que o rodava em vez do que o harness faz. Quatro vezes no teste novo, e a
quinta num teste da 6.51.0 que a suíte inteira pegou.

1. **Codepage herdada.** `Start-Process -NoNewWindow` herda o console do pwsh, que no terminal do
   agente está em **65001**. O `cmd.exe` dos hooks roda na **OEM (850)** (ver
   [[cmd-com-byte-nao-ascii-desalinha-o-cmd-exe-e-come-o-inicio-das-linhas]]), e há comportamento
   que muda com ela. Medido com o mesmo arquivo (`3600` + BOM): `set /p N=<arquivo` lê o valor
   **válido em 65001 e lixo em 850**. O `.cmd` testado honrava uma porta que em produção ignora, e o
   `.sh`, que imitava a produção, parecia o lado divergente. **Console novo**
   (`-WindowStyle Hidden`) nasce na OEM, e é esse o ambiente fiel. Um agravante: o `rodar-suite` sobe
   pwsh em janela oculta (OEM), então o mesmo arquivo de teste pode dar **verde pela suíte e vermelho
   rodado direto**, ou o contrário.
2. **`chcp` lê stdin.** A primeira ideia para forçar a codepage, `cmd /c "chcp 850 >nul & hook.cmd"`,
   calou o hook inteiro. Medido: `chcp 850 >nul & findstr "^"` sai **vazio**, e
   `chcp 850 >nul <nul & findstr "^"` repassa. Além disso, `chcp` num console compartilhado **deixa o
   console do processo pai** na codepage nova depois que o filho sai.
3. **O lançador do Git devolve o PATH.** Para testar "sem jq", o PATH do filho foi reduzido a
   `Git\usr\bin`, e o `jq` continuou visível. `Git\bin\bash.exe` é um **lançador** que re-adiciona
   `mingw64\bin`, `usr\bin` e `%HOME%\bin`, e o `jq` desta máquina mora em `%HOME%\bin`. O cenário
   "sem jq" rodou o caminho normal, e o teste mediu outra coisa. Conserto: `Git\usr\bin\bash.exe`
   direto, com `HOME` apontando para um diretório vazio, **e a pré-condição provada** no mesmo
   ambiente (`command -v jq || echo SEM-JQ`).
4. **pwsh fora do Git Bash não tem `bash` no PATH.** Teste que resolve o bash só por
   `Get-Command bash` vira `Skipped`. Hoje são **8 `It`**: 3 em `council-fallback-cross-claude.tests.ps1`
   e 5 em `spec-analyze-check.tests.ps1`. O `rodar-suite` só sai ≠ 0 com **falha**; o skip aparece
   apenas como um `passou/total` menor. É paridade `.sh` "provada" por teste que não rodou. O fallback
   `$env:ProgramFiles\Git\bin\bash.exe`, que `context-budget-guard.tests.ps1` já usa, resolve.

5. **O pwsh decodifica o stdout de comando nativo com `[Console]::OutputEncoding`.** Rodado pelo Bash
   ou em janela oculta (o `rodar-suite`), esse valor é **850**; no terminal do agente, 65001. Medido:
   `& bash -c` imprimindo um travessão (3 bytes em UTF-8) devolve uma string de comprimento **3** sob
   850 e **1** sob UTF-8. Dois testes de `regras-do-canon-injetadas.tests.ps1` (6.51.0) comparavam a
   saída de `bash`/`powershell.exe` com o valor calculado no próprio processo, e ficavam **verdes no
   terminal do agente e vermelhos pela suíte**. O produto estava certo; o teste lia os bytes do filho
   na codepage errada. O filho já forçava UTF-8 na escrita, e faltava o pai na leitura. A guarda
   `Should -Not -Match 'â€'` não pegou porque procura o mojibake do cp1252, e o do cp850 tem outra
   cara. Atribuído rodando o arquivo num worktree limpo em `HEAD` (falhava igual) e depois pelas duas
   ferramentas (850 vermelho, 65001 verde), antes de qualquer conserto.

**A regra:** se o teste depende de uma propriedade do ambiente (codepage, ferramenta ausente,
interpretador presente), **afirme essa propriedade num teste**, não num comentário. Pré-condição não
provada é o fixture fácil de [[paridade-testada-no-caso-facil-nao-e-paridade]], agora do lado do
processo em vez do lado do dado.

**Guarda:** `plugin/percus-review/tests/_dispatch-paridade.ps1` (`Get-CodepageDoCmdDeTeste`,
`Get-EnvSemJq`, `Invoke-BashComando`) e os `It` de pré-condição de
`dispatch-pre-paridade-sh.tests.ps1` e `dispatch-post-paridade-sh.tests.ps1`.

**Relacionado:** [[crlf-mata-regex-git-bash]] (a quinta armadilha da mesma tarefa: o `\r` do
`jq.exe` nativo, que zerou a seleção de checks) · [[regra-duplicada-ps1-sh]].
