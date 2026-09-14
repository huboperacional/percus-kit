## Reachout timelock do WhatsApp não só recusa envio: desloga o device companion (GOWA) — a sonda que cai todo dia no mesmo horário está certa {#reachout-timelock-do-whatsapp-desloga-device-companion}

`tags: whatsapp, gowa, reachout timelock, 463, device companion, logout, watchdog, sonda, falso positivo, contato frio, R23`

**Sintoma:** a sonda que verifica se o device do WhatsApp (GOWA, `go-whatsapp-web-multidevice`) está logado cai **todo
dia por volta do mesmo horário** em alguns projetos, e a primeira suspeita é a própria sonda (falso positivo) ou um cron.

**Causa medida** (VPS compartilhada paid-media/plexco/tiatendo, 2026-09-14): nos logs do serviço swarm `gowa_whatsapp` o
WhatsApp envia `NotificationUserReachoutTimelockUpdate` com `RESTRICT_ALL_COMPANIONS`, e o GOWA registra
`device_removed` / 403 "primary device was logged out" — às 22:30:0x UTC em três dias seguidos num número e 23:01:59 UTC
em outro. É o mesmo anti-spam do erro **463 `WA_REACHOUT_TIMELOCK`** (envio a contato frio, sem conversa prévia), em escala
que derruba o companion. Um dos números ficou **deslincado por dias**; a rotina suspeita (`day_closure`) tinha `sent=0` em
168 execuções — havia outro fluxo alcançando contato frio. O número que só manda para quem já conversou não foi afetado.

**Como diagnosticar:** `docker service logs gowa_whatsapp --timestamps --since 72h` e procurar `ReachoutTimelock` /
`device_removed` em volta do horário da queda, antes de mexer na sonda. `GET /devices` (Basic auth, sem `/app`) mostra
`state` e `jid` por device.

**How to apply:** re-parear só religa — a causa é o **volume de envio a contato frio daquele número**, e o dono da
correção é o projeto que envia (auditar TODOS os pontos de envio, não só o suspeito), não o watchdog.
