## "Não enviou" com credencial VÁLIDA: separe autenticação de provisionamento antes de mexer no `.env` {#credencial-valida-e-canal-morto-nao-sao-a-mesma-falha}

`tags: WhatsApp, GOWA, device, provisionamento, credencial, 401, 404, 400, diagnóstico, integração, canal de mensagem, SMTP, provedor de e-mail, DNS, SPF, DKIM`

**Sintoma:** o primeiro envio real de uma integração de mensagem falha, e a reação automática é
conferir a credencial — trocar senha, regerar token, reler o `.env`. Costuma ser a coisa errada.

**A separação que resolve em um minuto:** *autenticar* e *ter um canal provisionado* são duas
condições independentes, e o **código de status distingue as duas**:

| Resposta | O que ela diz | O que fazer |
|---|---|---|
| **401 / 403** | a credencial não passou | aí sim é `.env` |
| **400** com erro estruturado | a credencial passou, falta parâmetro | é chamada, não credencial |
| **404 `DEVICE_NOT_FOUND`** | a credencial passou, **o canal não existe** | provisionar, não autenticar |

Medido num caso real: `POST` de mensagem devolveu
`{"code":"DEVICE_NOT_FOUND","message":"device not found; create a device first",
"results":{"device_id":"..."}}`. E um `GET /api/devices` no mesmo host, com a mesma credencial,
devolveu **400 `DEVICE_ID_REQUIRED`** — não 401. **Duas leituras, cinco segundos, e a conclusão
inverte:** a credencial estava certa desde o começo; o aparelho é que nunca tinha sido criado e
pareado.

🔑 **O sinal que estava no `.env` e ninguém ligou:** o campo do identificador do aparelho
(`*_DEVICE_JID`, `*_INSTANCE_ID`) estava **vazio**. Campo de identidade de canal vazio é
provisionamento pendente, e ele é preenchido *pelo* pareamento — não antes dele.

**O canal que não existe é diferente do canal que falhou.** Na mesma medição, o segundo canal
(e-mail) devolveu "não enviado" por outra razão inteiramente: **não havia provedor nenhum** no
produto — varrido o backend, o frontend e o arquivo de dependências, zero ocorrência de
`smtplib`/`aiosmtplib`/Resend/SendGrid/Mailgun/SES, e nenhuma credencial de SMTP. Um endereço de
remetente configurado (`SUPERADMIN_EMAIL=...`) **não é** um canal: é uma string.

Vale dizer em voz alta ao operador, porque o custo é dele e não do código: e-mail exige escolher
provedor, **verificar o domínio no DNS** (SPF/DKIM) e pôr credencial em produção.

**Como fazer o canal falhar BEM** (o que essa medição validou): o módulo de notificação não levanta
e devolve **um resultado por canal**, com motivo legível quando não sai. No primeiro contato com a
realidade, os dois canais falharam por motivos diferentes, nada quebrou, e a mensagem de cada um
dizia o que fazer. Canal ausente implementado como **recusa explícita** — e não como `pass` — é o
que impede o produto de prometer dois canais e entregar um sem nada acusando.

**Onde apareceu:** Empresa Milionária, 2026-08-20, primeiro envio real do convite do contador
(M1-7).
