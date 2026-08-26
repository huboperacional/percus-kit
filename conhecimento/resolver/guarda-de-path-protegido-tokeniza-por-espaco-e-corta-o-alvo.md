## Guarda de "system path protegido" tokeniza por espaço e bloqueia por um FRAGMENTO do comando, não o alvo real {#guarda-de-path-protegido-tokeniza-por-espaco-e-corta-o-alvo}

`tags: hook, PreToolUse, Remove-Item, system path, path protegido, falso positivo, tokenizacao, aspas, espaco no caminho, heredoc, PowerShell, matcher, bloqueio inesperado, R20`

**Origem:** Micro Investors, 2026-08-26 — dois incidentes no mesmo dia, mesma classe de causa,
sintomas diferentes o bastante pra não reconhecer de cara.

**Sintoma 1 (path com espaço quebra em tokens):** um comando `pwsh` legítimo terminando em
`Remove-Item -LiteralPath $Q -Force -ErrorAction SilentlyContinue`, onde `$Q` apontava pra um
arquivo dentro de `d:\Claud Automations\Micro Investors\...` (caminho com espaço, entre aspas),
foi bloqueado com:

```
Remove-Item on system path '"d:\Claud' is blocked. This path is protected from removal.
```

O "path" citado no bloqueio (`"d:\Claud`) não é um caminho de verdade — é o PRIMEIRO TOKEN do
comando inteiro, cortado no primeiro espaço, com a aspa de abertura ainda grudada. A guarda não
tokenizou respeitando aspas; splitou por whitespace cru, pegou o pedaço `"d:\Claud` (de
`"d:\Claud Automations\...\council-q-...txt"`), casou contra um padrão de "raiz de disco" e
concluiu que o comando tentava remover `d:\` inteiro.

**Sintoma 2 (conteúdo de heredoc interpretado como alvo do comando seguinte):** um segundo comando
`pwsh`, com um here-string (`@'...'@`) contendo o texto `/offer-dispatches/{id}/resume` como PROSA
de uma pergunta de conselho, seguido de um `Remove-Item -LiteralPath $Q` real seis linhas depois,
foi bloqueado com:

```
Remove-Item on system path '/offer-dispatches/' is blocked. This path is protected from removal.
```

De novo: `/offer-dispatches/` nunca foi argumento de `Remove-Item` — era texto dentro do
here-string, um parágrafo antes. A guarda varreu o comando inteiro (não só a chamada de
`Remove-Item`), achou uma substring com cara de path absoluto em QUALQUER lugar do texto, e
atribuiu ela ao `Remove-Item` que aparecia depois.

**Causa raiz (comum aos dois):** a guarda que protege paths de sistema contra `Remove-Item` não
isola o **argumento real** da chamada — ela faz pattern-matching sobre a **string bruta do comando
inteiro** (heredocs, aspas e tudo), igual ao bug já catalogado em
[#guarda-casa-a-mensagem-nao-a-acao] pro `external-action-guard`, mas aqui o alvo é outro guard (o
que protege "system path") e o modo de falha é diferente: em vez de "menção vira uso" (aquele
verbete), aqui é "o PRIMEIRO substring com cara de path no comando inteiro vira o alvo do
`Remove-Item`", mesmo que esteja em outro trecho do comando ou cortado pela tokenização ingênua.

**Contorno que funcionou nos dois casos:** separar em **duas chamadas de tool** — uma só pra
escrever/preparar (sem `Remove-Item` nenhum na mesma invocação), outra só pro cleanup, cada uma
como comando `pwsh`/Bash isolado e curto, sem heredoc de prosa longa compartilhando a mesma
invocação com o `Remove-Item`. Nenhum path mudou; só a forma de disparar. Confirmar que nada rodou
antes de reexecutar (`ls` do temp / `.deepseek/council-log/`) — na 1ª vez a guarda bloqueou o
comando **inteiro antes de qualquer linha rodar** (nem o `Set-Content` nem o orchestrator
executaram).

**Como reconhecer rápido:** o "path" citado no erro do bloqueio **não bate com nenhum argumento
real do `Remove-Item` no comando** — está truncado num espaço/aspa, ou é um substring de um bloco
de texto/heredoc em outro lugar do comando. Se isso acontecer, não adianta trocar o path por outro
igualmente válido — o problema é a FORMA do comando (heredoc + ação real no mesmo call), não o
valor do path.

**Relacionado:** [Guarda de ação externa barra o COMMIT porque a MENSAGEM cita a ação](guarda-casa-a-mensagem-nao-a-acao.md)
— mesma classe de causa-raiz (matcher sobre string bruta, não sobre argumento isolado), guard e
modo de falha diferentes.
