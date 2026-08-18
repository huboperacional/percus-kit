## Webhook que "nunca chega": o provedor DESATIVOU a assinatura sozinho depois das suas respostas inválidas {#webhook-desativado-pelo-provedor-apos-resposta-invalida}

`tags: webhook nao chega, 0 execucoes, disabled, assinatura desativada, kommo, amocrm, stripe, retry, resposta invalida, responseNode, onReceived, integracao morta em silencio`

**Sintoma:** o evento acontece no sistema de origem (dá pra ver na tela dele), mas o seu workflow /
endpoint **não registra execução nenhuma**. Zero. Você revisa o parser, o filtro, a rota — tudo
certo — e conclui que "o evento não está sendo gerado".

**Causa raiz:** a assinatura do webhook está **desativada do lado do provedor**. Muitas plataformas
desativam automaticamente um endpoint que responde de forma inválida (erro, timeout, sem corpo)
algumas vezes seguidas. Esse estado é invisível do seu lado: você não recebe nada, e "0 execuções"
parece "nenhum evento", não "fui desligado".

O que torna a armadilha perfeita: o motivo da desativação costuma ser **um bug seu já corrigido**.
Você conserta o workflow, testa, e continua sem receber nada — porque o conserto não reativa a
assinatura.

**Ordem certa de diagnóstico** — inverta o instinto:

```bash
# 1. PRIMEIRO: a assinatura está viva do lado de lá?
GET /api/v4/webhooks        # procure o campo `disabled`
# 2. só depois investigue parser, filtro de evento, rota
```

**A correção real não é reativar — é garantir que você SEMPRE responde.** Reativar sem consertar a
resposta só adia a próxima desativação. Dois pontos:

- **Todo caminho do fluxo precisa terminar numa resposta**, inclusive os de exceção. Audite as
  folhas do grafo: cada uma deve ser um node de resposta. Um `IF` que é pulado (porque o node
  anterior devolveu 0 linhas) mata o fluxo antes da resposta.
- **Prefira responder na entrada** (`responseMode: onReceived` no n8n; ACK imediato em qualquer
  stack) e processar depois. Com resposta só no fim, qualquer exceção no meio — banco fora do ar,
  payload inesperado — vira resposta inválida e conta pontos para a desativação.

**Sinal de alerta que aponta pra cá:** "o evento aparece no CRM, o parser funciona quando testo
local, mas em produção não chega nada" e a última execução registrada é de **dias atrás**, logo
depois de um período em que o sistema estava quebrado.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12. O `.../finalizar` estava `disabled=True` desde algum
ponto em que o workflow morria antes do `Respond` (o firewall bloqueava o Postgres e toda execução
falhava). O evento (`update_lead`) sempre esteve correto. Isso manteve o `03-finalizar-disparo` sem
NENHUMA execução real desde que o projeto existia — vários dias de investigação foram gastos no
parser, que estava certo o tempo todo.
