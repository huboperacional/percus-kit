## Bot de WhatsApp mudo sem nenhum erro no log: o número do device mudou e o filtro de JID descarta tudo com 202 {#bot-whatsapp-mudo-sem-erro-e-o-jid-do-device-que-mudou}

`tags: whatsapp, gowa, webhook, jid, device, multi-device, env-add, watchdog, bot mudo, 202 ignored, INVALID_WA_CLI, device_removed, R23`

**Sintoma:** o bot de WhatsApp para de responder. Nenhum erro no backend, nenhum 4xx/5xx, o
endpoint do webhook segue recebendo `POST` e devolvendo `202`. O watchdog do device começa a alertar
"deslincado" e o operador manda um screenshot do painel do GOWA com o device **Logged in** — no
número novo.

**Causa raiz:** o webhook do GOWA é **global** (um servidor multi-device serve vários produtos), então
o backend filtra os eventos pelo JID do próprio device (`payload.device_id != settings.GOWA_INBOUND_DEVICE_JID`
→ `return {"status": "ignored"}`). "Não é meu" é o caminho **normal** do handler, por isso não loga.
Quando o operador troca o número do device, todo evento passa a chegar com o JID novo e é
descartado em silêncio. Pior: a variável **não estava setada no serviço** de produção — valia o
default do `config.py`, e o default era o número antigo.

**Medido em Plexco Tasks (2026-09-05):** `docker service inspect plexco_backend` mostrava só
`GOWA_DEVICE_ID=plexco`; `GET /app/devices` no GOWA mostrava o device `plexco` com
`jid: 5511980024853@s.whatsapp.net`; o sink de debug `gowa_hook` já tinha registrado `message` e
`message.ack` do número novo. O backend tinha 980 `POST /wa/inbound/gowa 202` em 12h e zero
processamento.

**Segundo sintoma que confunde:** `GET /user/info?phone=<JID>` devolvendo
`{"code":"INVALID_WA_CLI","message":"your WhatsApp CLI is invalid or empty"}` (HTTP 500) para
**qualquer** JID não é problema de auth nem de JID — é o device **deslincado** no GOWA. O log do
GOWA mostra `<stream:error code="401"><conflict type="device_removed"/>` seguido de
`DEVICE_LOGGED_OUT (slot kept)`: o WhatsApp do celular removeu o dispositivo vinculado (acontece na
troca de número). `/app/devices` passa a mostrar `jid: ''`. Só re-parear por QR resolve; nunca
`/app/logout` em device morto.

**Como resolver:** o JID mora em **três** lugares e os três têm que mudar:

1. env do serviço em produção: `docker service update --env-add GOWA_INBOUND_DEVICE_JID=<novo>@s.whatsapp.net <servico>`
   (converge sem redeploy; lembre que `--env-add` persiste e é invisível no compose);
2. `alert.env` do watchdog (`GOWA_JID=`), senão ele sonda o número velho para sempre;
3. default no `config.py` + `.env.example`, para um ambiente novo não nascer mudo.

Depois, o operador re-pareia o device por QR, e o smoke é mandar "oi" pro número novo. Se outro
produto (auth-service enviando OTP) usa o mesmo device como `gowa_self`, ele volta junto.

**Regra que fica:** "bot mudo sem erro nenhum" = filtro de identidade (JID/device) descartando por
design. Antes de olhar código, compare o JID que o provedor reporta com o que o serviço tem no env.
