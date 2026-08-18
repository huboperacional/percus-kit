## Watchdog de confirmação de entrega dispara falso-positivo contra device de teste automatizado (não gera ack) {#watchdog-ack-device-teste-automatizado}

`tags: watchdog, health check, delivery confirmation, ack, whatsapp, gowa, device de teste, falso positivo, alerta, monitoring, smoke test`

**Contexto:** watchdog "anti-mudo" que alerta quando N envios recentes de um canal (WhatsApp/GOWA,
mas a classe vale pra qualquer canal com confirmação de entrega assíncrona) ficam TODOS sem ack
(delivered/read) numa janela de tempo — sinal de sessão/dispositivo desconectado do lado de quem
envia.

**Sintoma:** alerta "N mensagens sem confirmação de entrega, verifique se o WhatsApp/device está
conectado" disparando repetidamente, sempre que alguém roda um smoke test/e2e contra o bot. O
device/canal de envio está saudável (mensagens chegam de verdade, confirmável lendo o histórico
por outra via), mas o alerta insiste.

**Causa raiz:** o RECEBEDOR das mensagens de teste é ELE MESMO um device/cliente automatizado
(ex.: um segundo bot/harness usado só pra disparar smokes), e não implementa o lado do protocolo
que gera confirmação de entrega/leitura (isso normalmente vem do cliente humano abrindo o app). O
watchdog mede corretamente "o envio nunca foi confirmado" — só que a premissa "sem confirmação =
problema no remetente" não vale quando o DESTINATÁRIO é quem nunca confirma, não importa o quão
saudável o remetente esteja.

**Solução:**
1. Identifique o(s) contato(s)/peer(s) automatizados usados só pra teste (harness de smoke, bot
   espelho, etc.) — geralmente têm um `contact_id`/número fixo e conhecido.
2. Adicione uma exclusão EXPLÍCITA e opt-in (via env/config, não hardcoded no código de produção)
   que remove esses contatos da contagem do watchdog, sem alterar o comportamento pra qualquer
   outro contato. Lista vazia/não-setada = comportamento antigo, sem filtro (default seguro).
3. NÃO desative o watchdog nem aumente o threshold pra "resolver" o ruído — isso mascara o caso
   real (contato humano genuíno sem confirmação). A exclusão tem que ser por IDENTIDADE do peer de
   teste, não por volume/frequência.
4. Confirme a causa ANTES de excluir: cheque a confirmação de entrega de um contato REAL no mesmo
   canal nesse intervalo — se ele recebe ack normalmente e só o device de teste não, a causa é o
   device de teste, não uma falha real de conectividade.

**Ref:** tiatendo, `execution/database/models/ackModel.py` (`tenantsWithSilentSends`) +
`execution/core/backgroundRunner.py` (`_ackWatchdogTick`), 2026-08-07 — alerta "N mensagens sem
confirmação de entrega" no tenant sabor-do-teste correlacionava 1:1 com sessões de smoke test
contra o device `whatsapp_de_testes`; contatos reais no mesmo tenant confirmavam entrega em 1-5s.
Fix: `ACK_WATCHDOG_EXCLUDE_CONTACTS` (env, csv, opt-in).
