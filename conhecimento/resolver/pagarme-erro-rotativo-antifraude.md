## Pagar.me recusa cobrança com erro rotativo (telefone → documento → billing_address) sem dizer os 3 de uma vez {#pagarme-erro-rotativo-antifraude}

`tags: pagar.me, cobranca recusada, erro rotativo, antifraude, customer phone, document, billing_address, subscription failed, gateway_response, um motivo por vez`

**Sintoma:** criar um customer + card + subscription real (mesmo em `PAGARME_ENV=test`) falha com
`subscription.status = "failed"` (não um erro HTTP — a chamada "funciona", só o resultado final é
falho). A API devolve só UM motivo por vez em `last_transaction.gateway_response.errors` (ex.: `"At
least one customer phone is required"`); corrigir esse e tentar de novo revela o PRÓXIMO requisito
faltando (`"The customer Document is required"`), e depois o seguinte (`"billing | value is
required"` = falta `billing_address`).

**Causa raiz:** com antifraude ligado na conta Pagar.me (padrão), uma cobrança de cartão de crédito
precisa de: telefone do customer, documento (CPF/CNPJ) do customer, E `billing_address` — mas esse
último não é um campo do `customer`, é um campo do **`card`** (`POST /customers/{id}/cards` aceita
`{token, billing_address: {line_1, line_2, zip_code, city, state, country}}`), não documentado como
óbvio na maioria dos wrappers/exemplos.

**Solução:** ao integrar cobrança de cartão pela primeira vez, montar a chamada já com os 3 de uma
vez (telefone + documento + billing_address no card) em vez de descobrir um por um por tentativa e
erro — cada tentativa cria um customer/card/subscription real (mesmo que "failed") no painel Pagar.me,
poluindo o ambiente de teste.

**Ref:** tiatendo, sessão 2026-08-07 (smoke `PAGARME_ENV=test` de O4b, achou o gap real em
`pagarmeClient.createCard()`).

**Fechado (mesmo dia, sessão de continuação):** os 3 campos agora são coletados no formulário de
cartão (`saveCard()`) e enviados de uma vez. Confirmado em PROD `0.294.0` com smoke real
repetindo o mesmo roteiro — `createCard()` retornou `status=active` de primeira, sem nenhum dos 3
erros rotativos. Receita de smoke sem precisar de browser/OTP: ver
[smoke-pagarme-card-sem-browser](../fazer/smoke-pagarme-card-sem-browser.md).
