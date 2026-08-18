## "Zerar um campo pra não sobrescrever" em API full-replace na verdade APAGA o campo {#zerar-campo-em-put-full-replace-apaga}

tags: pagar.me, pagarme, put, patch, full-replace, api rest, campo omitido, null, guarda de identidade, super_admin, multi-tenant, billing, payment gateway

**Sintoma:** um guard pra "não deixar sessão errada sobrescrever dado de outra entidade" — ex.
super_admin agindo em nome de um tenant, sessão com identidade diferente do alvo — foi desenhado
zerando os campos "perigosos" (`campo=None`) antes de mandar pra uma API de update. Parece
inofensivo (`None` = "não mexe"), mas o conselho/review acha CRITICAL: o campo correto do dado alvo
**sumiu** depois da chamada, não ficou como estava.

**Causa raiz:** duas coisas combinadas, cada uma sozinha inócua: (1) o endpoint de update da API
externa é `PUT` (ou equivalente) **full-replace**, não `PATCH` parcial — "campo ausente no corpo"
vira `null` do lado do servidor, não "mantém o valor anterior" (comportamento documentado, mas fácil
de assumir o oposto se você só olhou o `POST`/create); (2) o client HTTP local só inclui uma chave
no corpo **quando o valor é truthy** (`if campo: body["campo"] = campo` — padrão comum pra evitar
mandar `null` explícito sem querer). A combinação: `campo=None` → helper de corpo OMITE a chave →
API interpreta ausência como "apagar". O guard que devia SÓ evitar sobrescrever com dado errado
acaba apagando o dado certo — pior que o bug original (que trocava por errado, não deletava).

**Solução:** pra um guard de identidade contra API full-replace, **NUNCA** "zere campos e deixe a
chamada acontecer". As opções seguras são: (a) **pular a chamada inteira** quando a sessão não é
confiável pro alvo (mais simples, comprovadamente seguro — nada enviado, nada apagado; único
trade-off é que o campo que SERIA atualizado por essa chamada — ex. um documento novo — também não
propaga nesse caminho específico); (b) buscar o registro atual via `GET` primeiro e reenviar os
campos que já existem lá, só trocando o que precisa mudar (mais completo, mas depende de confirmar
o schema exato da resposta do `GET` — não assuma que espelha o corpo do `POST`/`PUT` sem checar a
doc ou testar empiricamente); (c) buscar o dado "correto" de outra fonte de verdade (ex. banco
próprio) — mais correto conceitualmente, mas abre pergunta de design maior (qual registro é "o
certo" se houver ambiguidade). Ao decidir entre elas, prefira a que não depende de reverse-engineer
um schema não verificado — o council desta sessão vetou a opção GET-first justamente por causa
disso, mesmo sendo "mais completa" em teoria.

**Ref:** tiatendo, sessão 2026-08-07 — `execution/billing/pagarmeClient.py` (`_customerBody()`,
`updateCustomer()`) + `execution/dashboard/routes/billingRoutes.py` (`saveCard()`). Achado num
review de marco (Cross-Claude): `updateCustomer()` mandava contato da sessão super_admin em vez do
tenant alvo. 1ª tentativa de fix (zerar `email`/`phone`) foi BLOQUEADA por DeepSeek (CRITICAL) na
review de spec — confirmado lendo `_customerBody()` (só inclui chave `if email: ...`) e a doc
oficial do Pagar.me v5 (`docs.pagar.me/reference/editar-cliente-1`, full-replace confirmado, sem
PATCH no v5). Fix final: pular a chamada inteira pra `super_admin`, commit `97cab71`. Specs:
`docs/superpowers/specs/2026-08-07-pagarme-customer-sync-retry-safety-design.md` (achado de API) e
`docs/superpowers/specs/2026-08-07-pagarme-update-customer-super-admin-identity-guard-design.md`
(o round 1 rejeitado + a correção).
