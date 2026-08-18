## API rejeita `*_id` com `InvalidType` porque o driver do Postgres devolve `BIGINT` como STRING {#bigint-vira-string-e-api-rejeita-int}

`tags: BIGINT, string, InvalidType, HTTP 400, NotSupportedChoice, status_id, n8n postgres node, coercao de tipo, Number(), JSON.stringify, kommo`

**Sintoma:** a API externa recusa o corpo com algo como
`InvalidType: "This value should be of type int"` (às vezes acompanhado de `NotSupportedChoice`,
sugerindo falsamente que o VALOR é inválido), mesmo o número estando visivelmente correto no log.

**Causa raiz:** `BIGINT`/`int8` não cabe no `Number` de JS sem perda, então drivers Postgres o
devolvem como **string** (`"109943212"`). Se esse valor vai direto pro JSON do corpo, sai
`{"status_id": "109943212"}` — string — e uma API com validação estrita recusa. O `NotSupportedChoice`
junto engana: parece "esse id não existe", quando o problema é só o tipo.

**Solução:** coagir explicitamente na fronteira (`Number(...)`/`parseInt(...)`) para todo id que a
API exige como inteiro. E vale virar lint no pipeline de deploy: varrer o corpo JSON e reprovar
`"<campo_id>": <expressão não coagida>`, com **lista explícita** dos campos que a API exige como int
— reprovar qualquer coisa terminada em `_id` gera falso-positivo em campos que são string por design
(`request_id` de correlação, `external_id`).

**Cuidado com o gêmeo na direção oposta:** a MESMA API costuma devolver esses ids como **número** no
JSON de resposta, e aí um comparador de tipo estrito que espera string reprova
(`'27261879' is a number but was expecting a string`). Os dois convivem no mesmo workflow: coaja
para número indo, para string voltando.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12. O PATCH que "aperta o play" do Salesbot falhava com
HTTP 400 sem enviar mensagem nenhuma. O gêmeo invertido já tinha acontecido no mesmo projeto dias
antes, num `IF` comparando `id` de contato.
