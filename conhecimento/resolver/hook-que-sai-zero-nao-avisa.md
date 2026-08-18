## Hook que sai 0 não consegue avisar ninguém: stderr e stdout são invisíveis no caminho de sucesso {#hook-que-sai-zero-nao-avisa}

`tags: hook, PreToolUse, exit 0, stderr, stdout, invisivel, aviso que ninguem le, SessionStart, health check, Claude Code, settings.json, canal visivel, bash, auto-lockout`

**Origem:** percus-kit, 2026-07-31 — medido com sondas, ao desenhar um fallback "barulhento" que
teria sido barulho no vácuo.

Duas sondas registradas no mesmo evento `PreToolUse`, uma escrevendo em **stderr** e outra em
**stdout**, ambas saindo **0**. A chamada seguinte rodou normal e **nenhuma das duas apareceu** — nem
na saída da ferramenta, nem como aviso. Só a terceira sonda, que escrevia num arquivo, deixou rastro.

| Caminho | A saída aparece? |
|---|---|
| hook `PreToolUse` que sai **0** | **não** — nem stderr, nem stdout |
| hook `PreToolUse` que sai **2** | sim (é como um BLOCK se mostra) |
| hook `SessionStart` que sai 0, escrevendo em **stdout** | sim (é como um gate de início se mostra) |
| hook `SessionStart` que sai 0, escrevendo em **stderr** | **não** — ver [#sessionstart-stderr-nunca-aparece] |

- **A regra:** aviso no caminho de sucesso **não existe**. Se um hook precisa dizer algo sem
  bloquear, o lugar é `SessionStart` (ou um arquivo que alguém leia depois), nunca uma escrita antes
  de um `exit 0`.
- **Como isso vira bug:** você escreve o aviso, confere lendo o código, conclui que "avisa", e o
  usuário nunca vê. Pior que não avisar — porque você para de procurar outro canal.
- **Como confirmar em 2 min:** registre duas sondas triviais (uma em stderr, outra em stdout, ambas
  `exit 0`) no `settings.json` do projeto e dispare uma ferramenta. Mudança em `settings.json` de
  projeto vale na hora, sem reiniciar a sessão.
- **Atenção:** o shell que executa o `command` de um hook (nesta máquina) é **`/usr/bin/bash`**, não
  PowerShell nem cmd — a doc oficial diz PowerShell no Windows e não foi o observado. Sonda em
  sintaxe errada devolve erro de sintaxe do bash, e `command` malformado sai não-zero, o que em
  `PreToolUse` **bloqueia a ferramenta inteira** (auto-lockout observado; a saída é por uma tool que
  o matcher não cubra).

**Relacionado:** [#plugin-cache-nao-recebe-fix] — o mesmo desenho de "parece que está ligado e não
está", uma camada abaixo.
