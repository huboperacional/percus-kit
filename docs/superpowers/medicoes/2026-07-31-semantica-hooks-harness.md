# Semântica de hooks do harness — medido, não suposto

**Data:** 2026-07-31 · **Task 1 do plano 2** (`enforcement que não consegue sumir calado`).

Este arquivo existe porque o plano 2 inteiro depende de comportamento que a doc oficial do Claude Code
marca como **não-documentado**. Projetar por cima de suposição é o que produziu o gate cego de
2026-07-29 e as guardas mortas de 2026-07-30. Cada item abaixo tem o comando rodado e a saída
observada. Onde não medi, está escrito que não medi.

## Estado do ambiente no momento da medição

Registrar a **versão** e não só a data é obrigatório: com `autoUpdate` ligado, a versão viva muda
sozinha, e regra de decisão congelada contra um harness que já não está instalado decide pelo motivo
errado. Use `scripts/revalidar-medicao.ps1` antes de confiar neste arquivo.

| O quê | Observado |
|---|---|
| Claude Code | `2.1.191` (`claude --version`) |
| `percus-review` instalado | **`6.32.0`**, `installPath` = `…\plugins\cache\percus-tools\percus-review\6.32.0`, `installedAt` 2026-07-30T21:55:56Z, `gitCommitSha` `ee6eb87b` |
| `plugin.json` do repo | `6.32.0` (alinhado com o instalado) |
| Pastas de cache em disco | `6.28.0` (plugin.json 6.28.0) · `6.29.0` (**plugin.json diz 6.30.0** — divergente) · `6.32.0` |
| `installed_plugins.json` | tem **uma** entrada para `percus-review@percus-tools`, apontando a `6.32.0`. As outras duas pastas são **órfãs**: existem em disco e não são referenciadas |
| `PERCUS_CANON_DIR` | processo **e** usuário = `D:\Claud Automations\percus-kit` (iguais; sem o descasamento que a fase 1 registrou) |

## Item 1 — Qual pasta de cache o `CLAUDE_PLUGIN_ROOT` resolve

**Resposta: `6.32.0`. O §2 do spec de 2026-07-29, que registra `6.28.0`, está desatualizado.**

Medido por comportamento, não por leitura de arquivo. O `external-action-guard` da `6.28.0` estava
**morto** — respondia verde sem rodar, por causa do wrapper `-Command` que engolia erro de parse — e
só voltou a barrar no fix de 2026-07-30 (`e06e839`). Logo, se ele barra, a versão viva é pós-fix:

```
$ git push --dry-run
PreToolUse:Bash hook error: ["${CLAUDE_PLUGIN_ROOT}/hooks/external-action-guard.cmd"]:
[percus:hook external-action-guard] BLOCK (R20):
  Razao: acao externa publica requer aprovacao explicita do operador (R20)
```

Corroborado pelo `installed_plugins.json`, que lista uma única instalação, na `6.32.0`.

**Consequência para a Task 3:** publicar a 6.33.0 surte efeito. O passo 6 da §4.4 do spec
("sincronizar as 2 pastas de cache") não só está errado no número — está errado no método: as pastas
velhas não são resolvidas, são lixo.

## Item 2 — Hook de plugin e hook de `settings.json` coexistem?

**Resposta: os DOIS rodam. Não há precedência — há união.**

Numa única chamada `Bash`, com o guard do plugin e três sondas do `settings.json` do projeto
registrados no mesmo evento:

```
$ git push --dry-run
  → plugin external-action-guard: exit 2, ação BLOQUEADA
  → .percus/medicao-harness.log ganhou, na mesma chamada:
      SONDA-P2-alternancia-disparou
      SONDA-P1 chaves=D:\Claud Automations\percus-kit ...
      P7-CMD-INICIOU dp0=…\scratchpad\
      P7-STDIN=635 bytes :: {"session_id":"38f1e2d4-…
```

O bloqueio do plugin **não** impediu as sondas de rodar, e as sondas saindo 0 **não** impediram o
bloqueio. Qualquer `exit 2` de qualquer fonte bloqueia.

**Ordem: não é sequencial.** A sonda P7 (que gera um `powershell.exe`) chegou ao log **depois** de uma
sonda declarada num bloco posterior. Os hooks rodam concorrentemente. Corolário de projeto: **não**
faça dois hooks anexarem ao mesmo arquivo — a intercalação é real.

**Consequência para a Task 6:** o enforcement duplo sai do campo da conjectura. Para as 8 guardas é
inofensivo (decidir duas vezes o mesmo). Para os 3 observadores é dano real — `catalog_publish` faria
POST duplicado. A ordem por risco do plano continua necessária.

## Item 3 — Expansão de variável no campo `command`

> **CORREÇÃO (mesma data, medição posterior).** A primeira redação deste item concluía que "a
> expansão é do harness, não do shell". **Está errada.** Uma sonda seguinte revelou o shell (item 9)
> e com ele o mecanismo: quem expande é o **bash**, fazendo expansão de shell comum. O resultado
> prático não muda — `${PERCUS_CANON_DIR}` funciona — mas o motivo, e portanto os caveats, mudam:
> depende da variável estar **no ambiente do processo do hook**, e a sintaxe válida é a do bash
> (`$VAR` e `${VAR}`), não uma substituição proprietária do harness. Registrado como correção em vez
> de reescrito porque a conclusão errada já tinha sido usada para decidir o ramo da Task 6, e apagar
> o erro apagaria a razão de a decisão continuar valendo.

**Resposta: `${VAR}` EXPANDE — por expansão de shell do bash.**

O resultado abaixo também **contradiz** a doc oficial, que documenta só `${CLAUDE_PROJECT_DIR}`,
`${CLAUDE_PLUGIN_ROOT}` e `${CLAUDE_PLUGIN_DATA}` como expansíveis. Sonda com as três sintaxes na
mesma linha:

```
command: echo SONDA-P1 chaves=${PERCUS_CANON_DIR} dolarenv=$env:PERCUS_CANON_DIR porcento=%PERCUS_CANON_DIR% >> "…"

saída:   SONDA-P1 chaves=D:\Claud Automations\percus-kit dolarenv=:PERCUS_CANON_DIR porcento=%PERCUS_CANON_DIR%
```

| Sintaxe | Resultado | Leitura |
|---|---|---|
| `${PERCUS_CANON_DIR}` | **expandiu** para o caminho | expansão de shell do bash, lendo o ambiente do processo do hook |
| `$env:PERCUS_CANON_DIR` | virou `:PERCUS_CANON_DIR` | bash expandiu `$env` (variável inexistente, vazia) e deixou `:PERCUS_CANON_DIR` literal — sintaxe PowerShell não vale aqui |
| `%PERCUS_CANON_DIR%` | literal | **não é `cmd.exe`** executando o `command` |

**Consequência para a Task 6:** `${PERCUS_CANON_DIR}` é utilizável. O erro do spec (design.md:85) não
é a sintaxe — é o caminho: os hooks estão em `<kit>\plugin\percus-review\hooks\`, não em `<kit>\hooks\`.
Ainda assim, caminho absoluto escrito pelo instalador continua preferível: não depende de a variável
estar setada, e o `renomear-kit-local.ps1` já reescreve caminhos do settings quando o kit é renomeado.

## Item 4 — Matcher

**Alternância funciona. Matcher é case-sensitive. A tool chama-se `PowerShell`.**

Três chamadas (PowerShell, Bash, PowerShell) com três sondas registradas:

| Sonda | Matcher | Disparos | Leitura |
|---|---|---|---|
| P2 | `Bash\|PowerShell` | **3 de 3** | alternância casa as duas tools |
| P1 / P7 | `Bash` | 1 de 3 | só a chamada Bash |
| P3 | `bash` (minúsculo) | **0 de 3** | **case-sensitive** |

**Consequência para a Task 4:** `Bash|PowerShell` é a forma certa, e escrever `bash` seria uma guarda
que nunca dispara — exatamente o tipo de ausência silenciosa que o plano existe para matar.

## Item 5 — `Stop` / `PreCompact` honram `exit 2`?

**NÃO MEDIDO — e tornado irrelevante por projeto.**

Medir exigiria um hook que sai 2 num evento de encerramento, com risco de travar o fim da sessão. Em
vez de correr esse risco, o health check da Task 7 é **observador que sempre sai 0**, como o plano já
determina ("observador, nunca guarda"). A semântica deixa de importar.

## Item 6 — O campo `async` é honrado?

**NÃO MEDIDO.** O campo não consta da doc oficial, e os 11 registros atuais passam `"async": false`.
As sondas foram registradas **sem** o campo e se comportaram como bloqueantes/síncronas — que é o
comportamento desejado. Decisão: os registros gerados pelo plano **não emitem** `async`. Um campo que
a doc não conhece e que não muda o observado é ruído que finge ser configuração.

## Item 7 — Um `.cmd` chamado do `settings.json` herda stdin?

**Resposta: herda, íntegro.**

```
P7-CMD-INICIOU dp0=C:\Users\…\scratchpad\
P7-STDIN=544 bytes :: {"session_id":"38f1e2d4-…","transcript_path":"D:\\Claud Automations\\…
```

Duas chamadas deram 544 e 635 bytes — o tamanho acompanha o comando, ou seja, é o payload real, não
um eco fixo. `%~dp0` resolve para o diretório do próprio `.cmd`.

**Consequência para a Task 3:** o trampolim pode viver num `.cmd` sem quebrar a cadeia de stdin.

## Item 8 — `SessionStart` dispara mesmo? (prova positiva)

**Resposta: dispara. Observado na abertura desta própria sessão**, a partir do `settings.json` do
projeto, com o harness rotulando o sucesso:

```
SessionStart:startup hook success: [GATE INICIO] Se este projeto tem HANDOFF.md/docs/PLANO.md:
leia primeiro pra saber estado atual e proximos passos. Se eh canon/lib/tooling, ignore.
```

É prova **positiva** — o evento disparou e produziu saída visível —, não "quebrei e ele gritou". O
risco nº 1 do pre-mortem (o health check nascer morto) está retirado.

## Item 9 — Qual shell executa o `command`? (não estava na Task; a Task 3 exigiu)

**Resposta: `/usr/bin/bash` 5.2.37 (Git Bash). Não é PowerShell, não é `cmd.exe`.**

A doc oficial diz "PowerShell on Windows". **Não é o que acontece nesta máquina.** Descoberto sem
querer, do jeito mais direto possível: uma sonda escrita em sintaxe PowerShell devolveu

```
/usr/bin/bash: -c: line 1: syntax error near unexpected token `'SONDA-STDERR-COM-EXIT-ZERO''
```

e a sonda seguinte, já em bash, confirmou por dentro:

```
SHELL=/usr/bin/bash  BASH=5.2.37(1)-release
CANON=D:\Claud Automations\percus-kit
ENVTEST=:PERCUS_CANON_DIR
```

É isto que explica o item 3 inteiro, e por isso ele levou correção: não há substituição proprietária
do harness — há um bash fazendo expansão de shell.

## Item 10 — Saída de hook que sai 0 é mostrada?

**Resposta: NÃO. Nem stderr, nem stdout.**

Duas sondas registradas no mesmo evento, uma escrevendo em stderr e outra em stdout, ambas saindo 0.
A chamada `Bash` seguinte rodou normalmente e **nenhuma das duas apareceu** — nem na saída da
ferramenta, nem como aviso. Só a terceira sonda, que escrevia num arquivo, deixou rastro.

Contraste com o que já estava observado: stderr de hook que sai **2** aparece (é como o
`external-action-guard` mostra o BLOCK), e saída de `SessionStart` aparece (é como o `[GATE INICIO]`
chega). O canal existe — mas não no caminho de sucesso.

**Consequência para a Task 3, e é uma mudança de projeto:** o "fallback barulhento" que o pre-mortem
exigiu **não pode morar no trampolim**. Uma guarda que resolve para o cache e depois sai 0 escreveria
para ninguém — barulho no vácuo é indistinguível de silêncio, que é exatamente o que o plano existe
para matar. O anúncio muda de lugar: vai para o health check da Task 7, em `SessionStart`, que é o
único canal provadamente visível. Isso promove a Task 7 de "peça que fecha a classe" para
**pré-requisito do valor da Task 3** — sem ela, a origem resolvida não tem como ser dita.

## Item 11 — `command` malformado: o que acontece?

**Resposta: bloqueia a ferramenta. Observado por auto-lockout.**

Uma sonda com erro de sintaxe fez o bash sair não-zero; como `PreToolUse` trata não-zero-não-2 como
erro e 2 como bloqueio, **toda chamada `Bash` passou a ser barrada** — inclusive a que eu usaria para
consertar a sonda. Saída pela tool `PowerShell`, que o matcher não cobria.

Isto é fail-closed funcionando, e é também uma armadilha operacional real: hook mal escrito no
`settings.json` global tranca a máquina inteira, e o conserto exige um caminho que o matcher não
cubra. **Consequência para a Task 6:** o instalador valida o JSON *e* a existência de cada `command`
em disco antes de salvar, e o backup datado é o que resta quando nem isso bastou.

## Achado extra, não previsto na Task

**Mudança em `settings.json` de projeto vale na hora, sem reiniciar a sessão.** As sondas foram
escritas e dispararam na chamada seguinte. Isso encurta o ciclo de canário da Task 5 e da Task 6 —
não é preciso reiniciar entre registrar e observar.

## Placar

| Item | Estado |
|---|---|
| 1 · cache resolvido | ✅ medido — `6.32.0` |
| 2 · coexistência | ✅ medido — **os dois rodam**, concorrentes, união de bloqueios |
| 3 · expansão de env var | ✅ medido — `${VAR}` expande (harness), `%VAR%` não, não é cmd.exe |
| 4 · matcher | ✅ medido — alternância sim, case-sensitive, tool é `PowerShell` |
| 5 · exit 2 em Stop/PreCompact | ⛔ não medido — irrelevante por projeto (health check sai 0) |
| 6 · campo `async` | ⛔ não medido — não emitir |
| 7 · stdin via `.cmd` | ✅ medido — herda íntegro |
| 8 · `SessionStart` | ✅ medido — dispara, prova positiva |
| 9 · qual shell roda o `command` | ✅ medido — **`/usr/bin/bash` 5.2.37**, não PowerShell como a doc diz |
| 10 · saída de hook que sai 0 | ✅ medido — **invisível**, stderr e stdout. Move o anúncio da Task 3 para a Task 7 |
| 11 · `command` malformado | ✅ medido — bloqueia a ferramenta; auto-lockout observado e desfeito pela outra tool |

**Ramo da Task 6 decidido pela medição:** coexistência é definida (os dois rodam; qualquer `exit 2`
bloqueia) e há sintaxe de caminho confiável. Pela regra fixada antes de medir, **o registro vai para o
`settings.json`** — com caminho absoluto escrito pelo instalador, e com a ordem por risco (8 guardas,
publicação, 3 observadores) porque o enforcement duplo foi confirmado real.
