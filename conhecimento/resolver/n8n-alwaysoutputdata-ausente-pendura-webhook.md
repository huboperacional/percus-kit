## n8n: 0 linhas num node Postgres sem `alwaysOutputData` pula o `IF` seguinte inteiro — webhook fica pendurado sem resposta {#n8n-alwaysoutputdata-ausente-pendura-webhook}

`tags: n8n, postgres node, alwaysOutputData, 0 rows, IF node pulado, execution running, webhook pendurado, responseNode, timeout, sem resposta http, 0 items`

**Sintoma:** um workflow com `responseMode: responseNode` (o webhook espera um node "Respond to
Webhook" explícito) ocasionalmente fica "rodando" por minutos sem nunca responder ao chamador —
`GET /rest/executions/{id}` mostra `status: "running"` por tempo anormal (a Kommo/o cliente HTTP
original acaba fazendo retry, gerando execuções duplicadas do mesmo evento).

**Causa raiz:** um node Postgres (`operation: executeQuery`) que devolve 0 linhas emite, por padrão,
**0 items de saída** — não um item vazio. Um node `IF` (ou qualquer node) que recebe 0 items em
TODAS as entradas é **pulado inteiro**, sem rodar nenhum dos 2 branches. Se esse `IF` é o único
caminho até um node `Respond to Webhook`, o webhook nunca recebe resposta — a execução "trava"
(do ponto de vista de quem chamou) até o timeout do lado de quem fez a requisição.

**Solução:** todo node Postgres cuja query pode legitimamente devolver 0 linhas (busca que pode não
achar nada — canal não configurado, item duplicado via `ON CONFLICT DO NOTHING`, etc.) E que
alimenta um `IF`/node que precisa rodar de qualquer forma pra alcançar um `Respond` **tem que ter
`"alwaysOutputData": true`** no JSON do node. Com isso, 0 linhas vira 1 item com `json: {}` (objeto
vazio, confirmado empiricamente contra n8n real — não é `[]`/array, nem `null`), que o `IF` seguinte
avalia normalmente (campos ausentes → `notEmpty` dá `false` → cai no branch certo).

**Como confirmar sem adivinhar:** decodificar a execução real (`GET /rest/executions/{id}`, campo
`data` no formato "flatted" — resolver referências numéricas recursivamente) e olhar o output
literal do node em questão, em vez de assumir a partir da documentação.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-11/12. Corrigido em 5 nodes Postgres do mesmo projeto assim
que o padrão foi reconhecido pela 1ª vez.
