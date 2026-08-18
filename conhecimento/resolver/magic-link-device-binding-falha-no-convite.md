## Convite via magic-link falha com "same device" mesmo no primeiro clique — device-binding gera falso-negativo no fluxo de convite {#magic-link-device-binding-falha-no-convite}

tags: magic link, auth-service, device binding, invite flow, 401, context mismatch, onboarding

**Sintoma:** um fluxo de "convidar usuário" (admin dispara convite → auth-service manda
magic-link por email/WhatsApp → convidado clica → `POST /auth/magic/consume`) falha com `401`
mesmo no **primeiro clique de um código nunca usado antes** — reproduzido com código fresco em
browser isolado (sem cookies/localStorage residuais), então não é reuso nem race.

**Causa raiz (auth-service Percus):** o magic-link tem **device-binding** — o consume só sucede
se o dispositivo que clica bate com um contexto de dispositivo capturado antes (provavelmente no
momento do `issue`, via `forwarded_for`/`user_agent` do request que disparou o convite). Isso é
uma proteção sensata contra phishing/link-forwarding **quando quem clica é o mesmo que pediu o
link** (ex.: "esqueci minha senha"), mas quebra por design no caso de **convite**, onde o
CONSUMIDOR é necessariamente um dispositivo diferente do ADMIN que convida — o binding captura o
contexto do admin, não do convidado, e a mismatch é estrutural, não um edge case raro.

**Sintoma no frontend:** a resposta real do auth-service é
`{"error_code":"magic_context_mismatch","detail":"Magic link must be opened on same device"}`,
mas o handler do frontend mapeia genericamente pra "link expirado" (colapsa 401/422 na mesma
mensagem por anti-oracle) — quem vê o erro não tem como saber que é device-binding, não expiração.

**Contorno usado (não é fix, é workaround pontual):** pular o magic-link inteiramente — linkar o
registro de domínio (aqui, `investors.user_id`) direto ao usuário admin JÁ autenticado, via
endpoint interno de link (`/users/{id}/link-investor`), sem passar pelo fluxo de convite.
Funciona pra teste/setup, não serve pra onboarding real de terceiros.

**Ação real:** é bug/comportamento do **auth-service**, não do produto consumidor — reportar ao
time do auth-service com a reprodução (código fresco, browser isolado, primeiro clique, resposta
`magic_context_mismatch`). Provável que nenhum teste do auth-service cubra o caso "quem clica ≠
quem pediu" porque a maioria dos consumidores testa magic-link só no caso self-service.

**Como foi encontrado:** `[5-T]` em produção, tentando convidar um investidor de teste
descartável — 3 tentativas (script direto, UI real do admin, código fresco em browser isolado via
Playwright MCP) todas falharam da mesma forma, eliminando hipóteses de contaminação de sessão.

**Ref:** Micro Investors, Fase 2 (votação interna), tentativa de onboard de investidor de teste,
2026-08-14.
