# Três guardas `PreToolUse` mortas respondendo verde: encoding + wrapper que engole falha

**Data:** 2026-07-30
**Estado:** design aprovado pelo operador
**Origem:** o `renomear-kit-local.ps1` quebrou na mão do operador com 7 erros de parse que apontavam
para linhas sem defeito. A causa (encoding lido como ANSI pelo PowerShell 5.1) valia uma varredura;
a varredura achou 16 arquivos com a mesma armadilha e, junto, um amplificador que transformou três
guardas em fail-open silencioso.

---

## 1. Problema

O kit tem **duas** falhas encaixadas. Sozinha, a primeira seria barulhenta. É a segunda que a
transformou em silêncio.

**Gatilho — 16 `.ps1` que o PowerShell 5.1 não consegue parsear.**
Windows PowerShell 5.1 lê `.ps1` **sem BOM** como ANSI (CP1252). Um em dash (`—`, U+2014) é
`E2 80 94` em UTF-8; lido como ANSI vira três caracteres, e o último (`94`) é `”` — **aspa curva**,
que o PowerShell aceita como delimitador de string. Dentro de uma string, ela fecha a string antes
da hora e o resto do arquivo desanda. Em comentário é inofensivo (comentário vai até o fim da
linha) — medido nos dois casos.

**Amplificador — o wrapper `.cmd` não distingue "guarda bloqueou" de "guarda morreu".**
Os 11 wrappers invocados por `hooks.json` rodam:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0X.ps1\"; exit $LASTEXITCODE"
```

Script que não parseia **nunca roda** → `$LASTEXITCODE` fica nulo → `exit` sai **0** → o harness lê
"guarda aprovou".

**O que a medição de 2026-07-30 encontrou:**

| Fato | Evidência |
|---|---|
| 16 `.ps1` do kit não parseiam sob 5.1 | `Parser::ParseFile` rodado pelo próprio 5.1 em todos os `.ps1` do kit |
| A causa é **só** encoding, nos 16 | copiados pro temp **com BOM e conteúdo intacto**: os 16 parseiam com 0 erros |
| Os 5 que pareciam ter sintaxe PS7 não têm | os `&&` estavam **dentro de string** (comandos bash em teste) e vazaram pra posição de código quando a corrupção rompeu o delimitador |
| 3 dos 16 são guardas **wired** em `PreToolUse` | `hooks.json`: `external-action-guard`, `auth-import-pre-commit`, `types-check-pre-commit` |
| As 3 respondem **verde** mortas | rodando os `.cmd` reais: `exit=0` **com** erro de parse. Controle: `pre-commit-check` (que parseia) também sai 0, então 0 é indistinguível de "aprovou" |
| Todo hook passa por `powershell.exe` | os 11 `.cmd` usam `powershell.exe`, que é o 5.1 — nunca o pwsh 7 |
| A suíte não veria nada disso | ela roda em **pwsh 7**, que lê UTF-8 por default |

## 2. Camada 1 — o gatilho: BOM nos 16

Adicionar BOM (3 bytes) aos 16 arquivos, **conteúdo intacto**. Escolhido sobre "ASCII puro" porque o
diff é de uma linha por arquivo, não há prosa pra eu errar, e as mensagens ao operador mantêm os
acentos corretos.

Verificado antes de escolher: nada no kit ancora regex na primeira linha de `.ps1` (os `head -1` que
existem são sobre `.jsonl` e `plugin.json`), então o BOM não quebra gate nem teste.

## 3. Camada 2 — o amplificador: `-File` nos 11 `.cmd`

```diff
- powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0X.ps1\"; exit $LASTEXITCODE"
+ powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0X.ps1"
```

Bancada, cenário por cenário:

| Cenário | `-Command` (atual) | `-File` (novo) |
|---|---|---|
| guarda sadia que bloqueia (`exit 2`) | 2 | 2 |
| guarda com erro de parse | **0** — aprova | **1** — bloqueia |
| `.ps1` ausente | **0** — aprova | não-zero |
| stdin (o hook recebe JSON por stdin) | chega | chega |
| stdout com acentos | — | **byte-idêntico** ao `-Command` |
| `$PSScriptRoot`, `CWD`, `$PSCommandPath`, `$args` | — | **idênticos** ao `-Command` |

As duas últimas linhas existem porque o conselho levantou as hipóteses; ambas foram testadas e não se
sustentam. A de contexto importava de verdade: cinco hooks usam `(Get-Location).Path` **como raiz do
projeto** (`external-action-guard`, `pre-commit-check`, `on-stop-check`, `state-drift-check`,
`pre-plan-exit`) e sete usam `$PSScriptRoot` pra carregar `_helpers.ps1`. Se `-File` mexesse em
qualquer um dos dois, a guarda passaria a olhar o projeto errado — calada.

**Descartado:** manter `-Command` com sentinela (`exit 97` quando `$LASTEXITCODE` for nulo). O
harness lê apenas zero/não-zero, então o código "diagnóstico" seria interpretado como **bloqueio** —
a opção que parecia mais informativa é a que trava a máquina. Também descartado trocar pra `pwsh`
com fallback: o engolimento é do `-Command`, não da versão.

## 4. Ordem é obrigatória, não preferência

**Camada 1 antes da 2, ou as duas no mesmo commit.** Wrapper barulhento com os três `.ps1` ainda
quebrados faz as guardas saírem de "aprovam tudo" para **"bloqueiam todo `PreToolUse` Bash"** — e a
máquina para de commitar, inclusive o commit do próprio conserto. É um estado que se auto-tranca.

## 5. Consequência esperada: as guardas voltam a barrar

**A camada 1 sozinha já revive as guardas** — script sadio propaga o exit code mesmo com `-Command`
(medido: `exit 2` → 2). Então "commits que passavam começam a falhar" chega junto com o **BOM**, não
com o `-File`:

- `external-action-guard` barra `gh pr comment`, `git push` e afins sem `PERCUS_EXTERNAL_OVERRIDE=1`
- `types-check-pre-commit` barra commit com erro de tipo
- `auth-import-pre-commit` barra import de auth fora do padrão

Não é regressão; é a função voltando depois de um período em que não rodou. Mas **vai parecer**
regressão para quem não for avisado, e o conselho apontou esse como o motivo de falha mais provável
do plano: o conserto ser revertido porque "quebrou os commits".

**Mitigação:** depois da camada 1 e antes de seguir, exercitar as três guardas com payloads
representativos (um `git push`, um import de auth, um erro de tipo) para medir o que elas voltam a
barrar. O commit declara o que muda e qual é o escape de cada uma
(`PERCUS_EXTERNAL_OVERRIDE=1`, `PERCUS_HOOKS_DISABLED=1`).

## 6. Camada 3 — prevenção: dois testes comportamentais

Os dois rodam o artefato de verdade; nenhum inspeciona bytes ou lista de caracteres. Inspeção de
código provaria uma causa; o que precisa ser provado é que o artefato **roda**.

| Teste | O que prova | O que teria pego |
|---|---|---|
| `ps51-compat.tests.ps1` | todo `.ps1` do kit parseia sob o `powershell.exe` real | os 16 |
| `hook-wrapper-fail-loud.tests.ps1` | `.cmd` com `.ps1` quebrado sai **não-zero**, e `.ps1` sadio com `exit 2` continua devolvendo 2 | o amplificador |

O segundo copia um par real `.cmd` + `.ps1` pro temp e corrompe a cópia — o `.cmd` resolve o script
por `%~dp0`, então o par copiado funciona sem tocar no original.

**Máquina sem `powershell.exe`:** o teste reporta `Skipped`, não verde. É honesto porque essa máquina
também não roda os `.cmd` — o hook é irrelevante ali.

## 7. Riscos aceitos (declarados, não resolvidos)

- **Consumidor externo do BOM.** Verifiquei os consumidores **dentro** do kit. Não tenho como
  enumerar com honestidade quem, fora dele, lê `.ps1` do kit. Rede: suíte completa (196 testes) mais
  execução dos 11 `.cmd` depois da mudança. O BOM é invisível para o próprio PowerShell.
- **Os 13 `.ps1` restantes que hoje parseiam** podem receber um em dash amanhã. É exatamente o que o
  `ps51-compat.tests.ps1` passa a barrar.

## 8. Registro do conselho

- **Consult** (deepseek + groq-llama, 2026-07-30): maioria por `-File`. O DeepSeek matou a opção do
  sentinela com o argumento do exit 97 ser lido como bloqueio. A Llama levantou encoding de stdout;
  testado e refutado.
- **Pre-mortem** (mesmos dois): consenso 2/2 em três riscos — guardas revividas quebrando fluxo,
  BOM em consumidor não verificado, `-File` mudando args/CWD. O terceiro foi fechado por medição.
  **Caveat de método:** os três riscos ecoam a lista `(a)(b)(c)` que eu mesmo pus no prompt, então a
  informação independente ali é baixa. O que veio além do plantado: o modo de falha **social** (o
  conserto ser revertido) e a hipótese de CWD.
- **Cross-Claude não rodou** (exige subagent; não autorizado nesta sessão).

## 9. Fora de escopo

| Item | Por quê |
|---|---|
| Os `.sh` equivalentes dos hooks | não têm o problema: bash não reinterpreta UTF-8 como ANSI |
| 4ª família de ponteiro: `.git/percus-v2-dir` | 12 repos desta máquina apontam pro caminho morto após o rename de hoje; decisão do operador foi tratar depois |
| Migrar os 11 hooks pro `settings.json` | é o "plano 2" já previsto no design da casa única |
| Converter os 16 para ASCII puro | descartado nesta decisão; o `renomear-kit-local.ps1` fica ASCII por ser o único que o operador roda à mão |

## Anexo A — os 16 arquivos (medidos em 2026-07-30, erros sob 5.1)

Caminhos relativos a `D:\Claud Automations\percus-kit`.

| # | Arquivo | Erros | Papel |
|---|---|---|---|
| 1 | `plugin\percus-review\hooks\external-action-guard.ps1` | 10 | **guarda wired** (`PreToolUse`) |
| 2 | `plugin\percus-review\hooks\auth-import-pre-commit.ps1` | 7 | **guarda wired** (`PreToolUse`) |
| 3 | `plugin\percus-review\hooks\types-check-pre-commit.ps1` | 7 | **guarda wired** (`PreToolUse`) |
| 4 | `scripts\percus-review-auto.ps1` | 13 | wrapper de review (invocado à mão / allowlist) |
| 5 | `plugin\percus-review\scripts\deepseek-review.ps1` | 7 | provider de review |
| 6 | `plugin\percus-review\tests\state-drift-check.tests.ps1` | 37 | teste |
| 7 | `plugin\percus-review\tests\hardening-2026-05-19.tests.ps1` | 7 | teste |
| 8 | `plugin\percus-review\tests\council-code-injection.tests.ps1` | 5 | teste |
| 9 | `plugin\percus-review\tests\router-sensitive-paths.tests.ps1` | 5 | teste |
| 10 | `plugin\percus-review\tests\pre-commit-path-resolution.tests.ps1` | 4 | teste |
| 11 | `plugin\percus-review\tests\mock-scan.tests.ps1` | 3 | teste |
| 12 | `plugin\percus-review\tests\gate-conhecimento.tests.ps1` | 2 | teste |
| 13 | `plugin\percus-review\tests\hardening-2026-05-18.tests.ps1` | 2 | teste |
| 14 | `plugin\percus-review\tests\version-alignment.tests.ps1` | 2 | teste |
| 15 | `plugin\percus-review\tests\crud-evidence-warn.tests.ps1` | 1 | teste |
| 16 | `plugin\percus-review\tests\fact-check-triage-integration.tests.ps1` | 1 | teste |

Os 11 `.cmd` da camada 2 são todos os que existem em `plugin\percus-review\hooks\` — o mesmo conjunto
que `hooks.json` invoca, um por hook wired.
