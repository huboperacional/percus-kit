---
tipo: handoff cross-projeto
origem: Plexco Tasks (sessão 36 — 2026-05-15)
destino: time Plexco Coach
audiência: tech lead Coach
status: aguardando replicação no Coach side
leitura: 3 min
referência profunda: D:\Claud Automations\Plexco Tasks\docs\superpowers\specs\2026-05-15-plexco-tasks-audience-wa-override-design.md
---

# Coach — replicar override de WhatsApp source por audience

## Por que este doc

O estúdio Percus padronizou: **produtos que já têm WhatsApp próprio devem usar o seu para enviar OTPs**, em vez de cair no canal compartilhado `Auth_Todos` (apelido "Robo de Notificações").

Hoje (2026-05-15), Plexco Tasks foi migrada — OTPs do `tasks.plexco.com.br` agora saem pelo número Plexco (mesmo do bot V1). Falta o Coach fazer o equivalente.

**Decisão da estratégia:** Plexco Tasks + Plexco Coach + Plexco Tickets compartilham a mesma instância Evolution chamada `Plexco`. Não criar novos números, reusar o que existe.

---

## O que mudar no Coach (1 SQL UPDATE)

Pré-requisito: zero código novo. A infraestrutura de override já está em prod no auth-service em `services/api/app/modules/audiences/service.py:33-63`.

### SQL pra rodar no auth-service DB (`percus_auth_v1`)

```sql
UPDATE auth.audiences
SET whatsapp_provider = 'evolution_self',
    whatsapp_config = jsonb_build_object(
      'api_key', '0C9B05DF6F94-407C-B0EE-8740882933F9',
      'instance_name', 'Plexco'
    ),
    updated_at = now()
WHERE audience = 'plexco-coach'
RETURNING audience, whatsapp_provider, whatsapp_config;
```

**Notas sobre o JSON:**
- `api_key`: chave da instância Plexco no Evolution (mesma que Plexco Tasks usa)
- `instance_name`: `Plexco` (literal, case-sensitive)
- `base_url`: omitido propositalmente → herda `settings.evolution_api_url` (`https://evo.huboperacional.com.br`). Se Evolution mudar de host no futuro, não precisa atualizar a row.

---

## Antes de rodar — validação pré-flight (2 min)

```bash
# Testa que key + instance + envio funcionam pra um número Coach-knowable
curl -s -i -X POST "https://evo.huboperacional.com.br/message/sendText/Plexco" \
  -H "apikey: 0C9B05DF6F94-407C-B0EE-8740882933F9" \
  -H "Content-Type: application/json" \
  -d '{"number":"55XXNUMEROCOACH","text":"[coach audience migration test] reply ignore","delay":0}'
```

Esperado: `HTTP 201 Created`. Se 401, parar e investigar antes de rodar o UPDATE.

---

## Smoke E2E pós-UPDATE

1. Abrir `https://coach.plexco.com.br/login` (ou o domínio canônico atual do Coach)
2. Pedir OTP com WhatsApp
3. **Verificar contato remetente no celular** — deve ser "Plexco" (não "Robo de Notificações")
4. Digitar código → entrar
5. Validar no banco:

```sql
SELECT provider, provider_instance, destination_masked, status, sent_at
FROM auth.message_audit
WHERE kind='otp' AND destination_masked LIKE '%55XXNUMEROCOACH%'
ORDER BY created_at DESC LIMIT 1;
```

Esperado: `provider=evolution provider_instance=Plexco status=sent`. Se ainda mostrar `Auth_Todos`, a row da audience não foi atualizada corretamente.

---

## Rollback (10 segundos)

Se algo der errado:

```sql
UPDATE auth.audiences
SET whatsapp_provider='default', whatsapp_config=NULL, updated_at=now()
WHERE audience='plexco-coach';
```

Próxima request volta pro `Auth_Todos`. Sem rebuild/restart. Idempotente.

---

## Trade-offs que você está aceitando

| Trade-off | Decisão Plexco Tasks |
|---|---|
| Blast radius compartilhado: ban do número Plexco afeta bot V1 (clientes criando tasks) + login Plexco | Aceito. Rollback de 10s mitiga. |
| Tráfego OTP misturado com tráfego conversacional do bot na mesma instance | Aceito. Monitorar via audit. |

Se Coach quiser **isolamento**, alternativa é criar nova instance `Plexco_Auth` no Evolution e apontar plexco-coach lá em vez de `Plexco`. Custo: +1 número WhatsApp + setup. Coach decide.

---

## Como observar uso e detectar problemas

```sql
-- Quantos OTPs por instance nas últimas 24h?
SELECT
  provider_instance,
  COUNT(*) AS msgs,
  COUNT(*) FILTER (WHERE status='failed') AS failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status='failed') / NULLIF(COUNT(*),0), 2) AS fail_pct,
  MAX(created_at) AS last_sent
FROM auth.message_audit
WHERE kind='otp' AND created_at > now() - interval '1 day'
GROUP BY provider_instance
ORDER BY msgs DESC;
```

Esperado: linhas separadas pra `Plexco` (Tasks + Coach) e `Auth_Todos` (Painel, Paid Media, qualquer audience sem override). Se `fail_pct` do Plexco subir muito acima do Auth_Todos, é sinal de problema com a instância compartilhada.

---

## Onde fica o spec completo

Decisão arquitetural detalhada + alternativas avaliadas: `Plexco Tasks/docs/superpowers/specs/2026-05-15-plexco-tasks-audience-wa-override-design.md`

---

**Quando terminar a migração do Coach, avise:** atualizar o "Mapa estratégico" no spec acima marcando `plexco-coach` como entregue.
