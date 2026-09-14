## Máscara de segredo por regex vira caça a separador, abre ReDoS a cada correção — e truncar ANTES de mascarar vaza senha de URL {#mascara-de-segredo-por-regex-vira-caca-a-separador}

`tags: segredo, redact, mascara, regex, redos, backtracking, truncar, url, credencial, log, str(exc), review duplo, R23`

**Sintoma:** para gravar a causa real de um erro (`str(exc)`) num log ou tabela que humanos leem, alguém escreve uma
função de máscara com regex (`access_token=***`). Cada review acha um jeito novo de o segredo escapar, cada correção
fecha aquele caso, e a rodada seguinte mede **ReDoS**: a função que roda em todo erro passa a levar segundos.

**Reprodução real** (paid-media, worker, 2026-09-14 — 4 rodadas de review duplo): o SDK da Meta põe `access_token` e
`appsecret_proof` na URL da mensagem de `ConnectionError`. A máscara passou por, nesta ordem: `&` (ok) → `;` escapava
(`code=X;access_token=S`) → JSON e repr de dict escapavam (`{"access_token": "S"}`) → quantificador aninhado
`(?:[A-Za-z0-9]+[_\-])*` levou **18 s em 100 kB** (O(n²)) → corrigido, e `"a-"*n` ainda dava 0,5 s → `redis://:senha@host`
(usuário vazio, formato do `REDIS_URL` de produção) e `api_key_v2=S` escapavam.

**O que encerrou a classe** (não o caso):
1. **Nome da chave como sequência inteira** (`[A-Za-z0-9_-]+`) + lookahead do termo-gatilho — toda repetição ilimitada
   é seguida de um caractere que não pode continuá-la, então não há ponto de reinício: linear por construção, e o
   comentário diz por quê.
2. **Teto de entrada** (8.000 caracteres) — defesa em profundidade, não a correção.
3. **Bateria adversarial parametrizada permanente** no teste: fragmentos (`a`, `a.`, `a-`, `a_`, `://`, `://:`, `@`,
   `%3D`, `access-token`, `Bearer `…) e misturas com seed fixa, no teto e a 10×, exigindo < 50 ms e crescimento linear.
   Achado novo vira **fragmento novo**, nunca caso especial.

⚠️ **Armadilha do teto:** "cortar antes de mascarar é seguro porque o valor vem depois do nome" vale para `nome=valor` e
**é falso para credencial de URL** — em `scheme://user:senha@host` o delimitador `@` vem **depois** da senha; o corte no
meio deixa a senha sem o `@` que a regra usa para achá-la. Teste varrendo a posição do corte em volta do segredo.

**Antes de concluir "vazou/não vazou" no histórico:** meça no banco por COUNT e hash, nunca selecionando o texto — no caso
real, 0 ocorrências, mas 46 notificações já traziam a URL da Graph API (o vetor existia).
