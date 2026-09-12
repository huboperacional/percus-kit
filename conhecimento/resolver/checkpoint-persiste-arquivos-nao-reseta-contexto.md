## Checkpoint persiste arquivos — não reseta contexto; sessão de 610k morreu com "Prompt is too long" {#checkpoint-persiste-arquivos-nao-reseta-contexto}

`tags: checkpoint, contexto, compactacao, compaction failed, Prompt is too long, resume, retomar, 610k, context-budget-guard, HANDOFF, PLANO, custo fixo de boot, R23`

**Sintoma:** ao retomar uma sessão (`retomar`, `--resume`), logo após um `Read` inocente aparece
`Prompt is too long · automatic compaction failed: API Error: Server is temporarily limiting requests
(...) All credentials for model claude-opus-5 are cooling down`. A primeira leitura é "o arquivo
lido é grande demais" — e a investigação sai atrás do `HANDOFF.md`/`PLANO.md` inchado.

**O que a medição mostrou (transcript de Empresa-Milionaria, 2026-09-09 → 09-12):** o arquivo lido
tinha 149 linhas (~4k tokens) e estava dentro do teto. O `usage` da própria API contava outra história:

| Momento | Contexto |
|---|---|
| início da sessão | 69k |
| ~3h depois | 235k |
| ~14h e 337 tool calls depois | **610k** (modelo 1M, zero reset) |
| resume 2 dias depois: resumo de compactação de **4k** | 1ª chamada pós-resumo: **188k** |
| compactação seguinte | rate-limit → "Prompt is too long" |

A palavra "checkpoint" aparece **11 vezes** nessa sessão. Os arquivos ficaram em dia; o contexto
nunca baixou. **Checkpoint escreve arquivo; só o reset (sessão nova) salva contexto.** A skill se
vendia como "caminho PRIMÁRIO de gestão de contexto" — era persistência sendo usada como se fosse
gestão de memória viva.

**Segundo achado, o custo fixo:** a 1ª chamada de toda sessão nova custa 65-73k tokens em todos os
projetos (system prompt + ~110 definições de tool MCP + hooks + skills). Após compactação, o
resumo tinha 4k e o prompt marcava 188k — o resto é overhead que nenhum arquivo do projeto explica.
Numa janela de 200k isso é ⅓ gasto antes da primeira palavra.

**Armadilha de diagnóstico, paga nesta investigação:** medi tamanho de HANDOFF/PLANO na frota,
achei PLANOs de 6-11 mil linhas (~150-260k tokens) e concluí que era a causa. Era um problema
**real e separado** (tratado noutro plano), mas **não a causa deste incidente** — o transcript
provou que o PLANO nem foi lido na sessão. Antes de culpar um arquivo, leia o `usage` no
transcript (`.claude-home/projects/<projeto>/<sessao>.jsonl`): ele diz o contexto exato a cada
chamada. Dois problemas tratados como um produzem a solução errada para os dois.

**Correção (6.45.0):** hook `context-budget-guard` (PostToolUse em **todas** as tools, observador)
lê a última `usage` da cauda do transcript e avisa agente + operador acima de 150k/180k tokens,
8h de parede ou transcript retomado com 2+ dias — uma vez por nível por sessão. A skill
`checkpoint` ganhou o passo **5. Reset**: quando o hook avisou, o checkpoint termina em sessão nova
com o bloco de retomada, não no commit. O loop `v2/loops/checkpoint.md` dizia "não gere texto pra
colar" enquanto a skill mandava gerar — resolvido a favor do bloco (≤15 linhas, ponteiro + próximo
passo): é exatamente o que salva um resume que ficou impossível.

**Discriminante:** o contexto vivo é um número que o harness já grava a cada chamada. Se a regra
para controlá-lo depende de alguém *lembrar* de fazer checkpoint, ela já falhou (CONSTITUIÇÃO §6) —
o hook mede; a skill diz o que fazer com a medida. O matcher é vazio de propósito: contexto cresce
com Edit/Write/Read tanto quanto com Bash, e guarda que só enxerga shell é a classe de furo que já
reincidiu neste kit (14 verbetes invisíveis em 2026-08-18 por hook que só cobria Bash). Ver
[[plano-append-only-mente-e-o-canon-elege-ele-juiz]] para o problema irmão (PLANO sem teto), que é
outro.
