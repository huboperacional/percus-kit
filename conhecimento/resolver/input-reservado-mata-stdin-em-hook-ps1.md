## `$input` é variável reservada do PowerShell — atribuir a ela mata a leitura de stdin do próprio script, e o hook fica inerte pra sempre {#input-reservado-mata-stdin-em-hook-ps1}

`tags: hooks, PowerShell, stdin, Console.In, input, variavel reservada, PreToolUse, Stop, ExitPlanMode, pwsh, powershell.exe, -File, skip silencioso, gate falha aberto, TDD`

**Contexto:** hook `.ps1` de `PreToolUse`/`Stop`/etc que lê o JSON do payload assim:

```powershell
$stdin = [Console]::In.ReadToEnd()
if (-not $stdin) { exit 0 }
$input = $stdin | ConvertFrom-Json      # <- BUG: $input é reservada
$command = $input.tool_input.command
```

**O sintoma:** o hook nunca faz nada. Sempre `exit 0`, sempre silencioso, mesmo com stdin real
sendo enviado (confirmado via `.cmd` real do kit, `cmd.exe /c "powershell.exe -File hook.ps1 < payload.json"`
— o mesmo caminho que o harness usa em produção, não um artefato de teste). `[Console]::In.ReadToEnd()`
devolve **string vazia**, então o guard da linha seguinte (`if (-not $stdin) { exit 0 }`) dispara
sempre, antes de qualquer lógica do hook rodar.

**Por que não aparece no parser nem no lint:** `$input = ...` é uma atribuição sintaticamente
válida. `$input` é a variável automática que representa o enumerador de pipeline do
script/função/scriptblock atual. O PowerShell não impede reatribuí-la, mas a mera presença dela em
qualquer lugar do script (mesmo como alvo de atribuição, mesmo depois de já ter lido
`[Console]::In`) muda como o runtime trata a entrada de pipeline do processo — e drena o stream
antes do código do usuário conseguir lê-lo de novo. Isso reproduz com pipe do PowerShell
(`X | & pwsh -File script.ps1`) e com redirecionamento puro de SO (`powershell.exe -File s.ps1 <
payload.json`), então não é artefato de um harness de teste específico — é do runtime.

**Como foi achado:** não por suspeita — por TDD. Um teste de regressão do caso MAIS simples
possível (tsconfig na raiz, sem nada de monorepo) falhou inesperadamente contra um hook que a
lógica de negócio dizia estar correta. Instrumentação com trace em arquivo (`Write-Host` não
serve: vai pro stream 6/Information, que `2>&1` não captura) isolou a divergência numa única linha.

**Blast radius medido (2026-09-04, canon 6.44.0):** a mesma linha `$input = $stdin |
ConvertFrom-Json` existia em **5 hooks**, todos com o padrão idêntico:
`types-check-pre-commit.ps1`, `auth-import-pre-commit.ps1`, `migration-check-pre-commit.ps1`,
`on-stop-check.ps1`, `pre-plan-exit.ps1`. Os 4 primeiros nasceram no mesmo commit (`719f166`,
2026-05-16); o último 2 semanas antes. **Todos os 5 estavam completamente inertes desde que
nasceram — ~4 meses** — porque nenhum tinha teste (nada exercitava stdin real de ponta a ponta) e
o próprio hook mascarava a falha: `if (-not $stdin) { exit 0 }` é indistinguível, do lado de fora,
de "rodei e não achei nada pra bloquear". Dois desses cinco são guardas de segurança/integridade
(`auth-import`, `migration-check`) — o gate existia no código e na intenção, mas nunca no ar.

**A correção é renomear, não é reescrever nada mais:**

```powershell
$payload = $stdin | ConvertFrom-Json
$command = $payload.tool_input.command
```

`crud-evidence-warn.ps1` já usava `$payload` (nome correto) desde sempre — comparar um hook que
funciona contra um que não é o que expôs a causa depois que a instrumentação achou a linha exata.

**Como confirmar que um `.ps1` de hook está limpo, sem esperar um bug aparecer:**

```powershell
grep -rn '^\s*\$input\s*=' plugin/percus-review/hooks/*.ps1
```

Zero ocorrências é o estado correto. Qualquer atribuição a `$input` num script top-level lido via
`-File` é suspeita — não precisa ser exatamente este padrão de stdin pra doer.

**Por que "sem teste" é a causa-raiz de verdade, não só a $input:** `ps51-compat.tests.ps1` prova
que todo `.ps1` **parseia** sob PowerShell 5.1 real (o runtime de produção — a suíte roda em pwsh 7,
que é cego a essa classe de erro por construção). Mas parsear não é executar: nenhum teste do kit,
antes disto, alimentava stdin de verdade num hook via `-File` e conferia o *comportamento*. Um hook
sem teste de comportamento é exatamente "gate que existe na crença, não no ar" — a mesma classe que
a devolutiva cross-produto sobre `types-check` em monorepo (`Plexco Tasks`, 2026-09-04) descreveu
para o skip silencioso por tsconfig ausente: **um gate que falha aberto não produz só um bug —
produz a crença de que o gate existe.**

**Princípio geral:** ao escrever um hook `.ps1` novo que lê `tool_input`/payload de stdin, nomeie a
variável **qualquer coisa menos `$input`** (`$payload`, `$data`, `$evt`) — e escreva pelo menos um
teste que alimente stdin real via `-File` (Pester, mesmo padrão de `crud-evidence-warn.tests.ps1`)
antes de confiar que o hook roda. Um hook sem esse teste pode estar morto desde o primeiro commit e
ninguém vai saber até alguém procurar.
