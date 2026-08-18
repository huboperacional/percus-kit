## n8n `jsonBody` sem `specifyBody: "json"` manda o corpo VAZIO — o PATCH "responde 200" e não aplica nada {#n8n-jsonbody-sem-specifybody-corpo-vazio}

`tags: n8n, httpRequest node, jsonBody, specifyBody, sendBody, PATCH, POST, corpo vazio, falha silenciosa, 200 sem efeito, bodyParameters, keypair, contentType, webhook, tag nao aplicada`

**Sintoma:** um node HTTP Request (`n8n-nodes-base.httpRequest`, `sendBody: true` +
`"jsonBody": "={{ {...} }}"`) devolve HTTP 200/sucesso, mas o efeito esperado no destino (tag
aplicada, campo atualizado, status mudado) simplesmente não acontece — nenhum erro, nenhum log,
nada. Parece bug do serviço remoto ou "atraso de indexação", mas não é.

**Causa raiz:** o node HTTP Request v4.x tem DOIS mecanismos concorrentes de corpo:
`bodyParameters` (modo `keypair`, formulário) e `jsonBody` (modo `json`). Qual dos dois é
efetivamente ENVIADO depende de um campo separado, `specifyBody`, que **default pra `"keypair"`**
mesmo quando `contentType` é `"json"`. Se `specifyBody` não estiver setado explicitamente como
`"json"` no JSON do node, o n8n manda o `bodyParameters` (frequentemente `{parameters: []}`, vazio)
em vez do `jsonBody` que você escreveu — a requisição sai com corpo vazio, o servidor remoto aceita
(muitas APIs tratam PATCH sem corpo como no-op bem-sucedido) e devolve 200, mascarando o problema
por completo. Confirmado consultando o schema REAL do node (`POST /rest/node-types` no n8n, não
documentação/suposição): `specifyBody` só aparece com `displayOptions.show: {sendBody:[true],
contentType:['json']}`, e seu `default` é `"keypair"`.

**Solução:** todo node com `sendBody: true` e `jsonBody` presente TEM que ter também
`"contentType": "json"` e `"specifyBody": "json"` explícitos no JSON — nunca confiar no default.
Escrever um lint/teste que bloqueia deploy se `jsonBody` existir sem `specifyBody: "json"` no mesmo
node (barato, mecânico, pega a classe inteira de uma vez).

**Como confirmar ao vivo, sem adivinhar:** `POST {n8n}/rest/node-types` com
`{"nodeInfos":[{"name":"n8n-nodes-base.httpRequest","version":<a do node>}]}` (autenticado com a
mesma sessão do editor) devolve o schema completo do node, incluindo `displayOptions`/`default` de
cada campo — mais confiável que testar por tentativa e erro contra o servidor remoto.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-11/12. Achado no PATCH que "aperta o play" do Salesbot
(`02-dispatch-worker.json`) — se não achado, o sistema pareceria funcionar (fila enche, sem erro)
mas nunca dispararia mensagem nenhuma, em silêncio, pra sempre. Lint `lint_json_body_needs_specify_body`
em `execution/deploy_workflows_n8n.py`.
