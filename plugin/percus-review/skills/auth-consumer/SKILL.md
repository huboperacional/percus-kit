---
name: auth-consumer
description: Use ao implementar OU auditar a integração de login de um produto Percus com o auth-service central (login combinado OTP+magic early-202, bridge #at=, validação JWT via JWKS, resolução de identidade iid→fallback-sub padrão único). Roda checklist grep (runner generalizado) + auditoria guiada semântica C1-C8. Consumer-side; complementa security-audit (service-side).
---

# Percus — Auth Consumer (integrar / auditar login contra o auth-service)

Skill **consumer-side**: como um produto Percus **integra** seu login com o **auth-service
central** (`auth.huboperacional.com.br`) e como **auditar** uma integração existente. Complementa
o `security-audit` (que é service-side, R14-R19). Mecanismo **híbrido**: checklist grep (triagem
rápida automatável) **+** auditoria guiada semântica C1-C8 (o que grep não pega — ex.: resolução
por coluna canônica, contrato `iid`/fallback, UX early-202). Extraído da reconciliação
cross-produto provada em prod (Coach + Tasks), 2026-06-09. Atualizado em 2026-06-13
(early-202 + regra de identidade padrão único).

## Quando usar

- Integrar login num produto Percus **novo** (do zero) → modo IMPLEMENTAR.
- **Auditar** conformidade de um produto que já consome o auth-service → modo AUDITAR.
- Após **migração de subdomínio** (o `default_redirect_uri`/`origins` podem ter ficado stale).
- Suspeita de **login quebrado / 404 inesperado** pós-token.
- Produto com UX que dependia de `502/503` do `/otp/request` (morreu com early-202).

## NÃO usar

- Pra auditar o **próprio auth-service** (service-side) → use `security-audit` (R14-R19).
- Pra fluxo de magic **per-contexto** com payload no link (`?task=`/`?invite=`) → isso usa
  `/auth/magic/issue` com `redirect_uri` explícito, não o combinado; ver Anti-padrões.

## Pré-requisitos

- Python 3.10+ + `pyyaml` (pro grep). Repo-alvo como CWD.
- A auditoria guiada (C1-C8) não precisa de nada além do Claude lendo o repo.

---

## O padrão (a fonte da verdade, condensada)

**Arquitetura — 2 domínios, por design:**
- **Motor de auth = centralizado** em `https://auth.huboperacional.com.br`. Todo produto chama ESSE
  pra OTP/JWT/magic/JWKS. O magic-link da mensagem mora aqui (`/w#<code>`, interstitial
  anti-preview-bot, code no fragment).
- **Destino + sessão = domínio PRÓPRIO de cada produto.** O magic faz 302 pro seu domínio com o
  token no **fragmento** (`…<seu_redirect>#at=<JWT>&rt=<refresh>`). É lá que a sessão nasce.

**Login canônico = OTP combinado (early-202, A2).** `POST /otp/request {channel, destination, audience}`
responde **`202` imediato** — envio em background. Manda **código + magic-link no mesmo envio**
(quando a audience tem `default_redirect_uri` setado). Falha de provider **não volta síncrona**
(sem 502/503 de WhatsApp). O usuário ou (a) digita o código → `POST /otp/validate` → tokens; ou
(b) toca no link → interstitial consome → 302 pro `default_redirect_uri#at=…`. Os dois caminhos
chegam no mesmo lugar.

**Token = JWT EdDSA.** Valide **localmente via JWKS** (lib `percus-auth`/`@percus/auth`), **sem RTT**
em `/me` no hot path. Claims: `sub` (`canal:handle`, sempre), `iid` (UUID da identidade canônica,
**quando provisionada**), `aud`, `iss`, `magic:true` se veio de link.

**🔑 Regra de identidade (padrão único — decisão 2026-06-12):**
- `iid` é **atalho**, NUNCA requisito. O token traz `iid` **só quando a identidade já está
  provisionada**. **Login é lookup-only** — quem provisiona é o **signup** (chama
  `POST /internal/identities[/v2]`), não o `/otp/request`.
- **Regra dura: NUNCA quebre um user legítimo autenticado por causa do `iid`.**
- **Padrão único:** fallback-pro-`sub` (Tasks-style) — quando `iid` ausente, resolver por
  `sub` (`canal:handle` → email/phone); user inexistente local → **401** (não 404). Esse é
  o padrão esperado. C2 do AUDITAR valida esse caminho.
- **Coach = exceção nominal documentada** — exige `iid` + garante provisionamento + backfill.
  Não é um segundo caminho aberto para novos projetos.
- **Coluna canônica:** ao resolver por `iid`, case contra a coluna canônica do produto
  (ex.: `tasks_identity_id`), **nunca** contra um id per-org (`user_id`).

**⚠️ UX early-202:** com o contrato early-202, `/otp/request` não devolve mais `502/503` de
WhatsApp. UX que dependia desse erro ("número sem WhatsApp → use email") morreu silenciosamente.
Ofereça canal alternativo **proativamente** ("não recebeu? tente e-mail"). Use
`POST /internal/whatsapp/check` no signup para checar o número antes do 1º OTP (fail-open: `null`
= provider down, nunca bloqueie o cadastro).

**Cookies (R7):** se cunha sessão própria → cookie **httpOnly + Secure + SameSite=lax**; limpe o
fragmento com `history.replaceState` antes de redirecionar. **Refresh** (`/otp/refresh`) é
single-use com rotation → **serialize** no client.

---

## Modo AUDITAR

### (a) Grep rápido — checklist declarativo

```bash
python "${env:PERCUS_CANON_DIR}/plugin/percus-review/scripts/security_audit.py" \
  --checklist "${env:PERCUS_CANON_DIR}/plugin/percus-review/skills/auth-consumer/checklist.yaml" \
  --label auth-consumer
```

Opções: `--json` (CI), `--min-severity high`, `--eixo IDENTITY`. Exit 0 = todos PASS · 1 = FAIL ·
2 = erro de schema/IO. Cobre os checks automatáveis. **É triagem** — a profundidade está em (b).

### (b) Auditoria guiada semântica (C1-C8)

O grep não pega resolução por coluna canônica, contrato `iid`/fallback, UX early-202 nem dual-call.
Inspecione o repo (frontend + backend) e reporte **PASS/GAP** com `arquivo:linha`:

- **C1. Entrada** — endpoint que inicia o login é `POST {AUTH}/otp/request`? Chama endpoint
  inexistente (ex.: `/auth/magic/request`)? Qual `audience` + onde configurado? O tratamento de
  erros aguarda 502/503 de WhatsApp do request (stale pós-early-202)?
- **C2. Resolução de identidade (CRÍTICO)** — como acha o user local a partir do token? Usa `iid`
  contra a coluna da identidade **CANÔNICA** ou um id **per-org**? Tem **fallback pro `sub`**? **O
  login 404a quando `iid` falta ou o user não existe?** (esperado: nunca 404 user legítimo; user
  inexistente → 401). _Padrão único vigente: fallback-pro-sub. Coach é exceção nominal._
- **C3. Provisionamento** — usuário NOVO ganha identidade via `POST /internal/identities[/v2]` no
  signup? Login provisiona algo (não deveria)? Há legados sem identidade canônica (precisam backfill)?
- **C4. Bridge + redirect** — rota fixa consome `#at=`/`#rt=` do fragmento? URL exata? Limpa o
  fragmento? O `default_redirect_uri` registrado aponta pro domínio **ATUAL** do app? FIXO ou CONTEXTUAL?
- **C5. Validação JWT** — local via JWKS (lib) ou RTT em `/me` no hot path? (esperado: local).
- **C6. Sessão/cookies** — cookie httpOnly+Secure+SameSite=lax? Storage do token? Refresh serializado?
- **C7. Combinado** — usa `/otp/request` combinado (código+link) ou ainda faz dual-call antigo
  (`/otp/request` + `/auth/magic/issue` em paralelo)?
- **C8. Estado** — algo quebrado/404 inesperado hoje? Domínios de frontend reais em prod (allowlist
  `origins`)? UX depende de erro síncrono de WhatsApp que não existe mais (early-202)?

**Relatório:** `Cn ... PASS/GAP — evidência` + `GAPS A CORRIGIR (prioridade)` + `VEREDITO`.

---

## Modo IMPLEMENTAR (produto novo ou correção)

Wiring canônico (ref: `CONSUMIR_AUTH_SERVICE.md` no canon + `CONSUMER_QUICKSTART.md` no auth-service):

1. **Registrar a audience** (lado auth-service, 1x): `display_name`, `default_redirect_uri`
   (= domínio próprio + path da bridge, ex.: `https://meu-app.com.br/open`), `origins`.
2. **Backend — login (early-202):** `POST {AUTH}/otp/request {channel,destination,audience}` →
   202 imediato. **Não espere 502/503 de WhatsApp.** Ofereça canal alternativo proativamente.
3. **Backend — JWT local:** lib `percus-auth`/`@percus/auth` (JWKS cacheado), **nunca** RTT `/me`.
4. **Backend — signup:** `POST {AUTH}/internal/identities[/v2]` (header `X-Internal-Auth`) pra
   provisionar a identidade canônica antes do 1º login. (Login não provisiona.)
5. **Resolução do user local:** `iid` se presente → **coluna canônica**; **fallback pro `sub`**
   se `iid` ausente; user inexistente → **401**, nunca 404.
6. **Frontend — bridge fixa** (ex.: `/open`): lê `location.hash` (`at`/`rt`), persiste, **limpa o
   fragmento** (`history.replaceState`), redireciona pro app.
7. **Refresh:** `POST /otp/refresh` single-use, **serializado** no client.

---

## Anti-padrões (os gotchas que quebram em prod)

- ❌ **UX que aguarda 502/503 de WhatsApp do `/otp/request`** — não existem mais (early-202).
  Ofereça canal alternativo proativamente.
- ❌ Resolver o user por id **per-org** (`user_id`) no lookup por `iid` → 404 mesmo COM `iid` válido;
  smoke numa conta onde os ids coincidem mascara. **Case sempre contra a identidade canônica.**
- ❌ **Hard-404/401 só porque `iid` não veio.** `iid` é atalho — caia pro `sub`.
- ❌ Chamar `/auth/magic/request` ou `/auth/magic/verify` — **não existem** (são `/auth/magic/issue`
  + `/auth/magic/consume`; login normal nem precisa, o combinado já manda o magic).
- ❌ Validar JWT por RTT em `/me` no hot path — use JWKS local.
- ❌ `default_redirect_uri` apontando pro domínio **antigo** pós-migração de subdomínio → token cai
  num lugar sem bridge e se perde.
- ❌ **Dual-call** (`/otp/request` + `/auth/magic/issue` em paralelo) em vez do combinado.
- ❌ JWT em `localStorage`/`sessionStorage` sem namespacing claro (risco XSS cross-produto).
- ❌ Magic **per-contexto** (`?task=`/`?invite=`) via combinado/`default_redirect_uri` fixo — emita
  com `/auth/magic/issue` + `redirect_uri` explícito, propagando `X-Forwarded-For`+`User-Agent`.
- ❌ `POST /internal/whatsapp/check` retornou `null` (provider down) → bloquear cadastro. Fail-open sempre.

## Referências

- Guia hands-on: `_Novo_Projeto/CONSUMIR_AUTH_SERVICE.md`.
- Manual completo: `auth-service/docs/CONSUMER_QUICKSTART.md` (read-only, cross-repo).
- Padrão + auto-auditoria: `auth-service/docs/padrao-login-percus-conformidade.md` (read-only).
- Canon: `_Novo_Projeto/PADRAO_AUTH_SERVICE.md` (B.2 early-202, B.4 identidade, B.5 whatsapp/check).
- Regras: `01_REGRAS_INEGOCIAVEIS.md` (R7 cookies, R16 SSO, R17 magic, R19 identidade).
- Skills irmãs: `security-audit` (service-side R14-R19), `cookie-audit` (R7).
- Runner: `scripts/security_audit.py --checklist skills/auth-consumer/checklist.yaml --label auth-consumer`.
