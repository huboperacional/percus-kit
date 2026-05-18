# Canon Percus — versão atual

**Versão canônica em `huboperacional/percus-kit`:** `6.7.0`

> Esta versão refere-se ao **kit Percus completo** (canon `_Novo_Projeto/` + plugin `percus-review`). Os dois são sincronizados via tag no repo `huboperacional/percus-kit`. Quando você lê `plugin.json` versão X, o canon na pasta `_Novo_Projeto/` daquela tag também é versão X.

---

## Changelog v6.7.0 — 2026-05-18

**Sprint 2 completo (sobre v6.7.0-alpha):**

- **Fact-check pipeline (F3 reformulado):** `scripts/fact-check.ps1`/.sh — etapa OBRIGATÓRIA pós-reviewer. Findings `[SEV: risco|bug]` passam por subagent Sonnet que lê arquivos citados. INFUNDADO filtrado do output principal; audit block preserva todos. Integrado em `percus-review-auto.ps1` (default). Opt-out via `--no-fact-check`.
- **Echo dedup (F5):** `scripts/dedup-findings.ps1`/.sh — agrupa findings por MD5(file_path + 100 chars). PR stacks com mesmo finding viram "1 unique, presente em N PRs" em vez de "N confirmações independentes".
- **Test suite regressão (F6):** `tests/hardening-2026-05-18.tests.ps1` — 11 testes estáticos que validam todas as defesas implementadas. 11/11 pass. Rode em CI ou pre-release.
- **Skill enforcement (F7):** `commands/council-consult.md` ganha seção "Pre-requisitos (enforcement v6.7.0+)" exigindo fact-check de findings críticos antes de escalar. Warning estruturado pro agente seguir.

**Sprint 1 (v6.7.0-alpha, 2026-05-18 — incluído no v6.7.0 final):**
- Router F1: sensitive_paths +5 padrões (alembic, internal, infra, config, services)
- Canon F4ab: R11 expansion + R20 nova ("decisões de conselho não autorizam ação externa pública")
- Hook F4c: external-action-guard.ps1 (PreToolUse, bloqueia gh pr comment/slack-cli/push sem PERCUS_EXTERNAL_OVERRIDE)
- Council F2: -CodeContextDir + premise_validity + premise_validity_consensus aggregator

**Smoke validations:**
- F2 (orchestrator code injection): ambos providers retornaram `premise_validity: invalid` em claim falso sobre outbox pattern. Comportamento que preveniria incidente 2026-05-18.
- F6 (hardening tests): 11/11 pass cobrindo todos os 4 cenários do reporter + 3 bonus.

---

## Changelog v6.7.0-alpha — 2026-05-18

**Anti-hallucination hardening Sprint 1** (pós-incidente Plexco Tasks):

- **Router (F1):** `sensitive_paths` expandido com `alembic/versions/`, `api/v\d+/internal`, `infra/*.yaml`, `(backend|app)/.*config.py`, `services/(auth|payment|notification|webhook)/`. PRs tocando esses paths agora rotam `decision=dual` automaticamente.
- **Canon (F4ab):** R11 ganha adendo "alegação técnica sobre função importada → ler implementação OU marcar 'não verificada'" + linha na matriz de roteamento. R20 nova: "decisões de conselho não autorizam ação externa pública" (PR comments, Slack, deploy, push) sem gate explícito do operador.
- **Hook (F4c):** `external-action-guard.ps1` PreToolUse bloqueia `gh pr comment`, `gh issue close`, `slack-cli`, `git push` sem `PERCUS_EXTERNAL_OVERRIDE=1`. Layer 1 enforcement runtime do R20.
- **Council (F2):** `council-orchestrator.ps1` ganha `-CodeContextDir <path>` + parser ```file:path```. Providers recebem código real + instrução pra reportar `premise_validity: ok|invalid|unverified` antes de opinar. Aggregator `premise_validity_consensus` no output JSON. Smoke validou: claim falso sobre outbox pattern → ambos providers retornaram `invalid`.

**Pendente v6.7.0 final (Sprint 2):**
- F3: fact-check pipeline (etapa obrigatória, INFUNDADO filtrado antes do consolidador)
- F5: echo dedup em PR stacks
- F6: test suite hardening-2026-05-18 (4 cenários do reporter)
- F7: skill `council-consult` enforcement

---

## Changelog v6.6.1 — 2026-05-18

- **Fix orchestrator integration:** `council-orchestrator.ps1`/.sh agora passa `-Mode $Mode` (não `-SystemPrompt`) ao invocar cross-claude wrapper. Bug v6.6.0: wrapper detectava `PSBoundParameters.ContainsKey('SystemPrompt')` = true e pulava load do `.md` enriquecido. F.1 cache estava ativo só em chamadas standalone, não via orchestrator.
- Validado: smoke via orchestrator confirma cache_read >= 1024 tok em consecutive calls.

---

## Changelog v6.6.0 — 2026-05-18

- **F.1 cache Anthropic ATIVO** para Sonnet 4.6 e Opus 4.7 (validado: 3142 tok read do cache em smoke E2E). Haiku 4.5 não cacheia (limitação Anthropic atual).
- SystemPrompts enriquecidos em `providers/system-prompt-{consult,review}.md` (~2400/~2800 tok cada, R1-R19 condensadas + antipadrões + padrões aprovados + exemplos calibrados).
- Wrapper `cross-claude.ps1`/.sh ganha `-Mode consult|review|pre-mortem`.
- `hooks/canon-version-check.ps1` warn pre-commit (não bloqueia) se SystemPrompt desatualizado vs canon.
- `scripts/smoke-cache-f1.ps1` valida cache via `cache_creation_input_tokens` + `cache_read_input_tokens`.
- Defensive guards: `$PSScriptRoot` null fallback, YAML strip regex EOF-safe, bash `--mode` validation (parity PS ValidateSet).

---

## Como cada projeto consumidor declara sua versão

Todo projeto Percus deve ter um arquivo `.percus-version` na raiz, com uma única linha contendo a versão do canon que adotou no último upgrade. Exemplo:

```bash
cat .percus-version
# 6.3.0
```

**Para que serve:**
- Operador sabe qual versão um projeto está rodando sem ler todo HANDOFF.
- Agente Claude, ao entrar no projeto, lê `.percus-version` e sabe quais regras valem (R1–R19 da v6.x, R14–R18 ainda não existem em v4.x, etc).
- Comando `UPGRADE_PARA_FASE6.md` (e futuros UPGRADE_*) atualiza esse arquivo ao concluir o upgrade — então um diff em git mostra exatamente quando o projeto migrou.
- `analyze-council-spend.py` e futuras ferramentas de catalog podem agregar projetos por versão.

---

## Versões do canon Percus (histórico)

| Versão | Marco | Data | Mudanças principais |
|---|---|---|---|
| **6.5.2** | Patch: UPGRADE_PARA_FASE6 e descriptions consistentes | 2026-05-17 | Header/instruções de `UPGRADE_PARA_FASE6.md` ainda mencionavam v6.4.0/v6.3.0 — migrados pra "versão canônica atual em CANON_VERSION.md" ou placeholder `vX.Y.Z`. `plugin.json` e `marketplace.json` descriptions alinhados com a versão real (estavam stuck em "Fase 6 v6.5.0" desde o bump pra v6.5.1, causando UI Manage Plugins mostrar versão antiga). |
| 6.5.1 | Patch: refs operacionais desatualizadas → `CANON_VERSION.md` | 2026-05-17 | Limpeza de 4 refs vagas de versão (pré-requisitos de comandos apontando pra versões intermediárias). Operacionais viraram "ver `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`"; refs históricas ("feature introduzida em vN.N.N") mantidas intactas. |
| 6.5.0 | Canon portável | 2026-05-17 | `PERCUS_CANON_DIR` env var (User-scope) substitui hardcode `D:\Claud Automations\_Novo_Projeto` em 28 arquivos (comandos, templates, scripts, skills, hooks). `SETUP_NOVA_MAQUINA.md` (novo) automatiza bootstrap em máquina nova: git clone + env vars + verificação. Canon agora funciona de qualquer path absoluto — não mais dependência de estrutura `D:\Claud Automations\...` específica da máquina do operador principal. Resolve "outro computador não tem D:\Claud Automations\\_Novo_Projeto, todos os comandos quebram". |
| 6.4.0 | DX e versionamento | 2026-05-17 | `CANON_VERSION.md` canônico + `.percus-version` por projeto (declara versão adotada); protocolo de 1º turno no `CLAUDE.template`. `SKILLS_VS_COMMANDS.md` (novo doc) resolve confusão recorrente de agentes pedindo skills como slash commands. Seção "API keys do kit Percus" em `AMBIENTE_LOCAL_OPERADOR` (User-scope env vars eliminam `.env` recorrente em cada projeto novo). `SCOPE_COUNCIL` reescrito Fase 6 ($0.05 → $0.005 via `/council:pre-mortem` paralelo). Funções do orchestrator renomeadas pra approved PS verbs (`Measure-Tokens`, `Limit-Prompt`). |
| 6.3.0 | Eixo F entregue | 2026-05-17 | Truncation 8k orchestrator; model router automático Haiku/Sonnet/Opus por mode; wrapper Anthropic direto com cache_control; A/B router aprovado (-70% custo Cross-Claude consult); auditoria F.3 hooks zero-LLM + F.7 skill descriptions revisadas; baseline analyze-council-spend.py. |
| 6.2.0 | Eixo B Sprint 3 | 2026-05-16 | Skills tracking-audit (R2), delegate-impl (R13), security-audit (R14–R19). |
| 6.1.x | Eixo C | 2026-05-16 | Conselho 3-membros (DeepSeek + Groq-Llama + Cross-Claude); council-orchestrator paralelo; commands `/council:consult/pre-mortem/brainstorm/drift-detect`; hook `pre-plan-exit`. |
| 6.0.0 | Eixo B Sprint 2 | 2026-05-16 | 5 hooks pre-commit (pre-commit-check, mock-scan, auth-import, migration-check, types-check); 5 skills; on-stop auto-trigger catalog-publish. |
| 5.1.0 | Fase 5 v5.1 | 2026-05-03 | Auto-trigger review pelo agente via wrapper `percus-review-auto`. Git hook nativo Layer 2 anti-bypass. |
| 5.0.x | Fase 5 v5.0 | 2026-05-02 | Skills `feature-flow` + `close-milestone`. Hooks pre-commit defesa em profundidade. |
| 4.x | Fase 4 | 2026-04 | Review cross-provider sem Codex/OpenAI — DeepSeek + Cross-Claude via plugin `percus-review`. |
| 3.x | Fase 3 | 2026-04 | Harmonização do kit + tooling. |
| 2.x | Fase 2 | 2026-03 | DeepSeek implementador (R13) + design v0/shadcn (R10). |
| 1.x | Fase 1 (DEPRECATED) | 2026-03 | Codex como revisor cross-provider — descontinuado por custo. |

---

## Como saber se um projeto está na versão atual

Compare:

```bash
# Versão canônica
type "${env:PERCUS_CANON_DIR}\CANON_VERSION.md" | findstr "Versão canônica"

# Versão do projeto (na raiz do projeto-alvo)
type .percus-version
```

Se divergir → rode `comandos/UPGRADE_PARA_FASE6.md` (ou versão mais recente quando publicarmos Fase 7).

---

## Convenção de versionamento

Semver:
- **MAJOR** (`6.x.x` → `7.x.x`): nova Fase do canon. Migration runbook obrigatório. Mudanças breaking nas regras R*.
- **MINOR** (`6.3.x` → `6.4.x`): nova capacidade dentro da Fase (novo Eixo entregue, nova skill, novo hook). Compatível pra trás.
- **PATCH** (`6.3.0` → `6.3.1`): bugfix, doc fix, refactor sem mudança de comportamento. Skill descriptions ajustadas, audit fixes.

Tag no git do `huboperacional/percus-kit` sempre bate com `plugin.json` versão.
