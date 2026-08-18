## Task dada como "fechada" com prova que só cobria metade do canal: hook fala por stderr num `SessionStart` que sai 0, e nunca aparece {#sessionstart-stderr-nunca-aparece}

`tags: SessionStart, hook, stderr, stdout, exit 0, health check, canario observacional, hook_success, transcript jsonl, Claude Code, prova incompleta, assinatura em stderr`

**Origem:** percus-kit, 2026-07-31 — canário observacional de um health check que tinha sido dado
como fechado numa sessão anterior.

Um health check em `SessionStart` (sempre `exit 0`, por contrato — nunca pode travar a sessão) tinha
sido validado com a prova "`SessionStart` produz saída visível", baseada num hook `echo` de exemplo
que falava por **stdout**. O health check em si falava por **stderr**, seguindo a convenção de
assinatura-em-stderr usada pelas guardas (`PreToolUse` que sai 2 mostra stderr — faz sentido lá). Na
sessão seguinte o banner esperado não apareceu. A tentação é reabrir o restart e torcer; em vez disso,
o `.jsonl` da própria sessão foi lido direto (`~/.claude/projects/<projeto>/<session_id>.jsonl` ou o
equivalente sob `CLAUDE_CONFIG_DIR`), procurando os registros `"type":"hook_success"` com
`"hookEvent":"SessionStart"`.

- **O que os registros brutos mostram, campo a campo:** cada `hook_success` tem `stdout`, `stderr`,
  `content` e `exitCode` **separados**. Comparando os 3 hooks que rodaram na mesma abertura: os 2 que
  escreviam em `stdout` tinham `content` populado (e apareceram); o que escrevia em `stderr` saiu 0,
  com a mensagem certa gravada no campo `stderr` do registro — e `content` vazio. `content` vazio é o
  que decide se aparece pra quem lê a sessão; não é o `exitCode`.
- **Por que a prova original não pegou isso:** ela testava "o evento dispara e o texto aparece" com
  UM exemplo (stdout). Generalizar de "stdout aparece" pra "SessionStart aparece" pulou a variável que
  importava. A mesma classe do item já registrado em [#hook-que-sai-zero-nao-avisa] (stderr é
  invisível em sucesso) — só que ali a medição parou em `PreToolUse` e a suposição vazou pra
  `SessionStart` sem reteste.
- **Como confirmar em 2 min, sem esperar reabrir nada:** rode o hook manualmente com stdout/stderr
  redirecionados pra arquivos separados (`comando 1>out.txt 2>err.txt`); se a mensagem cai em
  `err.txt`, ela não vai aparecer em `SessionStart` mesmo saindo 0. Ou leia o `.jsonl` da sessão atual
  e confira o campo `content` do `hook_success`, não só se o processo rodou.
- **Conserto:** hooks observadores de `SessionStart` (contrato: sempre exit 0, nunca bloqueiam) devem
  falar por stdout. A convenção de assinatura-em-stderr fica só pras guardas (`PreToolUse`/exit 2),
  onde o canal é comprovadamente visível.

**Relacionado:** [#hook-que-sai-zero-nao-avisa] — mesma família, um nível mais fundo: nem todo canal
"visível" é visível igual.
