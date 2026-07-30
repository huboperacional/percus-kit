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

## 2. Camada 1 — o gatilho: BOM nos 34

> **Escopo revisado em execução (2026-07-30), de 16 para 34.** A revisão de qualidade do teste da
> Task 1 mostrou que parse-only só enxerga metade da armadilha: mojibake que **quebra** sintaxe vira
> erro de parse (os 16), mas acento dentro de string que continua sintaticamente válido **passa
> verde** e o hook apenas imprime lixo. Medido: **34** `.ps1` do kit têm caractere não-ASCII sem BOM;
> 16 quebram hoje, 18 estão armados. Dois dos 18 são hooks wired — `pre-commit-check.ps1` e
> `on-stop-check.ps1`. Como a operação é a mesma (prepend de 3 bytes, verificado byte-a-byte),
> fechar 34 custa o mesmo trabalho e entrega o invariante de verdade em vez da promessa do §7.

Adicionar BOM (3 bytes) aos 34 arquivos, **conteúdo intacto**. Escolhido sobre "ASCII puro" porque o
diff é de uma linha por arquivo, não há prosa pra eu errar, e as mensagens ao operador mantêm os
acentos corretos.

Verificado antes de escolher: nada no kit ancora regex na primeira linha de `.ps1` (os `head -1` que
existem são sobre `.jsonl` e `plugin.json`), então o BOM não quebra gate nem teste.

**Método — obrigatório, e não é detalhe.** O BOM entra por **manipulação de bytes**, nunca por
`Set-Content`/`Out-File`/editor:

```powershell
$bytes = [IO.File]::ReadAllBytes($f)
[IO.File]::WriteAllBytes($f, (@(0xEF,0xBB,0xBF) + $bytes))
```

Os arquivos do kit estão com fim de linha **LF** no working tree (medido: `external-action-guard.ps1`
tem 91 LF e zero CRLF) e o repo está com `core.autocrlf=true` sem `.gitattributes`. Qualquer via de
texto reescreve fim de linha: `Set-Content -Encoding utf8BOM` no pwsh 7 já acrescenta um CRLF final
(4098 → 4103 bytes, arquivo com terminação mista); no PowerShell 5.1 converteria os 91 LF em CRLF. O
resultado seria um diff de arquivo inteiro em vez de uma linha, e a promessa de "conteúdo intacto"
deixaria de ser verdade.

**Verificação por arquivo:** o conteúdo a partir do 4º byte tem que ser byte-idêntico ao original
(provado na bancada). O outro lado da mesma prova é `git diff --numstat` dar `1 1` em **todos** os
arquivos: o BOM cola na primeira linha existente, então o git registra uma modificação de linha
(1 remoção + 1 inserção), não uma inserção pura. Fim de linha reescrito apareceria como arquivo
inteiro modificado, e é isso que o `numstat` descarta.

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
| `ps51-compat.tests.ps1`, `It` de parse | todo `.ps1` do kit parseia sob o `powershell.exe` real | os 16 que quebram |
| `ps51-compat.tests.ps1`, `It` de invariante | `.ps1` com byte > `0x7F` **tem** BOM | os 34 — inclusive os 18 que passam no parse e só imprimem lixo |
| `hook-wrapper-fail-loud.tests.ps1` | `.cmd` com `.ps1` quebrado sai **não-zero**, e `.ps1` sadio com `exit 2` continua devolvendo 2 | o amplificador |

O `It` de invariante existe porque o de parse é cego para metade da classe (ver §2). Ele também
protege o próprio `ps51-compat` de passar verde por varredura vazia: o auxiliar reporta quantos
arquivos viu e o teste exige um piso, senão arquivo movido ou erro de ACL engolido deixaria a
varredura vazia satisfazendo `Should -BeNullOrEmpty` — guarda que não guarda, a mesma classe que
este spec conserta.

**Como `ps51-compat` afere, exatamente:** invoca o `powershell.exe` real e pede **só o parse**, sem
executar o script — `[System.Management.Automation.Language.Parser]::ParseFile($caminho, [ref]$null,
[ref]$erros)`, reprovando se `$erros.Count -gt 0`. Executar os `.ps1` para descobrir se parseiam
seria disparar hook de verdade (`git`, rede, escrita em `.deepseek/`) como efeito colateral de um
teste. O parse tem que rodar **sob o 5.1**, não sob o pwsh 7: é a diferença entre os dois que é o
objeto do teste.

**Como `hook-wrapper-fail-loud` monta o caso, exatamente:** copia o **`.cmd` real** pro temp e planta
ao lado um `.ps1` **sintético** de mesmo nome (o `.cmd` resolve o script por `%~dp0`, então o par
funciona sem tocar no original). O artefato sob teste é o **wrapper**, não a guarda.

O `.ps1` sintético do caso quebrado tem uma linha com **em dash dentro de string** —
`Write-Host "x — y"` — e é gravado **sem BOM**: o gatilho real deste spec.

Três decisões que não são estilo:

- **Sintético, não cópia do `.ps1` real.** Depois da camada 1 o arquivo real **tem BOM**, então a
  cópia também teria, o 5.1 leria UTF-8 e o em dash não corromperia nada — o teste passaria sem
  testar. Sintético sem BOM é a única forma que continua reproduzindo o defeito depois do conserto.
- **Nem chave desbalanceada nem lixo aleatório.** Precisa ser falha de **parse**. Corrupção qualquer
  pode virar falha de **execução**, que o wrapper atual já propaga corretamente — o teste passaria
  pelo motivo errado e não provaria nada sobre o amplificador.
- **O corpo sadio do arquivo faz `exit 0`.** Se um dia a corrupção parar de corromper, o script roda,
  sai 0, e o teste **falha**. A direção da falha é segura: nunca vira falso verde.

**Máquina sem `powershell.exe`:** o teste reporta `Skipped`, não verde. É honesto porque essa máquina
também não roda os `.cmd` — o hook é irrelevante ali.

## 7. Riscos aceitos (declarados, não resolvidos)

- **Consumidor externo do BOM.** Verifiquei os consumidores **dentro** do kit. Não tenho como
  enumerar com honestidade quem, fora dele, lê `.ps1` do kit. Rede: suíte completa (196 testes) mais
  execução dos 11 `.cmd` depois da mudança. O BOM é invisível para o próprio PowerShell.
- **`.ps1` novo entrando sem BOM.** Coberto pelo `It` de invariante, que barra byte > `0x7F` sem BOM
  — não só o que quebra o parse. Era aqui que a versão anterior deste spec prometia mais do que
  entregava: ela dizia que o teste de parse barrava a classe, e ele não barrava.
- **`.ps1` novo em ASCII puro que depois recebe acento por edição.** Aí o invariante pega no momento
  da edição, não antes. É o comportamento desejado — não há o que fazer em arquivo que ainda está
  correto.

## 8. Registro do conselho

- **Consult** (deepseek + groq-llama, 2026-07-30): maioria por `-File`. O DeepSeek matou a opção do
  sentinela com o argumento do exit 97 ser lido como bloqueio. A Llama levantou encoding de stdout;
  testado e refutado.
- **Pre-mortem** (mesmos dois): consenso 2/2 em três riscos — guardas revividas quebrando fluxo,
  BOM em consumidor não verificado, `-File` mudando args/CWD. O terceiro foi fechado por medição.
  **Caveat de método:** os três riscos ecoam a lista `(a)(b)(c)` que eu mesmo pus no prompt, então a
  informação independente ali é baixa. O que veio além do plantado: o modo de falha **social** (o
  conserto ser revertido) e a hipótese de CWD.
- **Review do spec escrito** (mesmos dois): o DeepSeek achou três ambiguidades reais, todas
  aplicadas — método de gravação do BOM (§2), como o `ps51-compat` parseia sem executar (§6), e o
  que exatamente corromper no teste do wrapper (§6). A Llama não trouxe achado nesta rodada
  (resumiu o spec); registrado como veio.
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
