## Mensagem proativa no número do OTP derruba o login inteiro {#proativo-no-numero-do-otp-derruba-o-login}

tags: [whatsapp, gowa, otp, login, incidente, acoplamento]

**Sintoma.** O número de WhatsApp do produto é desconectado sozinho, e **ninguém consegue mais
entrar no sistema** — porque o mesmo número envia o código de login. `/app/devices` mostra
`jid: ""` e `/user/info` responde `INVALID_WA_CLI` (HTTP 500) para qualquer JID.

**Causa.** O WhatsApp não pune volume aqui: pune **iniciar conversa com quem não tem janela aberta**.
A punição tem nome no protocolo e é justamente desconectar os aparelhos vinculados:

```
22:30:01  [Client-X/Send] <message ...>                       (a NOSSA mensagem)
22:30:02  [Client-X/Recv] <notification op_name="NotificationUserReachoutTimelockUpdate">
          {"enforcement_type":"RESTRICT_ALL_COMPANIONS","is_active":true,
           "time_enforcement_ends":"..."}                      (= 21600s = 6h)
22:30:03  [Client-X/Recv] <stream:error code="401"><conflict type="device_removed"/>
```

**2,4 segundos entre a mensagem e o device morto. UMA mensagem, não rajada.**

🔑 **O defeito de projeto não é o envio — é o ACOPLAMENTO.** Aviso proativo e código de login
saindo pelo **mesmo device** significa que qualquer aviso pode derrubar a autenticação de todo
mundo por 6h. Um canal de conveniência derruba um canal crítico.

**O que NÃO resolve:**
- Espaçar os envios. Defesa contra ban por volume; o timelock é outra família.
- "Só mandar para número válido/cadastrado". Validade do número não é a variável — o castigo é por
  **não haver janela aberta**, e um número perfeitamente válido do próprio time dispara igual.

**O que resolve:**
1. **Separar os devices**: um número para avisos (pode ser punido sem consequência) e outro só para
   OTP. ⚠️ Confira se o cliente manda `X-Device-Id` global — se manda, trocar a env muda também o
   número com que o usuário **conversa**; o slice é separar o caminho PROATIVO do REATIVO, não um
   switch.
2. **Portão antes do envio**: só envia proativo para quem tem janela aberta. Precedente na casa:
   `proactive_gate.py` (Empresa Milionária, mesma punição em 2026-07-16) — *"volume baixo NÃO é
   seguro, é o perfil de RISCO"* e *"contato conhecido != conversa aberta"*.

**Sempre garanta um caminho de login que não dependa de WhatsApp** (OTP por e-mail) e verifique que
ele funciona **por round-trip real** (`otp.request.accepted` seguido de `otp.validate.ok`), não por
ausência de erro nos logs.

⚠️ **Um botão de UI que "cobra o responsável" é da mesma família** e é pior que o job automático: o
automático dá para prever quando dispara; o botão cai no instante em que alguém clicar.

Relacionado: [worker com tick antes do sleep dispara no deploy](worker-com-tick-antes-do-sleep-dispara-no-deploy.md)
