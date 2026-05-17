# Auditoria Eixo F (F.3 hooks + F.7 skills) — 2026-05-17

## F.3 — Hooks regex-only

| Hook | Arquivo(s) | Network call? | Status |
|---|---|---|---|
| pre-commit-check | pre-commit-check.ps1 / .cmd / .sh | nao | OK |
| mock-scan-pre-commit | mock-scan-pre-commit.ps1 / .cmd / .sh | nao | OK |
| auth-import-pre-commit | auth-import-pre-commit.ps1 / .cmd / .sh | nao* | OK |
| migration-check-pre-commit | migration-check-pre-commit.ps1 / .cmd / .sh | nao | OK |
| types-check-pre-commit | types-check-pre-commit.ps1 / .cmd / .sh | nao | OK |
| on-stop-check | on-stop-check.ps1 / .cmd / .sh | nao | OK |
| pre-plan-exit | pre-plan-exit.ps1 / .cmd / .sh | nao | OK |
| _helpers | _helpers.ps1 / _helpers.sh | nao | OK |

*`auth-import-pre-commit` contem a string literal `"GET https://auth.huboperacional.com.br/"` em mensagem de erro — nao e chamada de rede, e texto de instrucao pro usuario. Confirmado inspecionando linhas 75-82 do .ps1.

Padroes verificados: `api\.anthropic`, `api\.deepseek`, `api\.groq`, `api\.openai`, `Invoke-RestMethod`, `Invoke-WebRequest`, `curl.*api\.`, `HTTP.*api`, `Invoke-`, `curl `, `wget `, `http[s]?://`.

**Conclusao F.3: todos os 8 hooks (24 arquivos) sao regex-only. Zero chamadas de rede. Status OK.**

---

## F.7 — Skill descriptions

| Skill | Description atual (resumida) | Score | Description revisada |
|---|---|---|---|
| tracking-audit | "Use em PR que toca form/lead/conversion. Valida 15 campos canonicos paid media (fbclid, gclid…)" | 5 | — |
| delegate-impl | "Use ANTES de escrever codigo mecanico/boilerplate em volume. Calcula score heuristico…" | 5 | — |
| security-audit | "Use when reviewing/auditing auth-related code (auth/, auth_service/, middleware/…). Roda checklist YAML R14-R19" | 5 | — |
| cookie-audit | "Use when reviewing or modifying any code that sets HTTP cookies. Verifies R7 cookie subset — httpOnly + Secure + SameSite=lax" | 5 | — |
| catalog-publish | "Use after editing catalog-info.yaml or on session stop. Pushes feature catalog to Painel (/admin/catalog/ingest)" | 5 | — |
| feature-flow | "Use when starting any feature or bugfix in a Percus project. Orchestrates R1->R13 workflow" | 4 | — |
| pages-scan | "Use to scan project routes/pages and push them to the Painel de Gestao. Auto-detects FastAPI/Next.js/HTML" | 3 | "Use when explicitly asked to extract/sync routes or pages to the Painel de Gestao (POST /admin/pages/ingest). Targets FastAPI (@app.get/@app.post), Next.js (app/**/page.tsx), and static HTML — not generic code scanning or auditing. Auto-invoked by pre-commit and on-stop hooks; manually invoke only when catalog is stale or after adding new routes." |
| close-milestone | "Use when closing a milestone in Percus project — end of numbered phase, feature group in epic, or 'ready for next step' transition" | 3 | "Use when explicitly declaring a numbered Percus phase or epic feature group closed (e.g. 'Fase X concluida', 'fechar milestone', 'marcar Eixo Y'). Runs /percus-review:milestone-review checklist and marks ✓ in PLANO/HANDOFF. Do NOT trigger for routine commits or task completions — only for formal milestone closure." |

### Justificativa dos scores

- **pages-scan (3):** "Use to scan project routes/pages" e um trigger generico — qualquer pedido de "scan" ou "revisar paginas" pode matchear, confundindo com security-audit ou code review. A descricao nao deixava claro que o objetivo e sincronizacao com o Painel (POST /admin/pages/ingest), nao inspecao de codigo.
- **close-milestone (3):** "ready for next step transition" e overly broad — qualquer transicao de tarefa poderia triggerar. A falta de exemplos concretos de keywords ("Fase X concluida", "fechar milestone") tornava o lazy-match impreciso, com risco de ativar no fim de qualquer subtarefa.
- **feature-flow (4):** "Use when starting any feature or bugfix" e amplo mas o contexto "Percus project" e a mencao explicita do fluxo R1->R13 sao suficientemente especificos para nao confundir com outras skills.

**Conclusao F.7: 2 skills revisadas (pages-scan, close-milestone), 6 mantidas (5 com score 5, 1 com score 4).**

---

## Riscos identificados durante auditoria

- **String literal vs. network call (auth-import-pre-commit):** A URL `https://auth.huboperacional.com.br/` aparece em grep de `http[s]?://` mas e apenas texto de mensagem de erro. Sem impacto, mas vale manter consciencia se o hook for editado — nao adicionar chamadas reais sem review.
- **Overlap pages-scan / catalog-publish:** Ambas as skills envolvem push pro Painel. A distincao esta no objeto (rotas/paginas vs. catalog-info.yaml). A nova description de pages-scan reforca essa separacao.
- **feature-flow score 4:** O trigger "starting any feature or bugfix in a Percus project" cobre muito terreno. Nao e problema agora (unica skill com esse escopo), mas se uma skill de "quick bugfix" for adicionada no futuro, a description precisara ser diferenciada.
