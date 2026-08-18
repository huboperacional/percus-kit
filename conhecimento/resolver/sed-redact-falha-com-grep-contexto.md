## `sed` de redação de segredo falha quando a entrada vem de `grep -B`/`-A` (prefixo de número de linha quebra o padrão) {#sed-redact-falha-com-grep-contexto}

`tags: bash, sed, redact, segredo, api key, grep contexto, vazamento, tool output, secret exposure`

**Contexto:** sessão Scraper-prospeccao 2026-08-03, tentando localizar um comentário acima de uma
env var sem expor o VALOR da var no output da ferramenta.

**Sintoma:** `grep -n -B3 "^GOOGLE_PLACES_API_KEY=" .env | sed -E 's/=.+/=<redacted>/'` — o `sed`
não redigiu a linha do match; o valor real da API key saiu em texto puro no resultado da
ferramenta (e portanto no histórico/log da sessão). O padrão `s/=.+/=<redacted>/` parecia correto
isolado, mas `grep -n -B3` prefixa a linha de match com `N:` e as linhas de contexto com `N-` — a
linha real (`33:GOOGLE_PLACES_API_KEY=AIzaSy...`) não batia com um padrão testado só contra a
string SEM esse prefixo, e passou inalterada.

**Causa raiz:** testar um padrão de redação contra uma string sintética (sem o prefixo que
`grep -n` com contexto sempre adiciona) e assumir que generaliza. Qualquer regex de redação
ancorada em `^` quebra silenciosamente quando a entrada vem de `grep` com `-A`/`-B`/`-C`.

**Solução:** nunca usar `sed`/regex ancorado em `^` pra redigir segredo vindo de `grep` com
contexto. Alternativas seguras: (1) `grep -c` ou `cut -d'=' -f1` pra confirmar só a
EXISTÊNCIA/nome da variável, nunca o valor; (2) extrair o valor pra uma variável de shell DENTRO
do mesmo processo (nunca via `echo`/print) e usá-lo só em redirecionamento de arquivo (`>>`),
nunca em stdout que vira output de ferramenta; (3) validar formato/conteúdo (é JSON válido? tem o
campo esperado?) rodando um script que imprime só um veredito booleano, nunca o dado em si. Se o
vazamento já aconteceu: risco baixo quando a chave já é restrita (IP allowlist, escopo de API) —
mas considerar rotação por precaução, e nunca repetir o mesmo comando "pra confirmar".

**Ref:** sessão Scraper-prospeccao 2026-08-03, checkpoint de configuração de
`GOOGLE_PLACES_ACCOUNTS` (conta `moacir`).
