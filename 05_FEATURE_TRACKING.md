---
tipo: convenção-cross-projeto
prevalece-sobre: comandos/* (quando há conflito sobre como rastrear feature)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao aplicar feature global (auth v3, lead form, tracking, etc.) em projeto Percus
leitura: 6 min
ultima-atualizacao: 2026-05-15
fase-introducao: Fase 6
---

# 05 — Feature Tracking cross-projeto

> **Por que existe:** sem este sistema, fica impossível responder "em quais projetos a feature X v3 já foi aplicada?". Operador perde controle, retrabalho, drift entre projetos.
>
> **Como funciona:** cada repo Percus mantém um `catalog-info.yaml` na raiz + ADRs em `docs/adrs/` quando a decisão for significativa. Um crawler no Painel agrega tudo numa matriz `Feature × Projeto`.

---

## Princípios não-negociáveis

1. **Toda feature aplicada em 2+ projetos é uma "feature global"** e DEVE aparecer em `catalog-info.yaml`.
2. **Toda decisão arquitetural significativa** (escolha de pattern, mudança de stack, sunset de tecnologia) DEVE ter ADR.
3. **Slugs canônicos** (kebab-case, sem prefixo de projeto): `oauth-v3`, `lead-form-v2`, `auth-otp-whatsapp`, `tracking-15-campos`.
4. **Single source of truth**: o `catalog-info.yaml` é fonte; o Painel é cache. Quem está errado é sempre o cache.
5. **Não existe "implementei e esqueci de declarar"** — hook `catalog-publish` empurra automaticamente.

---

## Arquivos canônicos por projeto

### `catalog-info.yaml` (raiz do repo)

Template em `D:\Claud Automations\_Novo_Projeto\templates\catalog-info.yaml.template`. Schema:

```yaml
apiVersion: percus.io/v1
kind: Component
metadata:
  name: <slug-do-projeto>
  description: <descrição curta de 1 linha>
spec:
  type: service | library | site | data
  lifecycle: experimental | production | deprecated
  owner: <responsável>
  system: <agrupador, ex: vendas, auth, conteúdo>
  features:
    - slug: oauth-v3
      version: 3.1.0
      status: adopted          # adopted | trial | pending | deprecated
      applied_at: 2026-05-10
      notes: "via lib percus-auth"
    - slug: lead-form-v2
      version: 2.0.0
      status: trial
      applied_at: 2026-05-12
  dependsOn:
    - component:auth-service
    - resource:postgres-vps
    - resource:redis-vps
```

**Quando atualizar:**
- Ao aplicar feature global pela primeira vez → adicionar entrada em `features:`.
- Ao bumpar versão de uma feature existente (ex: oauth-v3 → oauth-v3.2) → atualizar `version` + `applied_at`.
- Ao deprecar uma feature → status `deprecated` + manter `notes` explicando motivo.

### `docs/adrs/NNNN-<slug>.md` (Architecture Decision Records)

Template em `D:\Claud Automations\_Novo_Projeto\templates\adr-0000-template.md`. Schema MADR + extensão Percus:

```markdown
# ADR-NNNN: <título da decisão>

- **Status:** Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN]
- **Date:** 2026-05-15
- **Applied-to:** projeto-a, projeto-b   ← consumido pelo crawler do Painel
- **Feature-slug:** oauth-v3              ← link pro catalog-info.yaml

## Context

Por que essa decisão precisa ser tomada agora.

## Decision

O que foi decidido.

## Consequences

- O que melhora.
- O que piora.
- O que é reversível, o que é irreversível.

## Alternatives considered

Lista curta dos outros caminhos descartados, com motivo de descarte.
```

**Quando criar ADR (e não só atualizar yaml):**
- Decisão é polêmica (alternativa real foi considerada).
- Decisão é irreversível ou cara de reverter.
- Decisão muda contrato cross-projeto (ex: novo schema de token, novo endpoint padrão).
- Sunset de tecnologia (vai parar de usar X em favor de Y).

ADRs nascem em **um** projeto, mas `Applied-to:` lista os N que adotaram. O crawler do Painel agrupa por slug.

---

## Slugs canônicos — convenção

- **kebab-case**, sem espaço, sem maiúscula.
- **Sem prefixo de projeto** (`oauth-v3`, não `painel-oauth-v3`).
- **Com versão major** quando há quebra de contrato (`auth-v2`, `auth-v3`).
- **Hierarquia opcional** com `/` (`tracking/15-campos`, `tracking/utm-pixel`) — útil quando há sub-features.

Lista canônica das features globais conhecidas em 2026-05-15:

- `oauth-v3` (auth com OTP WhatsApp + JWT EdDSA + refresh family invalidation)
- `tracking-15-campos` (UTM + click IDs canônicos, ver R2 + `03_TRACKING_ATTRIBUITION.md`)
- `lead-form-v2` (confirmação de form + handoff pro CRM, novo fluxo 2026-05)
- `magic-link-centralizado` (R17 — endpoint `/auth/magic/*` do auth-service)
- `sso-subdominio-compartilhado` (R16)
- `sso-redirect-fragment` (R16, cross-apex)
- `audit-hash-chain` (R14, immutable ledger)
- `rate-limit-ipv6-64` (R15)
- `identity-canonica-auth-service` (R19)
- `mock-audit-pre-commit` (R3, Fase 6)
- `types-check-pre-commit` (R5, Fase 6)
- `migration-check-pre-commit` (R6, Fase 6)
- `conselho-3-membros` (Fase 6, DeepSeek + Cross-Claude + Llama)

Mais virão. O crawler descobre features novas pelo `catalog-info.yaml` dos projetos.

---

## Integração com o Painel de Gestão

### Ingest (push)

Skill `catalog-publish` (no plugin `percus-review` v6.0.0) detecta delta em `catalog-info.yaml` e empurra:

```
POST https://gestao.ads4pros.com/admin/catalog/ingest
Header: X-Internal-Auth: <secret>
Body: <conteúdo parseado do yaml>
```

Mesmo padrão pra ADRs (`POST /admin/adrs/ingest`).

### Crawler (pull, fallback)

Worker `catalogCrawler.py` no Painel itera sobre `projects.git_url` a cada 1h, baixa `catalog-info.yaml` e `docs/adrs/*.md` via GitHub API, popula `features` + `project_features` + `feature_adrs`. Vale como rede de segurança quando a skill `catalog-publish` não rodou.

### Visualizações disponíveis no Painel (rota `/gestao/...`)

- `features.html` — matriz `Feature × Projeto` (linhas = features, colunas = projetos, células = status + version).
- `mindmap.html` — Markmap renderizando `docs/features.md` auto-gerado.
- `dependencias.html` — Cytoscape.js com grafo `Project → Feature ← Project`.
- `radar.html` — Zalando tech-radar com rings `adopt / trial / assess / hold`.
- `projeto-detalhe.html?slug=...` — aba **Páginas** lista rotas ativas (FastAPI + Next.js + HTML).

Drill-down: célula `(feature, projeto)` mostra páginas exatas onde a feature está, ADRs aplicados, último commit relevante.

---

## Drift detector (Eixo C — conselho)

Comando `/council:drift-detect <feature-slug>` no plugin invoca os 3 membros do conselho (DeepSeek + Cross-Claude + Llama via Groq). Conselho lê:
- `catalog-info.yaml` de cada projeto que declara a feature.
- Diff dos commits relevantes.
- ADRs aplicados.

Saída: lista de divergências (ex: "Plexco usa OAuth v3.1 mas Familia ainda v2.4 em fluxo X — divergência em campo `expires_at`") + recomendação de próximo passo. Salva em `.deepseek/drift/<feature>-<timestamp>.md`.

---

## Gate de verificação

- Toda feature aplicada em 2+ projetos aparece em `catalog-info.yaml` desses projetos.
- Toda decisão polêmica aplicada cross-projeto tem ADR linkado via `Applied-to:`.
- Crawler do Painel ingere sem erro em janela de 1h.
- Página `gestao/features.html` mostra cada projeto presente com pelo menos 1 feature listada.

**Anti-padrão:** "vou registrar no PLANO local e está bom" — PLANO é registro intra-projeto. Cross-projeto exige `catalog-info.yaml`.

---

## Referências

- Schema completo: `templates/catalog-info.yaml.template`
- Template ADR: `templates/adr-0000-template.md`
- Setup em projeto existente: `comandos/SETUP_CATALOG.md`
- Skill `catalog-publish`: `D:\Claud Automations\.claude-home\plugins\cache\percus-tools\percus-review\6.0.0\skills\catalog-publish\SKILL.md`
- Skill `pages-scan`: idem `skills/pages-scan/SKILL.md`
- Conselho `/council:drift-detect`: `06_CONSELHO_PERCUS.md`
