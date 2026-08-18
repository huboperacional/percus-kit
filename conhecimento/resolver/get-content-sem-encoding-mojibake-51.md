## `Get-Content` sem `-Encoding`: o MESMO arquivo chega diferente no PS 5.1 e no pwsh 7, e o regex acentuado para de casar {#get-content-sem-encoding-mojibake-51}

`tags: powershell, 5.1, pwsh 7, Get-Content, encoding, ANSI, Windows-1252, UTF-8, BOM, mojibake, acento, regex nao casa, hook, guarda morta, exit 0, skip, json, markdown`

**Sintoma:** um script funciona quando você o roda na mão e não funciona como hook. Ou: funciona na sua máquina e "pula" no hook, sempre com uma mensagem de skip e **exit 0**, nunca com erro. Rodar sob `pwsh` dá certo; rodar sob `powershell.exe` dá o skip. Nenhum stack trace, nada em log.

**Causa raiz:** o **default de encoding do `Get-Content` difere entre runtimes**. No Windows PowerShell 5.1 é **ANSI (Windows-1252)**; no PowerShell 7 é **UTF-8**. Um arquivo de dados em UTF-8 **sem BOM** — que é o normal para markdown e o **obrigatório** para JSON — é lido corretamente no 7 e vira mojibake no 5.1:

```
pwsh 7 : # Canon Percus — versão atual
PS 5.1 : # Canon Percus â€” versÃ£o atual
```

Se o script então compara com um **regex que tem acento** (`Vers[aã]o can[oô]nica`), o match falha. E como o caminho de "não encontrei" quase sempre é um skip educado, o resultado é **guarda morta respondendo verde**.

**Solução:** declare o encoding em toda leitura — `Get-Content -Encoding UTF8 <path>` ou `[IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)`. Funciona igual nos dois runtimes, com ou sem BOM no arquivo.

⚠️ **Não tente consertar pelo lado do arquivo.** Markdown não usa BOM, e **JSON com BOM quebra parser alheio** (`ConvertFrom-Json` de outra stack, `jq`, libs de outras linguagens). Quem **lê** é que declara o encoding. Isto é o oposto do conserto da classe irmã, e confundir as duas leva a "corrigir" o arquivo errado.

**Classe IRMÃ, e não é a mesma** — ver [#hook-powershell-51-sem-bom-corrompe](hook-powershell-51-sem-bom-corrompe.md):

| | o que quebra | como aparece | conserto |
|---|---|---|---|
| irmã (já conhecida) | o `.ps1` **fonte** sem BOM | erro de **parse**, alto | BOM **no `.ps1`** |
| esta | o `.md`/`.json` **lido** | regex não casa, **silêncio** | `-Encoding` **na leitura** |

Compartilham a origem (default de encoding do 5.1) e exigem guardas diferentes: uma varredura de BOM em `.ps1` **não vê** esta, e foi exatamente assim que ela sobreviveu.

**Como caçar:** `grep -n "Get-Content" *.ps1 | grep -v Encoding` em tudo que roda sob 5.1 (todo hook, porque `.cmd` chama `powershell.exe`, nunca `pwsh`). Depois pergunte de cada um: o conteúdo tem acento? é comparado com regex/string acentuada? é JSON com texto em PT-BR? Se sim, está corrompendo agora.

**Como testar de verdade:** teste estrutural (`todo Get-Content declara -Encoding`) pega a reincidência, mas quem prova o conserto é o **teste comportamental** — execute o script sob `powershell.exe` de verdade e exija uma marca da saída de sucesso. Com anti-vacuidade: sem exigir a marca positiva, um script que nem rodou deixa o teste verde por saída vazia.

**Ref:** percus-kit 6.36.5, 2026-08-16. Eram 9 chamadas em 4 hooks; o `state-drift-check.ps1` já usava `-Encoding UTF8` desde antes — a lição existia em **um** arquivo e nunca generalizou, que é como toda reincidência começa.
