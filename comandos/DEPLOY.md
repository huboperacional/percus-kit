---
tipo: playbook-de-deploy
quando-usar: ao deployar um projeto Percus na VPS (milestone / fim do dia / sob demanda — R24)
leitura: 3 min
ultima-atualizacao: 2026-06-25
fase-destino: 7+ (v6.20.0)
---

# Playbook — Deploy na VPS Percus (R24)

> **Cadência (R24):** deploy **não** é a cada feature. Os gatilhos canônicos são: **fim de milestone**,
> **fim do dia**, ou **sob solicitação direta do operador**. Durante o dia, trabalho fica em commits
> locais + dev; produção só recebe nos gatilhos. Sempre com **confirmação (R5)** + **smoke** + **rollback**.

---

## 0. Pré-deploy (gate)

- [ ] O que vai pra produção está `[5-T]` (ciclo CRUD testado) — ou o operador autorizou o risco em voz alta.
- [ ] Milestone fechado passou no `/percus-review:milestone-review` (R11), se for deploy de milestone.
- [ ] `HANDOFF.md` reflete o que está indo pra produção.
- [ ] **Confirmação do operador (R5)** — deploy é operação que afeta produção; nunca silencioso.
- [ ] Sei qual é a **versão/imagem atual** em produção (pra rollback).

## 1. Quando deployar (decisão)

| Gatilho | Deploya? |
|---|---|
| Terminei UMA feature isolada no meio do dia | ❌ Não — acumula pro fim do dia/milestone |
| Fechei um milestone (fase/épico aprovado) | ✅ Sim |
| Fim do dia, com features `[5-T]` acumuladas | ✅ Sim |
| Operador pediu "deploya agora" / hotfix | ✅ Sim (sob demanda) |
| Mudança só de doc/config local, sem efeito em prod | ❌ Não |

## 2. Como deployar (referência: `02_INFRA_E_STACK_PERCUS.md` §6-10)

A infra é Docker **Swarm + Traefik** no VPS `161.97.129.138`, gerida via **Portainer**
(`https://painel.huboperacional.com.br`) — API ou UI. Resumo:

1. **Build/push da imagem** (se aplicável ao projeto — registry ou imagem buildada na VPS).
2. **Atualizar a stack** existente via Portainer API (`PUT /api/stacks/{STACK_ID}?endpointId=1` com
   `stackFileContent`, `prune:true`, `pullImage:true` se imagem nova) — ver `02_INFRA` §10 "Atualizar stack existente".
3. Ou **forçar restart** do serviço (`ForceUpdate++`) se só mudou config/secret — ver `02_INFRA` §10.
4. Stack nova (primeira vez): `02_INFRA` §8-9 (Traefik labels + DNS Cloudflare **DNS only** + deploy via API).

> Detalhe operacional completo (CSRF, swarmId, endpoints) está em `02_INFRA_E_STACK_PERCUS.md` §7-10 —
> **não duplicar aqui**, este playbook é o "quando + sequência + verificação".

## 3. Smoke test pós-deploy (obrigatório — R24)

```bash
# 1. Serviço responde via Traefik (HTTPS + cert ok)
curl -I https://<sub>.huboperacional.com.br        # espera 200/301/302, não 5xx/520

# 2. Logs sem erro de boot
docker service logs <stack>_<servico> --tail 50

# 3. Healthcheck funcional do app (endpoint de saúde, login, ou rota crítica)
curl -s https://<sub>.huboperacional.com.br/health   # ou a rota crítica do produto
```

- **520 no curl** → DNS provavelmente "Proxied" no Cloudflare; tem que ser **DNS only** (`02_INFRA` §8).
- **5xx / serviço não sobe** → ler logs; se não resolver rápido → **rollback** (passo 4).

## 4. Rollback (tenha pronto ANTES de deployar)

**Swarm reverte pro spec anterior** (forma canônica):
```bash
docker service rollback <stack>_<servico>
```
Alternativas:
- **Re-deploy do YAML/imagem anterior** via Portainer (stack update com o conteúdo/version anterior).
- Se a mudança foi migration de banco: ter o `alembic downgrade -1` testado **antes** (rollback de schema
  é o mais arriscado — valide o downgrade em dev primeiro).

Após rollback: registrar no HANDOFF o que falhou + abrir entrada no `conhecimento/COMO_RESOLVER.md` (R23).

## 5. Pós-deploy

- [ ] Smoke test passou (passo 3).
- [ ] `HANDOFF.md` atualizado: "deployado em produção em {data} — {o que foi}".
- [ ] Problema novo descoberto no deploy? → `conhecimento/COMO_RESOLVER.md` (R23).

---

## Anti-padrões

- ❌ Deployar a cada feature (R24) — agrupe por milestone/EOD/sob-demanda.
- ❌ Deployar sem saber a versão atual (sem rollback possível).
- ❌ Pular o smoke test ("subiu, deve estar ok") — 520/5xx passam despercebidos.
- ❌ Deploy de migration sem `downgrade` testado em dev.
- ❌ Acumular dias sem deployar e sem registrar o pendente no HANDOFF.

## Referências

- Regra: `01_REGRAS_INEGOCIAVEIS.md` R24 (cadência), R5 (confirmação), R11 (milestone-review).
- Infra/como: `02_INFRA_E_STACK_PERCUS.md` §6-10.
- Procedimento curto: `conhecimento/COMO_FAZER.md#deploy-vps`.
