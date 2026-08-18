## Device GOWA (número novo/cold) banido "toda hora" com volume baixo {#gowa-device-ban-usync}

`tags: gowa, whatsapp, whatsmeow, device banido, LoggedOut, usync, 429, rate-overlimit, cold number, numero novo, healthcheck, /user/info, /devices, limiter, wa:devrate, redis db, prewarm, envio em massa, jitter, cloud api, reach-out 463`

**Sintoma:** o device GOWA (go-whatsapp-web-multidevice / whatsmeow) de um número **novo/cold** cai (deslogado, `LoggedOut`) diariamente, mesmo mandando **pouquíssimas mensagens**. O operador pergunta "por que bane com volume tão baixo?".

**Causa raiz:** NÃO é volume de mensagem — é **`usync` 429 `rate-overlimit`**. WhatsApp rate-limita as queries **usync** (`GET /user/info`, `GET /user/check` — checagem de número / info de contato) **por-conexão-de-device**, muito mais agressivo que envio; um número cold tem orçamento minúsculo. As fontes de usync são **invisíveis ao "volume de mensagem"**:
- **Healthcheck/watchdog** que sonda liveness com `GET /user/info` a cada 5 min = ~288 usync/dia, 24/7. **Esta costuma ser a maior fonte fixa.**
- **Prewarm / probes de entrega** (checar 9º dígito, `is_on_whatsapp`) — 1+ por cadastro; letais em **rajada**.
- **Contact-sync do whatsmeow no reconnect** — cada re-link por QR dispara um burst interno de usync.

**Como confirmar (evidência):** `docker logs --since 48h <gowa> | grep -iE 'usync|429|rate-overlimit|not connect'`. Um burst de `usync query ... status 429: rate-overlimit` imediatamente antes de um drop = ban por usync. Cruze com o **crontab** da VPS pra achar quem sonda a cada 5 min.

**Fix (em camadas, sem tocar no WhatsApp):**
1. **Healthcheck NÃO pode usar `/user/info`.** Trocar por listagem LOCAL do store (`GET /devices` ou `/app/devices`, que retornam `state`/`jid` sem gerar usync). Corta a maior fonte fixa. (o `device_health.py` do auth-service já era assim — modelo a copiar.)
2. **Serializador por-processo NÃO basta** se >1 serviço manda pro MESMO device (ex.: auth manda OTP + FM manda bot pelo mesmo device). Precisa de **limiter compartilhado**: token/janela-fixa no **mesmo Redis logical DB** (chave `wa:devrate:{device_id}`), consultado por TODOS os lados antes de cada usync. ⚠️ **Logical DBs do Redis são keyspaces ISOLADOS** — prefixo de chave NÃO cruza DB; os dois lados têm que bater o MESMO `db=N` (abrir conexão dedicada se o resto do tráfego usa outro DB). Fail-open absoluto (nunca bloquear OTP).
3. **Envio em massa** (broadcast/notificação) = jitter **6-12s + ≥2 variações** de mensagem (uniforme/rápido é assinatura de spam). Nunca fazer "blast" de agradecimento pós-wipe num número cold (foi o que baniu o device da FM em 2026-07-06 — 463 reach-out timelock).
4. **Fix definitivo:** migrar pro **WhatsApp Cloud API oficial** (Graph API). Não usa whatsmeow/linked-device nem usync → zera a classe inteira.

**Ref:** FM 2026-07-09/10, commits `99947ba` (healthcheck) + `d490ae4` (limiter FM). Memórias `project_snapshot_2026_07_09_usync_rootcause_limiter_compartilhado`, `incident_2026_07_06_gowa_familia_banido_antispam_463`, `convencao_envio_em_massa_antispam`. Contrato do limiter: `auth-service/docs/cross-product/2026-07-09-auth-reply-familia-fresh-start-e-usync.md`.
