## O guard de ação externa casa o TEXTO do motivo, não a ação — o comando que GRAVA a autorização é bloqueado por descrevê-la {#guard-de-acao-externa-casa-o-motivo-nao-a-acao}

`tags: hook, external-action-guard, R20, matcher, autorizacao, git push, PreToolUse, texto do comando, Write, R23`

**Sintoma:** a autorização R20 já foi dada pelo operador; o agente monta o comando que
grava `.percus/acao-externa-autorizada.json` — e o próprio hook `external-action-guard`
o bloqueia. Quanto mais honesto o campo `motivo` (ex.: citar "git push" por extenso),
mais provável o bloqueio. O agente conclui "a autorização não funciona" quando o que
falhou foi o REGISTRO dela.

**Causa raiz:** o guard é PreToolUse de Bash e casa o TEXTO da linha de comando, não a
semântica. Um heredoc/echo que escreve um JSON contendo a string `git push` é, para o
matcher, indistinguível de um `git push` — a descrição da ação dispara o gatilho da
ação. É a mesma família de `hook-le-o-texto-do-comando-nao-o-shell` (o `$VAR` no `cd`
que engana o matcher) e de `texto-sobre-a-regra-quebra-a-guarda` (comentário que
EXPLICA o conserto é indistinguível do defeito): matcher textual não separa uso de
menção.

**Correção (medida em Empresa Milionária, 2026-08-30, sessão -d1):**
1. Gravar o JSON de autorização pela ferramenta **Write** — ela não passa pelo hook de
   Bash, e o conteúdo é dado, não comando.
2. O timestamp que o JSON precisa vem ANTES, de um comando inócuo (`date`), nunca do
   mesmo comando que grava.
3. Só então executar a ação externa em chamada própria — o guard lê o ARQUIVO e libera.

**Como reconhecer:** o bloqueio cita a ação externa, mas o comando bloqueado não a
executa — só a DESCREVE (num campo de texto, num JSON, num log). Se remover a string
do motivo destrava, é isto.

**O que NÃO fazer:** "suavizar" o motivo para enganar o matcher — o motivo honesto é o
que audita a autorização depois; mude o CANAL (Write), não a verdade do texto. E não
concluir que a autorização do operador "não vale": o que falhou é mecânico e tem
caminho declarado.

**Relacionado:** hook-le-o-texto-do-comando-nao-o-shell ·
texto-sobre-a-regra-quebra-a-guarda · autorizacao-externa-em-comando-separado (o
princípio que este verbete operacionaliza sem tropeçar no próprio guard).
