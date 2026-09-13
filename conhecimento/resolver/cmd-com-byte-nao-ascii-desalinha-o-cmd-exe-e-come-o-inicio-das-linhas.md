## Um emoji num `.cmd` come o início das linhas e derruba o hook inteiro — e o Git Bash diz que está tudo bem {#cmd-com-byte-nao-ascii-desalinha-o-cmd-exe-e-come-o-inicio-das-linhas}

`tags: cmd.exe, batch, .cmd, hook, wrapper, encoding, UTF-8, codepage, OEM, emoji, nao-ASCII, exit 255, dispatcher, PostToolUse, offset de byte, teste manual mente, Git Bash, ps51`

**Sintoma:** o wrapper `.cmd` de um hook sai com **exit 255** e o stderr vem cheio de linhas do
tipo *"'ocal' não é reconhecido como um comando interno ou externo"*, *"'Dispatcher' não é
reconhecido"*, *"'Read' não é reconhecido"*. As palavras citadas **existem no arquivo**, mas sempre
faltando os primeiros caracteres: `setlocal` aparece como `ocal`, `REM Dispatcher` como
`Dispatcher`, `REM Read/Edit` como `Read`.

**A causa, medida em 2026-09-13:** o `cmd.exe` lê arquivo de lote por **deslocamento de byte** e
reposiciona a cada comando executado. Um caractere multi-byte faz o contador de **bytes** divergir
do de **caracteres**, e a partir dali ele reposiciona no lugar errado — o início das linhas some.

A aritmética bate exatamente:

| | |
|---|---|
| `⚠️` = U+26A0 + U+FE0F | **6 bytes**, **2 caracteres** |
| diferença | **4** |
| caracteres comidos do início de cada linha | **4** |

No caso medido, um único `⚠️` num comentário `REM` do `percus-dispatch-post.cmd` — o **único** byte
não-ASCII entre os 17 `.cmd` do kit — fazia o dispatcher `PostToolUse` sair **255 em toda tool
call**. Removido o emoji: exit 0, stderr limpo. Nada mais mudou.

**O que torna isto traiçoeiro: o teste manual diz que está bom.**

Sob codepage **UTF-8 (65001)** — que é a do Git Bash — byte e caractere coincidem e **não há
deriva**. O defeito só aparece na **codepage OEM**, que é a que o Claude Code usa de verdade no
Windows PT-BR. Foi exatamente isso que aconteceu: rodar `cmd //c script.cmd` pelo Git Bash deu
`exit 0`, e a suíte Pester (que invoca via `Start-Process $env:ComSpec`) deu 14 vermelhas. O
terminal errado **certifica** um arquivo quebrado.

> Um detalhe que atrasou o diagnóstico: a primeira hipótese foi **CRLF** (`.cmd` com LF quebra o
> `cmd.exe`, e é defeito real). Foi medida e **descartada** — 187 de 187 linhas com CR. A segunda
> foi **BOM**, também descartada (`@ec` nos três primeiros bytes). Só a terceira era a certa. Vale
> gastar os dois minutos das duas primeiras: as três têm sintoma parecido e causa diferente.

**Por que engana:** o arquivo **abre perfeitamente** em qualquer editor, passa em revisão humana, e
o caractere problemático costuma estar num **comentário** — o último lugar onde se procura a causa
de um erro de execução. E o erro reportado cita palavras que existem no arquivo, o que sugere
corrupção aleatória em vez de deslocamento sistemático.

**Como aplicar:**

1. **`.cmd` é ASCII puro. Não é estilo, é requisito de execução.** Nada de emoji, `—`, `→`, aspas
   tipográficas ou acento — nem em comentário. Para destaque use `ATENCAO:`, `!!`, `***`.
2. Medir, em vez de olhar:
   ```bash
   for f in *.cmd; do printf "%-34s %s\n" "$f" "$(LC_ALL=C grep -c $'[\x80-\xff]' "$f" || echo 0)"; done
   ```
3. **Não valide `.cmd` pelo Git Bash.** Ele roda em UTF-8 e esconde a classe inteira. Valide como o
   chamador real invoca: `cmd.exe /c "<caminho absoluto>"`, com stdin redirecionado.
4. **A guarda tem que rodar o arquivo, não só varrê-lo.** A varredura estática de byte é barata e
   pega a causa; o teste comportamental é o que prova. Em
   `plugin/percus-review/tests/cmd-ascii-puro.tests.ps1` existem os dois, e o segundo executa os
   dispatchers pelo caminho de produção com `PERCUS_HOOKS_DISABLED=1` (exercita o *parse* do lote
   sem efeito colateral).
5. Classe irmã, causa diferente — não confunda:
   - `.ps1` **sem BOM** não *parseia* no PowerShell 5.1 → guarda: `ps51-compat.tests.ps1`.
   - `.md`/`.json` lido **sem `-Encoding UTF8`** chega em mojibake no 5.1 → guarda:
     `hooks-leitura-utf8.tests.ps1`.
   - `.cmd` com **byte não-ASCII** desalinha o `cmd.exe` → esta aqui.

**Relacionado:** [[revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida]] (mesma
sessão, outra família), e a lição de que ambiente de teste diferente do de produção produz verde
falso.
