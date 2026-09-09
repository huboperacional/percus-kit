## Worker com tick antes do sleep dispara a cada deploy {#worker-com-tick-antes-do-sleep-dispara-no-deploy}

tags: [worker, asyncio, deploy, cron, whatsapp, efeito-colateral]

**Sintoma.** Um job "diário" parece rodar sempre no mesmo horário, mas `crontab -l` e
`systemctl list-timers` não têm nada nesse horário. E o efeito colateral dele (envio, cobrança,
e-mail) aparece logo depois de todo deploy.

**Causa.** O laço é `while not stop: await _tick(); await sleep(intervalo)` — **o tick vem ANTES do
primeiro sleep**. Então o horário não é horário: é `início_do_container + k*intervalo`. Reiniciar o
container **re-ancora a série** e dispara um tick imediato.

```python
# backend/app/workers/overdue_scan.py
while not stop_event.is_set():
    await _tick()                                   # <- dispara no start
    await asyncio.wait_for(stop_event.wait(), timeout=interval)
```

**Prova de que é isso, e não relógio:** reiniciar o serviço e conferir que o tick acompanhou.
Medido: `17:50:24 worker starting (interval=86400s)` seguido de `17:50:25 entregou 11 aviso(s)` —
o horário **mudou junto com o restart**.

⚠️ **A mitigação óbvia causa o que quer evitar.** Subir o intervalo
(`--env-add INTERVALO=<enorme>`) reinicia o container e **dispara a rajada na hora**. O
desligamento seguro é o flag que gateia a **criação** da task:

```python
if settings.OVERDUE_SCAN_ENABLED:            # main.py
    asyncio.create_task(run_overdue_scan(stop_event))
```

Com ele falso não existe laço, logo não existe tick inicial.

**Consequência operacional que morde quem não sabe:** enquanto o worker estiver armado, **qualquer
deploy de backend dispara o efeito colateral**. Se o efeito for envio de WhatsApp proativo, o deploy
pode derrubar o número — ver
[proativo no numero do OTP derruba o login](proativo-no-numero-do-otp-derruba-o-login.md).

**Ao desligar por `--env-add`:** a variável **persiste cross-deploy e é invisível no `docker-compose`**.
Registre no HANDOFF, senão o próximo a deployar não sabe que está lá.
