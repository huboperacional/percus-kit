# Canon Percus — versão atual

**Versão canônica em `huboperacional/percus-kit`:** `6.11.0`

> Esta versão refere-se ao **kit Percus completo** (canon `_Novo_Projeto/` + plugin `percus-review`). Os dois são sincronizados via tag no repo `huboperacional/percus-kit`. Quando você lê `plugin.json` versão X, o canon na pasta `_Novo_Projeto/` daquela tag também é versão X.

---

## Changelog v6.11.0 — 2026-05-30

**Limpa cosmética do canon + template canônico de `.claude/settings.json`.**

Fase 1 do plano v6.11.0→v7.0.0 ([acabei-de-perceber-que-quirky-toast.md](D:/Claud Automations/.claude-home/plans/acabei-de-perceber-que-quirky-toast.md)) — refactor incremental do canon. Esta release é cosmética + setup canônico de settings; zero breaking pros consumidores.

**Consolidação AUTH (3 → 1 arquivo):**
- `PADRAO_AUTH_SERVICE_INTEGRATION_V2.md` → renomeado para `PADRAO_AUTH_SERVICE.md` (versionamento volta pro git, sai do nome de arquivo).
- `AUTH_SERVICE_PATTERNS_LEARNED_2026-05-15.md` → removido (já absorvido na Seção I do consolidado desde v6.9.x).
- `REVIEW_AUTH_INTEGRATION_2026-05-15.md` → removido (review de momento da sessão 35; decisões já refletidas no consolidado).
- Refs atualizadas em: `01_REGRAS_INEGOCIAVEIS.md`, `checklists/CHECKLIST_AUDIENCE_NOVA.md`, `comandos/COMANDO_PROJETO_NOVO.md`, `docs/contracts/{error-codes,redirect-reasons,MIGRATION_V1_TO_V2}.md`.

**Stale removidos da raiz** (artefatos operacionais de sessão, não canon — git history preserva conteúdo):
- `_AUDIT_2026-05-15.md`, `_AUDIT_2026-05-17_eixo-f.md`, `_AUDIT_2026-05-17_eixo-f-pos-entrega.md`
- `baseline-2026-05-17.md`, `baseline-2026-05-17-v2.md` (eram untracked)
- `diagnostico-disco-c-2026-05-15.md`

**NOVO — template canônico de settings:**
- `templates/settings.template.json` — `bypassPermissions` + `allow:*` (mode operador único Rodrigo), `additionalDirectories` portáveis (`${env:USERPROFILE}` em vez de placeholder), `enableAllProjectMcpServers: true`, 3 hooks padronizados (SessionStart GATE INICIO / UserPromptSubmit GATE VISUAL com regex refinada / Stop ENCERRAMENTO).
- `comandos/SETUP_CLAUDE_SETTINGS.md` — runbook passo-a-passo de aplicação em projeto novo OU existente, incluindo drift detection e anti-padrões.
- **GATE VISUAL regex** refinada após observar falsos-positivos recorrentes na sessão de planejamento desta release: era `(landing page|p[aá]gina inicial|redesign|...|paleta|layout novo)` — disparava em qualquer menção genérica de design; agora `(gerar (mockup|wireframe|design)|criar tela nova|redesenhar.*(p[áa]gina|tela)|v0\.dev|claude\.ai/design|hero section|reestilizar.*UI|landing page (nova|do zero)|mockup do figma)` — exige verbo de criação + objeto visual concreto.
- **GATE INICIO + ENCERRAMENTO** agora explicitam "Se eh canon/lib/tooling, ignore." pra silenciar ruído em sessões onde `HANDOFF.md`/`docs/PLANO.md` não existem (canon próprio, libs, tooling).

**00_LEIA_PRIMEIRO.md** ganha 2 linhas novas na tabela de roteamento:
- "Configurar `.claude/settings.json` canônico" → `comandos/SETUP_CLAUDE_SETTINGS.md`
- "Integrar com `auth-service`" → `PADRAO_AUTH_SERVICE.md`

**NÃO incluído nesta release** (deliberadamente):
- `COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md` permanece na raiz do canon — é handoff destinado ao Plexco Coach. Operador reforçou (2026-05-30): nunca tocar em projetos fora do CWD; mecanismo canônico é entregar caixa de texto pro operador colar manualmente. Caixa será entregue ao fim desta release; arquivo será deletado em v6.11.1 após confirmação.
- `templates/login-ui/` permanece intacto — análise revelou que pasta tem só 21 arquivos tracked (o "3155" inicial era `node_modules/` untracked). Login-ui é canon legítimo, alinhado com `auth-service/libs/node` via `@percus/auth`.

**Refs aprovação:**
- Plano completo: `D:/Claud Automations/.claude-home/plans/acabei-de-perceber-que-quirky-toast.md`
- Conselho consult cascata 3 níveis (2026-05-30 11:38): consenso 2/2 Opção A.
- Conselho pre-mortem do plano original (2026-05-30 11:42): identificou riscos críticos endereçados nesta versão (cascata virou experimento condicional; login-ui mantido; enforcement sem promoção automática).
- Conselho consult otimização Groq (2026-05-30 11:55): Vetor B + D adotados pra v6.14.0 (paralelo); Vetor A + C descartados.

---

## Changelog v6.10.0 — 2026-05-26 (noite)

**R22 v2 — bloco de 20 portas + range expandido 3000-9999.**

Decisão: bloco de 10 portas era apertado pra projeto full-stack real (Vite + Storybook + Playwright + backend FastAPI + worker + Postgres local + Redis local consomem 7-8 offsets, quase zero margem). Bumpamos para **20 portas/projeto** e expandimos range global de `3100-4090` (100 projetos) para `3000-9999` (~349 projetos).

**Breaking — todos os projetos já alocados foram re-alocados.** Snapshot pré-v6.10 (`painel-gestao` 3100, `tiatendo` 3110, etc.) virou (`painel-gestao` 3000, `tiatendo` 3020, etc.). Operador precisa re-rodar `/percus-review:port-allocate` em cada projeto, atualizar `.env` e configs (vite/next/compose). Documentado em `docs/handoffs/HANDOFF_CONSUMIDORES_v6.10.md`.

**Cross-repo Painel:** mudanças no Painel ficam descritas em `docs/handoffs/HANDOFF_PAINEL_v6.10.md` — canon **não** comita lá (cross-repo write protocol). Operador aplica manualmente:
- Migration nova (drop CHECK antigo, zera `port_base`, re-aloca por `ORDER BY id`, novo CHECK `BETWEEN 3000 AND 9980 AND port_base % 20 = 0`).
- `catalogEngine.py:77-79` constantes (`PORT_ALLOC_RANGE_START=3000`, `PORT_ALLOC_RANGE_END=9980`, `PORT_ALLOC_BLOCK_SIZE=20`).
- `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` snapshot + seção concorrência explícita.
- Tests `test_portAllocate.py` ajustados pros novos números.

**Concorrência (documentada explicitamente):** o endpoint já era seguro via `pg_advisory_xact_lock(4242)` + UNIQUE INDEX `uq_projects_port_base`. 2 consultas simultâneas do mesmo slug → mesmo `port_base` (idempotência). 2 consultas simultâneas de slugs distintos → blocos distintos garantidos pelo lock; UNIQUE INDEX é rede de segurança. Nada muda no código — só fica documentado pra agentes/consumidores não duvidarem.

**Canon — arquivos tocados nesta release:**
- `01_REGRAS_INEGOCIAVEIS.md` R22 — bloco 20, range 3000-9999, tabela de 12 offsets nomeados + reserva, seção "Garantia de unicidade sob concorrência".
- `02_INFRA_E_STACK_PERCUS.md` §5.5 — mesma tabela, exemplos atualizados (port_base=3140 next free).
- `plugin/percus-review/skills/port-allocate/SKILL.md` — banner breaking v6.10, exemplos com tiatendo 3020·3039.
- `plugin/percus-review/scripts/port_allocate.py` — `BLOCK_SIZE=20`, `RANGE_START=3000`, `RANGE_END=9980`, fallback ajustado.
- `docs/handoffs/HANDOFF_PAINEL_v6.10.md` (novo) — passo-a-passo pra aplicar no Painel.
- `docs/handoffs/HANDOFF_CONSUMIDORES_v6.10.md` (novo) — passo-a-passo pra cada projeto consumidor re-alocar.

**Snapshot real pós-migration** (ordem por `id` UUID divergiu do otimista do handoff — verdade do banco):

| slug | port_base | range |
|---|---|---|
| familia-milionaria | 3000 | 3000·3019 |
| ghl-evolution | 3020 | 3020·3039 |
| robo-vendas | 3040 | 3040·3059 |
| zap-disparador | 3060 | 3060·3079 |
| tiatendo | 3080 | 3080·3099 |
| painel-gestao | 3100 | 3100·3119 |
| social-midia | 3120 | 3120·3139 |

**Próximo bloco livre:** 3140·3159.

**Deploy Painel confirmado:** imagem `ads4pros-api:fase7-20260526b` (sha `39fc67b49cd7`) vivo em prod. Commits Painel: `db8f3d6` (feat R22-v2) + `5eb9664` (docs snapshot real). Smoke E2E ok: `/health` 200, `port-allocate` idempotente, bloco-de-20 confirmado por `kind:new` saltar de 3120→3140. Backup `pg_dump --data-only -t projects` salvo na VPS antes da migration (rollback procedure no §4 do handoff Painel).

---

## Changelog v6.9.1 — 2026-05-26 (tarde)

**Sync com Painel pós-deploy R22.**

Após a sessão Painel deployar a v6.9.0 em prod (imagem `ads4pros-api:fase7-20260526a`, endpoint vivo, 7 projetos já alocados de 3100 a 3169), a Painel publicou `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` consolidando o padrão operacional real. O canon-side estava com 3 desvios em relação ao guia operacional:

1. **Tabela de offsets divergente.** Canon v6.9.0 pensava em "full-stack" (`+0` front, `+1` back, `+2` worker, `+3` admin UI, `+4` mailhog). Painel mapeou ferramentas reais do dev frontend Vite (`+0` dev server, `+1` preview, `+2` Storybook, `+3` Playwright UI, `+4` mock/MSW, `+5` outro daemon). Como a stack default Percus é Vite + frontend e a convenção é **sugestão** (não trava), o canon foi alinhado com a Painel. Full-stack continua livre pra mapear `+1` como backend em `docs/PORTS.md` do projeto.
2. **`strictPort: true` não era pré-requisito explícito.** Sem isso o Vite cai pra ephemeral e a alocação não tem efeito — exatamente o bug que motivou R22. Agora obrigatório em R22 gate 4.
3. **Estado do endpoint vago.** Canon ainda dizia "fallback é default" — invertido: endpoint vivo é o padrão, fallback é exceção rara.

Arquivos sincronizados em [commit a confirmar]:
- `01_REGRAS_INEGOCIAVEIS.md` R22 — tabela de offsets, `strictPort: true` no gate, referência ao consumer guide, anotação de auditoria visual via `gestao.ads4pros.com/projetos.html`.
- `02_INFRA_E_STACK_PERCUS.md` §5.5 — mesma tabela, exemplos de config alinhados (Vite strictPort, Next `--port`, Storybook `-p`, Playwright `--ui-port`).
- `plugin/percus-review/skills/port-allocate/SKILL.md` — exemplos por stack, referência ao consumer guide, badge UI.
- `plugin/percus-review/scripts/port_allocate.py` — docstring atualizada (endpoint vivo, fallback como exceção).

**Próximo bloco livre no momento desta release:** 3170. 7 projetos já alocados (snapshot vivo em [gestao.ads4pros.com/projetos.html](https://gestao.ads4pros.com/projetos.html)).

**Roadmap v6.10+** (registrado pelo guia Painel, ainda fora de escopo):
- Expandir constraint `chk_projects_port_base_range` quando passar de 100 projetos.
- Liberação de bloco quando projeto é desativado (hoje a coluna fica órfã).
- Dashboard de detecção de colisões via `lsof -i :PORT` em healthcheck local.

Princípio reforçado pela sincronização: **quando canon e Painel divergem em ponto operacional, Painel vence** — é o que está vivo em produção. Canon documenta o "porquê"; Painel documenta o "como agora".

---

## Changelog v6.9.0 — 2026-05-26

**R22: alocação central de portas locais via Painel.**

Bug: dois projetos Percus colidiram na porta `52924` (ephemeral atribuído por
Vite/Node sem `strict-port`). Causa estrutural: Far-West de portas — cada projeto
inventava as suas (3000 Next + 8000 FastAPI + 5273 Vite + 3100 Node + ...), sem
padrão cross-projeto.

**Solução: source of truth no Painel + bloco de 10 portas por projeto.**

Cada projeto Percus recebe um `port_base` único alocado pelo Painel (`projects.port_base INT UNIQUE` partial). Bloco de 10 portas cobre frontend (+0), backend (+1), worker (+2), reserva (+3..+9). Range global 3100-4090 = 100 projetos.

**Lado Painel** (cross-repo, autorizado em voz alta nesta execução; ver plano `analisa-essa-devolutiva-e-floofy-candy.md`):

- Migration `execution/database/migration_port_base.sql`: `ALTER TABLE projects ADD COLUMN port_base INT NULL` + UNIQUE index parcial + CHECK constraint do range.
- Engine `allocatePortBase(slug, name)` em `execution/engine/catalogEngine.py`: idempotente, serializado via `pg_advisory_xact_lock`, auto-cria projeto se name fornecido.
- Endpoint `POST /admin/projects/port-allocate` em `execution/api/catalogRoutes.py`: header `X-Internal-Auth` (mesma key de `/admin/catalog/ingest`).
- Tests integration em `tests/test_portAllocate.py` (cobertos: auto-create, idempotência, alocação sequencial, erro sem name).
- **Pendência operador:** aplicar migration na VPS (`psql ... -f migration_port_base.sql`) e reiniciar API container.

**Lado canon** (escopo deste commit):

- Skill `percus-review:port-allocate` para projetos novos + migração de legados.
- Wrapper `plugin/percus-review/scripts/port_allocate.py` (Python primary, mesmo padrão de `catalog_publish.py`):
  - Consulta Painel; fallback `hash(slug) % 100 → 3100 + hash*10` se offline.
  - Cache local `.percus-ports.json` versionado em git (`unverified: true` se fallback).
  - Idempotente; cache hit verified faz short-circuit.
- R22 em `01_REGRAS_INEGOCIAVEIS.md` + anti-padrões 29-30 na lista.
- Seção 5.5 em `02_INFRA_E_STACK_PERCUS.md` com tabela canônica de offsets.
- Passo 2.5 em `comandos/COMANDO_PROJETO_NOVO.md` (alocar port_base após templates).

**Pre-mortem do conselho** (DeepSeek + Llama; Cross-Claude falhou 400 nesta rodada — consenso 2/2):

- **Risco crítico identificado e mitigado:** plano original entregava canon antes da Painel, deixaria a ferramenta quebrada. Mitigação: ordem invertida — Painel-side primeiro, canon-side depois.
- Riscos aceitos como dívida documentada: hash collision ~1% (reconcile detecta); merge conflict em `.percus-ports.json` offline em branches paralelas (git força resolução); resistência adoção legados (1 projeto-piloto serve de exemplo).

**Próximos passos (operador, fora deste commit):**

1. Aplicar `migration_port_base.sql` na VPS + reiniciar API (Painel).
2. `curl -X POST .../admin/projects/port-allocate -d '{"slug":"test-foo","name":"Test Foo"}'` → confirmar `{port_base: 3100, ...}`.
3. Rodar `port-allocate` em 1 projeto piloto (Plexco Tasks recomendado), ajustar `vite.config` + `docker-compose` para usar `process.env.PERCUS_PORT_BASE`.
4. Documentar exemplo do piloto em UPGRADE_PARA_FASE8 (futuro).

---

## Changelog v6.8.4 — 2026-05-23

**Fix(deepseek-review): `curl` argv mangla UTF-8 em git-bash Windows + AGENTS.md tolerante a CP1252.**

Bug: o pre-commit hook quebrava com `messages[0].content: invalid unicode code
point at line N col M` da API DeepSeek. Reproduzido nesta própria sessão durante
implementação do fix — mesmo SEM `AGENTS.md` presente, o erro acontecia, o que
descartou a hipótese inicial de que era só encoding de `AGENTS.md`.

**Root cause real (descoberto via reprodução ao vivo):** o `curl` 8.18 do git-bash
recebe argv via Windows API (`CreateProcessW`), que reencoda UTF-8 → CP1252 → UTF-8
e quebra sequências multi-byte (`Você`, `código`, `padrão`, etc.) que existem no
próprio `SYSTEM_PROMPT` do script. O body JSON sai válido do `jq`, mas chega
corrompido na API. Teste empírico: passar o mesmo body via `--data-binary @file`
ou stdin funciona perfeito; via `--data-binary "$BODY"` (argv) falha.

Fix em [plugin/percus-review/scripts/deepseek-review.sh:126](plugin/percus-review/scripts/deepseek-review.sh):
`printf '%s' "$BODY" | curl ... --data-binary @-` — body vai por stdin, contorna
o argv mangling do Windows. Esse é o fix principal.

Fix complementar em [plugin/percus-review/scripts/deepseek-review.sh:71](plugin/percus-review/scripts/deepseek-review.sh):
normalização UTF-8 defensiva de `AGENTS.md` via `iconv` (UTF-8 com `-c`, fallback
CP1252, fallback `cat`). Mantém o pipeline robusto se o `AGENTS.md` do
projeto-cliente também estiver fora de UTF-8 — independente do argv mangling.

Fix simétrico em [plugin/percus-review/scripts/deepseek-review.ps1:76](plugin/percus-review/scripts/deepseek-review.ps1):
`Get-Content -Encoding UTF8` explícito com fallback CP1252. A `.ps1` já passava o
body por `Invoke-RestMethod -Body $bodyBytes` (bytes UTF-8 explícitos, L113), então
o caminho do argv mangling não a afeta — só a leitura do `AGENTS.md` precisava de
guard.

**Decisão do conselho** (`/percus-review:council-consult` com DeepSeek + Llama):
consenso 2/2 em "normalização defensiva" (sobre o pedaço do `AGENTS.md`). O fix
real (argv → stdin) emergiu durante teste de fumaça, após o conselho. Ambos os
caminhos ficaram no v6.8.4 porque cobrem causas distintas do mesmo sintoma.

**Lição registrada:** rodar o próprio `deepseek-review.sh` localmente antes de
declarar fix completo. O bug foi reproduzido apenas porque tentei satisfazer o
hook de R11 e o script falhou em ambiente local — sem isso, teria comitado
"fix-AGENTS.md-CP1252" sem ter corrigido o caminho principal.

**Não inclui** (registrado como follow-up v6.8.5): melhorar mensagem de erro
quando `curl` retorna 400 do DeepSeek — hoje só diz "chamada API falhou", deveria
exibir o body pra debug ser segundos em vez de minutos.

---

## Changelog v6.8.3 — 2026-05-20

**Novo comando `/percus-review:version`.**

`commands/version.md` — comando que mostra a versão do plugin `percus-review`
instalado na sessão atual, o changelog condensado, e — se o canon estiver
alcançável (`$PERCUS_CANON_DIR` ou path padrão) — compara com `.percus-version`
e sinaliza drift (ex: "plugin instalado v6.8.0 mas canon já em v6.8.3 — atualize
pela UI do marketplace").

Motivação: a skill foi adiada 2× (v6.7.0, v6.7.2) com a nota "re-avaliar se
houver 3ª ocorrência de confusão de versão". As ocorrências chegaram — incidente
v6.7.0-vs-v6.7.1 (memória `check-origin-before-resume`) + o cache do plugin
ficando defasado do canon durante a própria Sprint v6.8. O comando torna o drift
visível sob demanda em vez de exigir leitura manual do `CANON_VERSION.md`.

`disable-model-invocation: true` — é comando de operador, não auto-invocável.

---

## Changelog v6.8.2 — 2026-05-20

**Smoke v6.8 — corrige nome da lib nos templates e scaffold.**

Smoke ponta-a-ponta dos entregáveis da Sprint v6.8 (Frente B `templates/login-ui/`
+ Frente C `scaffold-percus-project`) rodando o scaffold contra um projeto Next.js
real. Dois bugs encontrados:

1. **Nome da lib errado.** A lib Node real é `@percus/auth` (scoped), com toda a
   API de tenant (`useTenant`, `TenantProvider`, `getTenantConfig`, `TenantConfig`)
   exportada do **export root**. Os templates e o scaffold importavam
   `percus-auth/tenant` — pacote unscoped + subpath `/tenant` que não existe no
   `exports` da lib. **Todo projeto scaffoldado quebraria na resolução de import.**
   Origem: o plano da Frente D assumiu `percus-auth` unscoped; Frentes B/C
   herdaram. Fix: `percus-auth/tenant` → `@percus/auth` em `login-card.tsx`,
   `support-link.tsx`, `vitest.config.ts`, `login-card.test.tsx`, stub,
   `README.md`, `scaffold-percus-project.ps1/.sh` (`npm install @percus/auth`),
   e nos code-blocks de `MIGRATION_KIT_AUTH.template.md` (`@percus/auth/express`,
   `@percus/auth/next`). Lib Python segue `percus-auth` (correto — pip).
2. **`.env.example` incompleto.** O passo 6 do `README.md` (mount do
   `TenantProvider`) lê `NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK` e
   `NEXT_PUBLIC_PERCUS_PRODUCT_FALLBACK`, mas o `.env.example` não as definia
   (o scaffold já tinha a substituição, sem alvo). Adicionadas.

Scaffold validado: re-scaffold produz `import { useTenant } from "@percus/auth"`.
Template login-ui: 10/10 testes vitest verdes.

---

## Changelog v6.8.1 — 2026-05-20

**Fix mock-scan — falso-positivo R3 em palavras acentuadas.**

Sintoma: durante a Sprint v6.8 Frente B, o hook `mock-scan` bloqueou um commit
legítimo flagrando `aria-label="Método de login"` como "TODO/FIXME/XXX/HACK
pendente" — a palavra portuguesa "mé**todo**" contém "todo".

Causa raiz (dupla):
1. `Get-PercusStagedContent` (`_helpers.ps1`) lia o output do `git show` com a
   codepage OEM (cp850/cp437) em vez de UTF-8. O "é" (UTF-8 `C3 A9`) virava 2
   bytes não-word → criava uma word-boundary falsa antes de "todo".
2. O padrão `\b(?:TODO|FIXME|XXX|HACK)\b[: ]` casava case-insensitive (default
   do `-match`/`grep -i`), então "todo" minúsculo dentro de "método" casava.

Fix:
- `Get-PercusStagedContent` força `[Console]::OutputEncoding = UTF8` ao ler o git.
- Markers viram **case-sensitive** via grupo `(?-i:TODO|FIXME|XXX|HACK)` nos dois
  hooks (`.ps1` e `.sh`) — TODO/FIXME/XXX/HACK são convenção maiúscula; matching
  insensível era a causa latente. Markers reais (`// TODO:`, `# FIXME `) seguem
  bloqueando.
- `mock-scan-pre-commit.ps1` ganha dual stdin path (`[Console]::In` + fallback
  `$input`), igual ao `pre-commit-check.ps1` — torna o hook testável via Pester.
- Comentário obsoleto em `external-action-guard.ps1` removido ("F3 Sprint 2" —
  F3 entregue na v6.7.0).
- Novo `tests/mock-scan.tests.ps1` — 6 testes de regressão. Suite: 72/72.

---

## Changelog v6.8.0 — 2026-05-20

**Sprint v6.8 — Canonização do padrão auth** (5 frentes paralelas A-E).

**Breaking changes:**
- R7.5: audience naming **MUST** ser kebab-case. Audiences legadas com underscore precisam ser migradas via `UPGRADE_PARA_FASE7.md`.
- Lib `percus-auth` bump 0.3.x → 0.4.0 (novos hooks `useTenant`/`TenantProvider`).
- Schema `auth.audiences` ganha 8 colunas (branding + origins + alias_slugs).

**Novidades:**
- Endpoint público `GET /tenants/by-origin` no auth-service (rate-limited).
- Templates `templates/login-ui/` canônicos extraídos do Plexco Tasks (parametrizado por tenant).
- Script `tools/scaffold-percus-project.ps1`/`.sh` idempotente.
- `COMANDO_PROJETO_NOVO.md` aciona scaffold + checklist humano.
- `UPGRADE_PARA_FASE7.md` novo.
- R7.5 (kebab-case enforcement) + R7.6 (tenant detection) cravadas no canon.

**Refs:**
- Spec: [docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md](docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md)
- Planos: [docs/superpowers/plans/2026-05-19-sprint-v6.8-frente-*.md](docs/superpowers/plans/)

---

## Changelog v6.7.2 — 2026-05-19

**Cross-repo R11 + diagnostic hardening** (pós-incidentes consolidados 2026-05-19).

Contexto: sessão Plexco Tasks reportou dois incidentes além do incidente 2026-05-18 já endereçado em v6.7.0:
- **Incidente 2** (wrapper auto-rename + branch autônoma): plugin v6.7.1 já não reproduz — `hooks.json` não registra `PostToolUse:Edit` e nenhum script cria branches. Coberto agora por **invariantes de teste** que falham se essa propriedade regredir.
- **Incidente 3** (hook freshness lê CWD em vez de git toplevel, quebra R11 cross-repo): **corrigido**.

**Mudanças:**

- **Proposta F (hook cross-repo):** `hooks/pre-commit-check.ps1` e `.sh` parseiam `cd <dir> && git commit` e `git -C <dir> commit` do comando, resolvem `git rev-parse --show-toplevel` do target, e procuram `.deepseek/reviews/` no repo TARGET — não no CWD do agente. Cross-repo work (CWD do agente ≠ repo do commit) passa a respeitar R11 sem workaround "cópia placeholder review".
- **Proposta G (diagnostic):** mensagens de bloqueio do hook incluem `git root: <repo>`, `searched: <path>` e `cwd: <path>` (este último apenas quando difere do git root). Operador/agente sabe imediatamente se erro é cross-repo, missing review, ou path-resolution.
- **Invariante D+E (regressão):** `tests/hardening-2026-05-19.tests.ps1` falha o build se:
  - `hooks.json` ganha entrada `PostToolUse` (qualquer matcher), ou
  - qualquer hook `PreToolUse` declara matcher `Edit|Write|MultiEdit|NotebookEdit`, ou
  - qualquer `.ps1`/`.sh`/`.cmd` em `scripts/hooks/skills/commands` contém `git checkout -b`/`git switch -c`/`git branch <novo>`.
- **`.percus-version`** atualizado: estava parado em `6.5.2` (não estava no loop de validação pre-push) → `6.7.2`.

**Decidido NÃO fazer agora:** skill `/percus-review:version` (bonus do doc 2026-05-19). Operador hoje lê `CANON_VERSION.md`; adicionar skill inflaria surface area sem incidente claro. Re-avaliar se houver terceira ocorrência de confusão de versão.

**Council consultado (3/3 Opção A):** DeepSeek + Llama + Cross-Claude concordaram com o escopo (F+G+invariante D/E, adiar skill version). Cross-Claude destacou: "F sem G deixa hook em modo fallback silencioso — viola R14 (observabilidade estruturada)". Por isso F e G entraram no mesmo bump.

---

## Changelog v6.7.1 — 2026-05-18

- **Fix marketplace.json duplicação:** `.claude-plugin/marketplace.json` (raiz, fonte única consumida pela UI) estava parado em `6.5.2` enquanto `plugin/.claude-plugin/marketplace.json` (duplicado órfão) era bumpado a cada release. Causa raiz de 3 incidentes recorrentes em v6.6.0/v6.6.1/v6.7.0.
- Deletado `plugin/.claude-plugin/marketplace.json`. Fonte única passa a ser raiz.
- **Pre-push hook (`tools/hooks/pre-push`):** bloqueia `git push` se `marketplace.json` vs `plugin/percus-review/plugin.json` divergem em versão, ou se duplicação ressurgir. Install via `tools/hooks/install.sh`.

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
