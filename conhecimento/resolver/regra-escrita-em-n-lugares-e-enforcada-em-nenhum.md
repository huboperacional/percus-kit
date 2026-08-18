## Regra escrita em N lugares e enforçada em nenhum: enforcement ENUMERA tools, então toda tool nova nasce fora da guarda {#regra-escrita-em-n-lugares-e-enforcada-em-nenhum}

`tags: enforcement, hook, matcher, PreToolUse, Edit, Write, ponto cego, regra documentada sem gate, assimetria de gate, caminho de menor resistencia, R23, tool nova nasce fora, guarda de caminho, guarda de comando`

**Sintoma:** uma regra está escrita com todas as letras em vários lugares — no documento de regras,
na skill que o agente invoca, no LEIA-ME da pasta — e **é violada de forma sistemática**, por
sessões diferentes, durante semanas. Ninguém está desobedecendo de propósito; e quando você vai
somar, descobre que **nenhum gate consegue ver a violação**.

**Causa raiz — e ela é estrutural, não de disciplina.** Guarda de `PreToolUse` se registra por
`matcher`, e matcher **enumera tools**. Toda guarda escrita quando existiam N tools cobre aquelas N.
A tool N+1 nasce **fora** de todas elas, e nada avisa: não há erro, não há teste vermelho, não há
log. A regra continua verdadeira no papel e indefensável na prática.

**O caso (percus-kit, 2026-08-18):** R23 diz *"não edite o monólito direto"* em três lugares. Os 12
hooks registrados casavam `Bash|PowerShell` ou `ExitPlanMode` — **nenhum** casava `Edit`/`Write`.
Uma sessão que abrisse `COMO_RESOLVER.md` com a tool Edit passava por zero guardas. Resultado
medido: **14 verbetes** entraram por ali sem âncora `{#slug}`, sem linha `tags:` e fora do Índice, e
**11 estavam commitados havia semanas**.

🔑 **É reincidência da mesma classe, não um caso novo.** Em 2026-07-31 o mesmo kit consertou
*"matcher era só `Bash` e a tool PowerShell passava livre"*, estendendo para `Bash|PowerShell`.
`Edit`/`Write` nunca entraram. **O ponto cego mudou de andar; não sumiu.** Quem conserta um matcher
por incidente conserta o andar, não o prédio.

⚠️ **A assimetria é o que DIRIGE a sessão pro caminho errado, e ela é invisível de dentro.** No caso,
o gate cobrava 8 invariantes de quem escrevia no caminho **certo** (a caixa: um verbete por arquivo,
slug == nome do arquivo, `tags:` presente, fence fechado…) e **nada** de quem escrevia no caminho
**proibido**. Quem obedecia podia ser rejeitado; quem desobedecia, nunca. **Gate que só cobra de
quem já está certo não é enforcement — é imposto sobre a disciplina**, e o caminho proibido vira o
de menor resistência.

**Solução:**
1. **Trate "a regra está documentada" como zero evidência de enforcement.** A pergunta é *"qual gate
   falha se eu violar isto agora?"* — e a resposta tem de ser um arquivo executável, não um
   parágrafo. Três lugares dizendo a mesma coisa é um sinal de alerta, não de robustez: se
   precisou repetir três vezes, é porque não há gate.
2. **Ao somar uma guarda, pergunte qual conjunto ela enumera e o que está FORA.** Liste as tools que
   o harness expõe e case contra os matchers registrados. O que sobrar é o ponto cego, e ele é
   descobrível em minutos.
3. **Barre na ESCRITA, não só no commit.** Gate de commit barra quando o texto já está no arquivo
   errado, possivelmente misturado com trabalho de outra sessão. Guarda de `PreToolUse` barra na
   decisão.
4. **A mensagem tem de ENSINAR o caminho certo, não só recusar.** Guarda que só diz "não" ensina a
   contornar. Diga para onde ir, com o caminho exato, e por que a regra existe.
5. **Escreva junto o teste de que a guarda NÃO barra o legítimo.** No caso: `## Índice` e subtítulos
   `###` não podem barrar, e a caixa tem de seguir livre. Guarda que ninguém consegue satisfazer é
   desligada no primeiro aperto — e aí não guarda mais nada.

⚠️ **Fronteira derivada por exclusão apodrece.** O teste que exigia matcher `Bash|PowerShell` de toda
guarda definia o conjunto como *"PreToolUse que não é `ExitPlanMode`"*. Funcionou enquanto "guarda de
PreToolUse" era sinônimo de "guarda de comando" — e **proibiria por construção** a primeira guarda de
CAMINHO (que lê `tool_input.file_path`). O conserto não é somar a segunda exceção: é declarar o
critério que faltava (campo `alvo`: `comando` | `caminho` | `plano`). **Lista de exceção que cresce é
cheiro de critério ausente.**

**Ref:** percus-kit 6.37.0, 2026-08-18. `knowledge-write-guard` (`PreToolUse`, `Edit|Write`) + bloco
2b do `percus-gate.sh`. Suíte 385 → 400. Ver `#health-check-versao-vence-autoupdate` (matcher novo é
mudança de REGISTRO e exige publicação; código de hook vem do kit por `git pull`) e
`#hooks-percus-so-cobrem-tool-bash` (o mesmo ponto cego, um andar abaixo, em 2026-07-31).
