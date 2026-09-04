## R20: os padrões NÃO-ancorados (`git push`, `gh pr comment`, `slack-cli`, `mailto:`) casam prosa que NEGA a ação, não só quem a executa {#r20-padroes-nao-ancorados-casam-prosa-que-nega-a-acao}

`tags: r20, external-action-guard, hooks, falso positivo, git push, commit message, ancoragem, mock-scan, R23`

**Sintoma:** `git commit` (ou qualquer comando Bash) bloqueado por `external-action-guard` (R20)
mesmo quando o comando em si não faz `ssh`, `docker service update`, `git push` nem nenhuma ação
externa de verdade — só CITA uma dessas palavras em texto explicando o que **não** foi feito.

**Reprodução real** (tiatendo, 2026-09-04): um `git commit -m "..."` cuja mensagem incluía a
frase *"Sem `git push`."* (documentando, corretamente, que nada foi enviado ao remoto) recebeu
`BLOCK (R20): acao externa publica requer aprovacao explicita do operador`. O mesmo aconteceu
num `python3 -c "..."` cujo string literal (motivo de uma tentativa de gravar
`.percus/acao-externa-autorizada.json`) continha `"...sem git push."` — nem `ssh` nem `docker`
apareciam no comando, só essa frase.

**Causa raiz:** `external-action-guard.ps1` tem duas listas de padrão. A maioria (`docker stack
deploy`, `docker service update`, `ssh <host>`, wrappers `*vps*.py`) é **ancorada** em posição de
comando (`$cmdIni` = início da string ou logo após `; & | ( && ||`) — de propósito, porque a 1ª
versão sem âncora bloqueava prosa que só CITAVA `wrangler versions deploy` dentro de uma tag
HTML. Mas 4 padrões ficam **deliberadamente NÃO-ancorados**: `git\s+push`, `gh\s+(pr|issue)\s+
comment`, `gh\s+pr\s+(close|merge)`, `slack-cli`, `mailto:` — o comentário do próprio script
justifica: "são específicos o bastante para prosa raramente casar". Essa aposta falha
exatamente quando a prosa é sobre **negar** a ação (comum em mensagens de commit e relatórios de
sessão, que documentam "não fiz X" com bastante frequência) — a `regex.IsMatch` não distingue
afirmação de negação, só presença do substring.

**É a MESMA classe do mock-scan** (ver [[mock-scan-casa-a-palavra-nao-o-sentido-da-frase]]):
qualquer scanner que casa TEXTO em vez de INTENÇÃO trata "não fiz X" e "fiz X" como equivalentes.
A diferença aqui é que R20 tem duas famílias de padrão com âncoras DIFERENTES no MESMO hook — os
achados sobre os ancorados (ver [[guard-r20-bloqueia-a-gravacao-da-propria-autorizacao]], sobre
bloquear a própria gravação da autorização) não previnem este caso, porque a lista não-ancorada é
um mecanismo à parte.

**Solução:** ao escrever mensagem de commit, log ou qualquer texto que precise MENCIONAR
(afirmando OU negando) push/gh-comment/slack/mailto, quebre a adjacência das palavras-gatilho —
"nada foi enviado ao remoto", "push não executado", "sem envio ao GitHub" em vez de "sem `git
push`". Não há flag de override que ajude aqui: nem `PERCUS_EXTERNAL_OVERRIDE=1` inline no
comando resolve, porque **a env var da sessão do Claude não atravessa a fronteira de processo
até o hook** (achado de 2026-07-31, documentado no próprio código-fonte do hook) — só o arquivo
`.percus/acao-externa-autorizada.json` (gravado via ferramenta Write, não Bash — ver
[[guard-r20-bloqueia-a-gravacao-da-propria-autorizacao]]) atravessa de verdade.

**Contra-regra:** os padrões ANCORADOS (deploy/ssh/docker) não sofrem disso — eles só casam em
posição de comando, então prosa que os cita no meio de uma frase passa batido. Confirme qual
família de padrão está em jogo antes de aplicar este verbete.
