## Consumir `/internal/identities/v2` do auth-service: `name`, não `display_name` {#identities-v2-exige-name}

`tags: auth-service, identities, v2, IdentityCreateV2, name, display_name, origin, extra forbid, 422, provisionamento, identity_id`

**Contexto:** provisionamento de identidade no signup falhava **422** silencioso (`{"type":"missing","loc":["body","name"]}`) → `identity_id` ficava NULL → usuário sem login. O cliente mandava `{email, phone, display_name, origin}`.

**Causa raiz:** `IdentityCreateV2` (`app/modules/identity/schemas.py`) exige **`name`** (mapeia pra coluna `display_name`), `email` e `phone` — e tem **`extra="forbid"`**. Então `display_name` e `origin` no corpo geram DOIS erros: `missing name` + `extra_forbidden`. O `origin` é **derivado server-side** do `consumer_id` (anti-impersonation) e não deve ser enviado (use `origin_context` se precisar de sub-contexto).

**Solução:** payload correto do V2 = `{"name": <display>, "email": <e>, "phone": <p>}` (só isso; nada de `display_name`/`origin`). Verificar rápido: `curl` com o payload novo → 200; com o antigo → 422 com os 3 erros. Resposta ainda traz `display_name`/`origin` (só a ESCRITA que mudou).

**Ref:** Painel Gestão affiliate-signup (2026-07-14); `execution/integrations/authServiceClient.py:createOrGetIdentity`.
