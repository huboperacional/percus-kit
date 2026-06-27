---
tipo: regras-universais
prevalece-sobre: [02_INFRA_E_STACK_PERCUS, comandos/*, templates/*]
prevalecido-por: [CLAUDE.md do projeto atual]
quando-usar: SEMPRE que executar trabalho em projeto Percus
leitura: 10 min
ultima-atualizacao: 2026-05-06
---

# 01 — Regras Inegociáveis

> Cada regra abaixo tem **gate verificável**. Se você não consegue verificar, a regra não foi cumprida — não invente que cumpriu.
> Ordem das seções por frequência de uso, não por importância.

---

## Status de enforcement (Fase 6+)

A partir da Fase 6, cada regra tem **um dos três tipos de reforço**:

- 🤖 **Hook automático** (regex/AST/grep, zero custo de LLM, latência <1s) — bloqueia commit/stop sem perguntar.
- 🔧 **Skill invocável** (LLM-assisted) — Claude ou operador aciona via comando.
- 📖 **Só doc** — princípio/padrão sem enforcement mecânico, gate é humano.

Tabela rápida — quem usa o quê:

| Regra | Tipo Fase 6 | Onde mora o enforcement |
|---|---|---|
| R1 (CRUD `[0]→[5-T]`) | 📖 + 🔧 | skill `percus-review:feature-flow` |
| R2 (tracking 15 campos) | 🔧 | skill `percus-review:tracking-audit` (NOVO Fase 6) |
| R3 (zero mock) | 🤖 | hook `mock-scan-pre-commit` (NOVO Fase 6) |
| R4 (credenciais — pare) | 📖 | humano |
| R5 (tipos explícitos) | 🤖 | hook `types-check-pre-commit` (NOVO Fase 6) |
| R6 (migrations Alembic) | 🤖 | hook `migration-check-pre-commit` (NOVO Fase 6) |
| R7 (auth-service Percus) | 🤖 + 📖 | hook `auth-import-pre-commit` (NOVO Fase 6) + texto |
| R8 (HANDOFF atualizado) | 🤖 | hook `on-stop-check` (extendido Fase 6: também invoca catalog-publish) |
| R9 (superpowers) | 📖 + 🤖 (existente) | hooks Layer 1+2 já existem |
| R10 (design v0.dev/shadcn) | 📖 | humano + `comandos/DESIGN_WORKFLOW.md` |
| R11 (review cross-provider) | 🤖 | hook `pre-commit-check` (extendido Fase 6: 3 membros DeepSeek+Cross-Claude+Llama) |
| R12 (meta-regra de gate) | 📖 | estrutural |
| R13 (delegate to DeepSeek) | 🔧 | skill `delegate-impl` (NOVO Fase 6) |
| R14 (observabilidade tier-1) | 📖 + 🔧 (opt-in) | texto + skill `security-audit` |
| R15 (rate limit IPv6/64) | 📖 | texto + smoke test descrito |
| R16 (SSO multi-domínio) | 📖 | lib `percus-auth` |
| R17 (magic links centralizado) | 📖 | auth-service `/auth/magic/*` |
| R18 (tracking ≠ auth) | 📖 | princípio de separação |
| R19 (identidade canônica) | 📖 | `OWNERSHIP.md` |
| R20 (ação externa pública — gate operador) | 📖 + 🤖 (v6.7.0+) | hook `external-action-guard.ps1` (NOVO v6.7.0) |

Conselho expandido em `06_CONSELHO_PERCUS.md`.

---

## Convenção de paths neste arquivo

Paths citados nas regras seguem duas formas:

- **Path absoluto** (`${env:PERCUS_CANON_DIR}/...`): aponta para arquivo do **kit Percus** (regras, templates, comandos, scripts auxiliares). NÃO existe no repo do projeto que está sendo revisado — é referência cross-projeto. Vale para toda regra que entra em `AGENTS.md` via transclusão (R10, R11, R13).
- **Path relativo** (`docs/...`, `HANDOFF.md`, `CLAUDE.md`): aponta para arquivo **dentro do repo do projeto atual**. É criado pelos templates do kit no setup inicial.

**Para revisores não-Claude (DeepSeek, etc.):** se um path absoluto começando com `${env:PERCUS_CANON_DIR}/` for citado, **NÃO** trate como referência morta no repo do projeto — é arquivo do kit, fora do repo, propositalmente externo.

### Config dir do Claude Code (`CLAUDE_CONFIG_DIR`)

Em máquinas Percus o Claude Code roda com `CLAUDE_CONFIG_DIR=D:\Claud Automations\.claude-home\` (custom), **não** o default `~/.claude/`. Plugins instalados a nível de usuário (`percus-review@percus-tools`, `superpowers`, etc.) ficam em `D:\Claud Automations\.claude-home\plugins\` e o registro autoritativo é `D:\Claud Automations\.claude-home\settings.json` (campo `enabledPlugins`).

**Ao diagnosticar instalação de plugin, sempre detectar o path real:**

```powershell
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
```

Hardcodar `~/.claude/` ou `$env:USERPROFILE\.claude` dá **falso-negativo** — plugin aparece "ausente" mesmo estando enabled e ativo. Erro real ocorrido em diagnóstico de upgrade Fase 5.

---

## R1. Critério único de "feito" para feature: ciclo CRUD com F5

**Regra:** Uma feature SÓ está em `[5-T]` quando:
```
Criar X → F5 (dado continua?) → Editar X → F5 (mudou?) → Deletar X → F5 (sumiu?)
```

**Gate de verificação:** Se você não rodou as 6 ações nesta sessão, a feature **não é** `[5-T]`. Marque `[4-C]` no máximo.

**Build passando ≠ feito. Tela abrindo ≠ feito. Endpoint respondendo no Postman ≠ feito.**

---

## R2. Tracking de status — atualização imediata

**Regra:** Cada feature do projeto tem uma tag de status. Atualize **imediatamente** ao concluir cada etapa, não no fim da sessão.

| Tag | Significado | Condição obrigatória para avançar |
|-----|-------------|-----------------------------------|
| `[0]` | Planejada | — |
| `[1-S]` | Schema | Migration rodou, tabela existe no banco (verificar com `\dt` ou query) |
| `[2-E]` | Endpoint | Rota responde 2xx em curl/log (verificar com curl) |
| `[3-H]` | Hook | Frontend chama o endpoint sem erro (verificar com network tab) |
| `[4-C]` | Componente | Tela renderiza dado real do banco (verificar olhando a tela) |
| `[5-T]` | Testado | R1 cumprida (ciclo CRUD com F5) |

**Onde atualizar:** `docs/PLANO.md` do projeto (fonte da verdade) E `HANDOFF.md` ao encerrar sessão.

**Gate de verificação:** Se você avançou status sem checar a condição, você violou R2. Volte e verifique.

**Regra de profundidade > largura:** Não inicie feature nova enquanto outra da mesma frente estiver entre `[1-S]` e `[3-H]`. Não acumule features pela metade.

### Evidência de `[5-T]`: trailer `CRUD-verified` (enforcement v6.12.0+)

O commit que transiciona uma feature para `[5-T]` **SHOULD** conter o trailer `CRUD-verified: YYYY-MM-DD HH:MM` — a prova, no histórico git, de que o ciclo CRUD com F5 (R1) foi rodado de fato, não arredondado de `[4-C]`.

```
git commit -m "feat(x): finaliza feature Y" -m "CRUD-verified: 2026-05-30 14:32"
```

Dois hooks do plugin `percus-review` cuidam disso (sem promoção automática warn→block — decisão registrada no plano v6.11→v7.0):
- **`crud-evidence-warn`** (pre-commit, **warn-only**): avisa quando um `[5-T]` é adicionado a `PLANO.md`/`HANDOFF.md` sem o trailer. Não bloqueia. Skip: `PERCUS_SKIP_CRUD_WARN=1`.
- **`state-drift-check`** (on-stop, **bloqueia**): impede encerrar a sessão se `docs/PLANO.md` (fonte da verdade) e `HANDOFF.md` divergem no status de alguma feature. Skip: `PERCUS_SKIP_DRIFT_CHECK=1` (declarar motivo em voz alta).

A skill `percus-review:feature-flow` atualiza PLANO **e** HANDOFF na mesma operação ao marcar `[5-T]`, eliminando a classe de drift por origem.

### Marcações visuais (opcionais, ortogonais à tag de status)

Marcações são metadata visual — vão ANTES da tag de status no PLANO. Acumulam (uma feature pode ter várias).

| Símbolo | Significado | Quando aplicar |
|---|---|---|
| `🎨` | Draft de design aprovado (v0.dev export, shadcn add, ou wireframe) | Em features visuais — **obrigatório** antes de sair de `[0]` (R10) |
| `🎨?` | Feature visual sem draft — BLOQUEADA em `[0]` | Ao classificar feature visual ainda não desenhada (R10) |
| `🤖` | Implementação delegada ao DeepSeek (R13) | Em qualquer fase `[1-S]→[5-T]` onde o trabalho foi feito via wrapper `deepseek-impl` |
| `✓` | Reviewer aprovou no marco (não no commit individual) | Em features cujo escopo de marco passou por `/percus-review:milestone-review --base <commit>` ou `/percus-review:review` aprovado pré-commit (R11) |

**Exemplo de PLANO com marcações compostas:**
```
- [5-T] ✓ Login OTP — testado, marco aprovado
- [4-C] 🤖 Form de cadastro — implementado por DeepSeek, falta testar CRUD
- [3-H] 🎨 Tela de boas-vindas — hook OK, componente em andamento
- [0] 🎨? Página de erro 404 — bloqueada (precisa draft v0/shadcn)
```

**Por que marcações em vez de novas tags `[6-R]`/`[7-D]`:** R2 é um pipeline linear (técnico). Review cross-provider é gate cross-cutting (commit + marco), DeepSeek é mecanismo de execução. Ambos ortogonais ao pipeline — viram metadata, não fase.

---

## R3. Zero mock escondido

**Regra:** Quando algo for mock/local (sem persistência real no backend):
- Banner `MODO DEMO` visível na tela
- Toast diz `"salvo localmente"`, **nunca** apenas `"salvo"` (que implica servidor)
- Use Zustand + localStorage no mínimo enquanto backend não está conectado

**Anti-padrão proibido:** `toast.success("Salvo!")` quando o dado não foi ao servidor. Mentira para o usuário.

**Gate de verificação:** ao encerrar sessão com frontend, atualizar `docs/mock-audit.md` (template em `templates/mock-audit.template.md`). Sem auditoria atualizada, sessão não está encerrada.

---

## R4. Setup de credenciais — pare em vez de contornar

**Regra:** Se um script falha com `FileNotFoundError`/`not found` em arquivo de credencial (`credentials.json`, `token.json`, var de `.env`):
1. Identifique o arquivo/var faltando
2. **Pare imediatamente** — não crie arquivo vazio, não comente código, não pule
3. Instrua o usuário com passos exatos para obter (referência em `02_INFRA_E_STACK_PERCUS.md` Seção 7)
4. Aguarde confirmação

**Anti-padrão proibido:** "vou criar um placeholder pra continuar" — perde o erro e deixa código quebrado.

---

## R5. Confirmação obrigatória antes de operações que custam dinheiro ou são irreversíveis

**Regra:** Antes de executar:
- API call que consome créditos pagos (OpenAI, Veo, Imagen, Kling)
- DELETE em produção (database, stack, container)
- Force push em main/master
- Re-run de operação cara que já rodou

**Sempre confirme com o usuário antes**, mesmo em modo auto-approve.

---

## R6. Banco de dados — sempre novo por projeto

**Regra:** Ao iniciar projeto novo, **crie database e role dedicados** no Postgres compartilhado:
- Naming: `{slug_projeto}_v{N}` (ex: `micro_investors_v2`)
- Role: `{slug_projeto}_user` com senha forte em Docker secret
- Redis: prefixo `{slug_projeto}:*` em todas as chaves

**Anti-padrão proibido:** reutilizar database/role/namespace de outro projeto. Mesmo "só para teste rápido".

---

## R7. Auth — padrão Percus único

**Regra:** Todo projeto novo consome o **auth-service Percus centralizado** (`Identity → Organization → Product`, OTP WhatsApp/Email + JWT EdDSA + JWKS público + refresh opaco em Redis com family invalidation). Detalhes em `02_INFRA_E_STACK_PERCUS.md` Seção 2.

**Modo de adoção (estados possíveis):**

| Estado do projeto | Caminho |
|---|---|
| Greenfield iniciado **após** auth-service v1 publicado | Consome auth-service via lib `percus-auth` (validação JWT 100% local via JWKS cache). Sem auth próprio. |
| Greenfield iniciado **antes** de auth-service v1 (transição) | Sidecar FastAPI próprio com OTP+JWT HS256 (forma B da Seção 2.4). Migra pra auth-service quando v1 sair. |
| Legado em produção | Segue `comandos/MIGRAR_AUTH.md` (V1-V4). Não improvise. |

**Princípios não-negociáveis (independentes do estado):**

- **Validação JWT é local em cada projeto** — nunca chamar serviço externo a cada request. Lib `percus-auth` (ou equivalente do estado atual) valida assinatura via JWKS cacheado.
- **JWT_SECRET (HS256) ou par de chaves Ed25519 (EdDSA) dedicado por domínio.** Nunca reaproveitar secret de outro domínio (NEXTAUTH, public-token, webhook). Cada um tem o seu. Quando auth-service v1 ativo, chave privada vive só no auth-service; consumidores têm só pública (via JWKS).
- **Refresh token, quando emitido, é opaco em Redis com rotation a cada uso + family invalidation** (RFC 6749 §10.4). Refresh JWT stateless é vetado — sem revogação imediata, blast radius alto.
- **Cookie httpOnly + Secure + SameSite=lax** sempre. Domínio compartilhado entre subdomínios do apex. Cross-domain via redirect-fragment (R16). `localStorage` pra token é vetado.
- **OTP guardado em Redis** (TTL 5-10 min, max 5 tentativas, 1 OTP ativo por destino). Anti-flood paralelo via `SET ... EX ... NX`.
- **WhatsApp via adapter pattern**: Evolution API (default, custo zero, infra existente) + Cloud API oficial (quando projeto/tenant escalar — critérios de migração na Seção 2 do INFRA). Trocar provider é UPDATE em row de tenant config, sem deploy.
- **Anti-bot WhatsApp em ambos os backends** — sequência humana (presence/typing/delay), templates rotativos, number warm-up gradual, pool multi-número com health score, time-of-day awareness, auto-fallback canal. Detalhes em INFRA Seção 2.
- **Auth gate `sub == subject` em endpoints sensitive** — endpoints que afetam recurso identificado por payload (ex.: `/admin/totp/enroll {subject: "user@x"}`) **exigem** Bearer com claim `sub` igual ao `subject` do payload. Bearer válido de outro usuário com claim diferente = 403. Bearer ausente = 401. Aplicado em produção no auth-service desde 2026-05-06. (Aprendizado Fase 2.)
- **Lazy upsert de identity em `/me`** — primeira call autenticada com Bearer válido cria `auth.identities` row automaticamente. Não precisa endpoint explícito de signup/onboarding. Identity é side-effect do primeiro Bearer. Validado em produção no auth-service. (Aprendizado Fase 3.)
- **Lib cliente `percus-auth` é self-hosted** via `/dist/` mount do próprio auth-service (`https://auth.huboperacional.com.br/dist/percus_auth-<ver>-py3-none-any.whl` e `.tgz`). Consumidor instala com `pip install <url>` ou `npm install <url>`. PyPI/npm privado pago **não é necessário**. Detalhes na Seção 2 do INFRA. (Aprendizado Fase 3.)

**Vetado em projetos novos:** GoTrue, PostgREST, `@supabase/supabase-js`, NextAuth, magic-link puro fora do auth-service (R17), senha pura sem 2FA, refresh JWT stateless, JWT HS256 com chave compartilhada cross-projetos.

**Magic links** (first-login, convite, reset) — primitiva centralizada do auth-service via `/auth/magic/*`. Projetos consomem, não reimplementam (R17). **Pilar 1 (Padrão Auth Percus v2 — ver `PADRAO_AUTH_SERVICE.md` Seção L):** `/otp/request` passa a emitir OTP **e** magic juntos, sem opt-in — 🔶 rollout Sprint A; até o deploy, o comportamento exclusivo segue vigente.

**Admin / role privilegiada:** OTP + TOTP step-up obrigatório. Username+password é dívida — phishing/credential-stuffing sem ganho. TOTP enrollment no primeiro login da role admin. **Encrypt at rest** do `secret_b32` é obrigatório em produção (Docker Secret ou KMS — aprendizado Fase 4 do auth-service).

### R7.5 — Audience naming canônico (v6.8.0+)

Slugs em `auth.audiences.slug` **DEVEM** ser kebab-case: `^[a-z0-9]+(-[a-z0-9]+)*$`.

- ✅ `plexco-tasks`, `plexco-coach`, `familia`, `painel`, `paid-media`
- ❌ `plexco_tasks` (underscore proibido — incidente 2026-05-19)
- ❌ `PlexcoTasks` (camelCase proibido)

Migração de audiences legadas com underscore: ver [`comandos/UPGRADE_PARA_FASE7.md`](comandos/UPGRADE_PARA_FASE7.md) §2.

Enforcement runtime: regression test no plugin `percus-review` (Frente E) falha o build se grep encontrar audience com underscore em código consumidor.

### R7.6 — Tenant detection canônico (v6.8.0+)

Pré-autenticação, o frontend descobre o tenant via:

```
GET /tenants/by-origin?origin=<window.location.origin>
```

Response: `{ audience, product_name, logo_url, palette, copy, support_contact_url }`. Rate-limited 100 req/min por origin. Cache 5min sessionStorage no frontend via `useTenant()` da lib `percus-auth >= 0.4.0`.

Fallback: `PERCUS_AUTH_AUDIENCE_FALLBACK` env quando o endpoint falha (auth-service down ou origin não registrado).

Spec completa: [`PADRAO_AUTH_SERVICE.md`](PADRAO_AUTH_SERVICE.md) + [`docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md`](docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md).

---

## R8. Sessão sem HANDOFF é débito técnico

**Regra:** Toda sessão termina com `HANDOFF.md` atualizado contendo:
- Estado real (o que está em `[5-T]` vs o que é `[4-C]` ou abaixo)
- Próximo passo imediato (sem ambiguidade)
- Tabela de status espelhando `docs/PLANO.md`

**Template:** `templates/HANDOFF.template.md`.

**Gate de verificação:** abrir o HANDOFF gerado e perguntar: "se eu fechar tudo agora e voltar amanhã sem memória, consigo retomar?". Se a resposta é "talvez", o handoff está incompleto.

**Gate mecânico:** plugin `@percus/review` instala hook `on-stop` que bloqueia encerramento de sessão com edições de código se HANDOFF.md não foi atualizado. Pra burlar: `$env:PERCUS_SKIP_HANDOFF=1` antes do Stop, motivo declarado em voz alta. Skip fica logado em `.deepseek/handoff-skipped.log`.

---

## R9. Superpowers — não são opcionais

**Regra:** Para cada feature nova, execute o fluxo:

| Fase | Skill | Disparo |
|------|-------|---------|
| Início orquestrado | `percus-review:feature-flow` | **Toda feature/bugfix não-trivial** — substitui carregar R1+R9+R11+R13 separadamente |
| Brainstorming | `superpowers:brainstorming` | Feature não-trivial, antes de qualquer código |
| Exploração | `Explore` (subagent) | Código desconhecido em projeto grande |
| Plano | `superpowers:writing-plans` | Multi-step com 3+ arquivos a tocar |
| Execução paralela | `superpowers:subagent-driven-development` | **Plano com 3+ tasks independentes — OBRIGATÓRIO** (corta contexto principal em ~60%) |
| Paralelização B/F | `superpowers:dispatching-parallel-agents` | Backend + Frontend independentes |
| Testes | `superpowers:test-driven-development` | **Todo endpoint novo** — vitest antes do código |
| Debug | `superpowers:systematic-debugging` | Qualquer bug ou teste quebrado |
| Revisão | `superpowers:requesting-code-review` | Em background antes do commit |
| Finalização | `superpowers:verification-before-completion` | Antes de marcar `[5-T]` |
| Marco | `percus-review:close-milestone` | Antes de marcar `✓` no PLANO (fechar fase/feature/épico) |

**Cobertura mecânica (defesa em profundidade — dois layers):**

1. **Layer 1 — Hook PreToolUse:Bash do plugin** (`hooks/pre-commit-check.ps1`). Bloqueia commit dentro do Claude Code com stderr formatado em PT-BR. UX boa, mas tem brecha conhecida em comandos bash compostos (`rm -rf .deepseek/reviews && git commit` burla porque PreToolUse avalia estado uma vez antes do bash rodar).
2. **Layer 2 — Git hook nativo** (`.git/hooks/pre-commit`, instalado via `/percus-review:install-git-hooks` no projeto). POSIX sh self-contained, dispara no momento real do `git commit`. Fecha a brecha do Layer 1 e cobre commits feitos direto no terminal fora do Claude Code. **Obrigatório em todo projeto Fase 5+.**

Não confiar em disciplina — os hooks são gate. Escape declarável em voz alta: `PERCUS_HOOKS_DISABLED=1 git commit ...`.

### Auto-trigger pelo agente (v5.1.0+)

**Antes**: agente pedia ao usuário "rode `/percus-review:review` no chat" antes de cada commit. Fricção real (5-20 commits/dia × 1 paste manual).

**Agora**: agente Claude Code AUTORIZADO a auto-disparar review via wrapper kit-level antes de qualquer `git commit` que ele mesmo for executar via Bash tool. Wrapper:

- Pre-commit: `pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1"` (ou `.sh` em Unix)
- Marco: `pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-milestone-review-auto.ps1" -Base <commit-inicio-marco>`

Wrapper resolve plugin instalado, dispatch DeepSeek (caso default) ou emite marker `__PERCUS_NEEDS_CROSS_CLAUDE__` no stderr quando decisão exige Cross-Claude (pasta sensível, marco, ou commit de DeepSeek). Agente lê marker → dispatch Sonnet subagent via Agent tool → consolida findings → decide commit.

**Fluxo do agente:**

1. Antes de `git commit` que toca código: rodar wrapper auto-trigger
2. Ler findings; processar críticos (corrigir antes do commit)
3. Se marker `__PERCUS_NEEDS_CROSS_CLAUDE__` aparecer: dispatch Sonnet subagent IMEDIATAMENTE com prompt R11 cross-claude-review (revisar diff vs AGENTS.md). Salvar output em `.deepseek/reviews/<ts>-cross-claude.jsonl` para o hook validar.
4. Apresentar consolidado ao usuário, declarar em voz alta findings ignorados
5. `git commit` (hooks Layer 1+2 já aprovam por TTL do review)

**Comandos manuais ainda válidos:**

- Slash command `/percus-review:review` no chat — pra invocação humana
- Wrapper auto — pra invocação pelo agente

Hook Layer 1+2 continua sendo backstop final — se agente esquecer auto-trigger, hook bloqueia commit normalmente.

**Em commits manuais (humano no terminal, fora do Claude Code):** apenas Layer 2 (git hook nativo) atua. Auto-trigger não se aplica — humano roda `/percus-review:review` no chat se quiser.

**Anti-padrão proibido:** pular brainstorming porque "já sei o que fazer". TDD opcional. Code-review pulado em bulk edit. Implementar plano grande serialmente quando subagent-driven-development cabe.

**Guia rápido de skills:** `comandos/USANDO_SUPERPOWERS.md`.

**Detalhes do fluxo passo-a-passo:** `checklists/CHECKLIST_FEATURE_NOVA.md`.

---

## R10. Design — gate por trigger lexical (v0.dev + shadcn MCP, NÃO Claude artifacts)

**Regra:** Se o pedido contém qualquer um destes triggers, **PARE antes de codar** e siga `${env:PERCUS_CANON_DIR}/comandos/DESIGN_WORKFLOW.md`:

`landing page`, `página inicial`, `home`, `redesign`, `redesenhar`, `refazer tela`, `hero section`, `seção de X`, `banner`, `CTA`, `dashboard`, `painel`, `tela de métricas`, `fluxo de onboarding`, `fluxo de cadastro`, `fluxo de checkout`, `pitch deck`, `apresentação`, `one-pager`, `melhorar UI/UX`, `deixar mais bonito`, `modernizar visual`, ou qualquer pedido que envolva **mais de 1 tela nova**.

**Ferramentas aprovadas** (em ordem de preferência):

| Tipo de pedido | Ferramenta | Por quê |
|---|---|---|
| Componente isolado (button, card, modal, form) | **shadcn MCP local** (skill `vercel:shadcn`) | Adiciona via CLI direto no repo; quase zero token Claude |
| Tela/fluxo novo, alta fidelidade | **v0.dev** (Vercel) | Browser próprio, créditos próprios, exporta código React/Tailwind pronto |
| Iteração rápida sobre tela existente | Edição local + `npm run dev` | Sem custo de mockup; loop de feedback é a tela real |
| Diagrama / wireframe | **Excalidraw** ou **Mermaid** em markdown | Versionável, sem dependência externa |

**Vetado para produção visual:** Claude artifacts (claude.ai/design). Fica indisponível ~6/7 dias por semana e bloqueia trabalho. Pode ser usado pra rascunho descartável quando estiver disponível, mas **não é o caminho oficial**.

**Resposta obrigatória ao detectar trigger:**
> Essa tarefa é visual. Antes de codar, vou seguir `${env:PERCUS_CANON_DIR}/comandos/DESIGN_WORKFLOW.md`:
> 1. Identifico se é componente isolado (→ shadcn MCP) ou tela nova (→ v0.dev)
> 2. Você gera/aprova o draft visual no canal certo
> 3. A partir do código aprovado, sigo o fluxo `[0]→[5-T]`
> Quer que eu já te oriente o caminho específico?

**Exceções permitidas (declare em voz alta):** bug fix em componente existente · ajuste de copy · troca isolada de cor/espaçamento · usuário disse explicitamente "sem mockup".

**Anti-padrão:** começar a codar uma "tela nova rapidinha" sem mockup; ou esperar Claude artifacts voltar quando v0.dev/shadcn resolveriam agora.

---

## R11. Review cross-provider obrigatório — antes de commit E ao concluir cada marco

**Regra:** Rodar review cross-provider em **dois momentos** obrigatórios. Reviewer é decidido pelo router automático ou forçado manualmente.

- **Pre-commit:** `/percus-review:review` (router auto — escolhe DeepSeek, Cross-Claude ou duplo conforme contexto)
- **Marco:** `/percus-review:milestone-review --base <commit-de-inicio-do-marco>` (DeepSeek + Cross-Claude duplo, sempre)
- **Override manual:** `/percus-review:deepseek-review` ou `/percus-review:cross-claude-review` quando quiser forçar canal específico

### Matriz de roteamento automática (`/percus-review:review`)

| Cenário | Reviewer | Por quê |
|---|---|---|
| Pre-commit rotineiro | **DeepSeek** (`deepseek-chat`) | Cross-provider real (não-Anthropic), 9× mais barato que GPT-5, suficiente pra catch básico |
| Pre-commit em pasta sensível (`**/auth/**`, `**/payment*/**`, `**/migrations/**`, `**/credentials/**`, `.env*`) | **DeepSeek + Cross-Claude duplo** | Defesa em profundidade onde o risco × consequência paga o custo |
| Pre-commit de saída DeepSeek (commit com trailer `Co-implemented-by: deepseek-v4` — ver R13) | **Cross-Claude apenas** (subagent Sonnet) | Princípio R11: revisor ≠ implementador. DeepSeek não pode auto-revisar |
| Marco (fim de fase/feature/épico) | **DeepSeek + Cross-Claude duplo** | Frequência baixa, gate crítico — vale defesa em profundidade |
| Pre-commit com alegação sobre função importada (lib externa, auth-service, SDK) | **Cross-Claude obrigatório no review** | DeepSeek pode alucinar comportamento por nome de função sem ler implementação. Cross-Claude segue imports melhor. Detectado por F4c hook quando reviewer principal foi só DeepSeek. |

Justificativa do design: dois provedores diferentes (DeepSeek Inc + Anthropic) cobrem viés de modelo de cada um. Cross-Claude é grátis (consome plano Claude). DeepSeek é ~$0.02/call. Custo agregado mensal estimado: $2-5.

### Quando dispara

1. **Antes de cada `git commit`** que muda código (não vale para commits só de docs/configs).
2. **Ao concluir cada marco** de plano em execução — fim de fase numerada (Fase 1, Fase 2…), conclusão de feature dentro de épico, ou ponto onde o agente diria *"pronto, próxima etapa"*. O escopo da revisão de marco é o **conjunto** de mudanças do marco (não só do último diff).

### Setup primeira vez

Seguir `${env:PERCUS_CANON_DIR}/comandos/SETUP_REVIEW_ROUTING.md`. Cada projeto precisa de:
- `DEEPSEEK_API_KEY` no `.env`
- Plugin `@percus/review` instalado (uma vez globalmente)
- `AGENTS.md` na raiz (template em `${env:PERCUS_CANON_DIR}/templates/AGENTS.template.md`) — sem isso, o reviewer revisa cego

### Tratamento de findings

- **Bug ou regressão:** corrigir antes de commitar
- **Risco / violação de regra Percus:** corrigir antes de commitar **OU** declarar em voz alta por que está ignorando
- **Alegação técnica (comportamento de função importada, API contract, side-effect):**
  OBRIGATÓRIO ler ou testar a implementação antes de levantar como crítico.
  Se não foi possível ler (ex.: lib externa), marcar na conclusão como
  "alegação não verificada — validar manualmente" para evitar bloqueio em base falsa.
  **Anti-padrão observado (incidente 2026-05-18):** DeepSeek alegou bug de ordering em
  função importada sem ler implementação; função era outbox pattern atômico; bug
  inexistente foi propagado para 4 PR comments públicos.
- **Preferência de estilo:** ignorar é OK, mas declare em voz alta para criar rastro

### Gate de verificação

`/percus-review:review` deve ter sido rodado nos últimos 5 minutos antes do `git commit`. Se passou disso, rode de novo (você pode ter mexido em algo desde então).

### Anti-padrão proibido

Commitar e "rodar review depois" — derrota o propósito. Interceptar **antes** do commit.

### Exceções declaráveis em voz alta

- Commit só de docs/config sem mudança de código (`*.md`, `*.yml`, `*.json` não-código)
- Hot fix urgente em produção — corrige primeiro, abre TODO de "review retroativo" depois
- DeepSeek API down → router faz fallback automático pra Cross-Claude (declarar em voz alta)
- Plugin `@percus/review` indisponível — declarar e marcar TODO de "revisar retroativamente"

### Kit Percus (`_Novo_Projeto/`) — sem exceção a R11

O kit de iniciação (`${env:PERCUS_CANON_DIR}/`) segue R11 **como qualquer projeto** — mudanças nele (regras, templates, comandos, scripts, plugin, hooks) passam pelo mesmo gate de review cross-provider de qualquer commit.

> Até v6.14.0 o kit era **exceção** a R11. A isenção foi removida porque (1) já era **letra morta** — o hook `pre-commit-check` sempre aplicou o gate uniformemente, sem carve-out pro kit; e (2) o kit hoje shippa **código executável real** (plugin: scripts + ~12 hooks ×3 shells + 123 testes), não só convenção — exatamente o tipo de código que o review existe pra proteger (bugs reais já foram pegos: regex de parse no `fact-check.ps1`, parsing ASCII/PS5.1). Uma regra só, pra tudo.

Além do review, mudanças no kit ainda devem: (a) ser feitas via plano explícito, (b) ser revisadas pelo usuário antes de virar canon, (c) passar por verificação de consistência cruzada (greps de referências mortas, validação de sintaxe). Estes são **aditivos** ao review, não substitutos.

As exceções gerais declaráveis em voz alta (acima — docs-only, hot fix, DeepSeek down → fallback Cross-Claude) valem pro kit como pra qualquer projeto.

---

## R12. Toda regra precisa de verificação verificável

**Meta-regra:** Se uma regra não tem como você verificar objetivamente que cumpriu, ela é decoração. Se você se pegar pensando "acho que cumpri", você não cumpriu — vá verificar.

**Para R1-R11 e R13-R18**, a coluna "gate de verificação" ou "como verificar" é o ponto crítico. Quando ausente, a regra não está apta a ser auditada — nesse caso, peça ao usuário para esclarecer.

---

## R14. Observabilidade obrigatória em serviços tier-1

**Regra:** Todo serviço tier-1 (auth, gateway de pagamento, webhook handler, fila crítica, qualquer endpoint que outro projeto consome) **deve** emitir:

1. **Traces OpenTelemetry** em pontos críticos do fluxo (endpoint → DB → integração externa → resposta). Stack default: OTel SDK → SigNoz self-host (ClickHouse-backed, ~150MB RAM, mais leve que Grafana stack).
2. **Logs estruturados em JSON** (structlog em Python, slog em Go) com `request_id`, `tenant_id`, `module`, `actor`, sem PII em plain text.
3. **Métricas de negócio** específicas do serviço (ex.: auth → delivery rate por canal, taxa de falha OTP; webhook → time-to-process, taxa de retry).
4. **Audit trail imutável** com hash chain (cada row tem `prev_hash` do anterior — barato, validável end-to-end, sem precisar SIEM).
5. **Alertas proativos** em métricas que sinalizam ataque ou degradação (ex.: taxa de falha OTP >X% = ataque em curso; delivery rate <90% = canal degradado).
6. **Webhook callbacks como insumo de audit/health-score** — endpoints `POST /webhooks/<provider>` (Evolution `messages.update`, Stripe webhooks, etc.) são insumo válido pra audit log e health-score, **mesmo antes** de OTel/SigNoz wirados. Pattern: **stub-first** — endpoint loga eventos via structlog em produção primeiro (já recebe payload real), business logic / regras de health-score vêm em fase posterior. Validado em prod no auth-service desde 2026-05-06. (Aprendizado Fase 3.)

**Gate de verificação:** abrir SigNoz/Grafana e ver trace de uma transação real do serviço, fim-a-fim. Se trace pula etapas ou não existe, R14 não foi cumprida.

**Anti-padrão:** "depois eu adiciono observability" — auth e pagamento sem trace em produção é bug latente. Adicionar OTel quando o sistema está em produção custa 10× mais que adicionar no scaffold.

**Tier-2 (CRUD interno, dashboard, ferramenta operacional):** structlog + métricas básicas suficiente. OTel opcional.

**Pilar 5 (Padrão Auth Percus v2 — `PADRAO_AUTH_SERVICE.md` Seção L.5):** define o set mínimo de métricas auth cross-product (`auth.magic.*`, `auth.otp.*`, `auth.signup`, `auth.identity.linked`) → SigNoz, redesenhando o audit-chain (item 4) como audit trail via OTel exporter. 🔶 planejado (Sprint A base) — SigNoz ainda não subiu.

---

## R15. Rate limit canônico — IPv6 /64 + canonicalização de destino

**Regra:** Todo endpoint público que aceita identificador (email, telefone) ou IP deve:

1. **Canonicalizar** antes de usar como chave de rate limit:
   - Email: `lowercase` + `strip plus-tag` (`user+1@gmail.com` → `user@gmail.com`).
   - **Telefone — duas formas canônicas distintas, NUNCA misturar:**
     - **JWT/API form (consumer-facing):** E.164 **COM `+`** (`+55 11 99999-9999` → `+5511999999999`). Usado em `sub` claim do JWT, payloads de `/otp/*`, `/auth/magic/*`, e qualquer input HTTP externo. Gerado via `libphonenumber.format_number(..., E164)` em `libs/python/percus-auth/src/percus_auth/phone.py:normalize_phone`.
     - **DB storage form (interno):** digits-only **SEM `+`** (`+5511999999999` → `5511999999999`). Convenção cravada em 2026-05-15 pós-Strangler Etapa 2 do Plexco Tasks (migration 040). Aplica-se a `auth.identities.phone`, `plexco_tasks.users.phone`, `familia_api.users.phone`, e qualquer FK ou unique index sobre telefone.
     - **Regra de uso obrigatória:** consumer (qualquer serviço Percus) **SEMPRE** normaliza antes do WHERE: `handle.lstrip("+")` ou `phone_handle_for_db_lookup(handle)` da lib `percus-auth >= 0.3.0`. Insert/update no DB **SEMPRE** strips o `+` antes do `INSERT`/`UPDATE`.
     - **Justificativa:** mudar DB form pra E.164 exige migration cross-project (auth-service + Plexco + Familia + Coach + Painel) — alto custo operacional sem ganho semântico proporcional. Aceitar a divergência storage/API como contrato explícito é mais barato e tem ZERO risco de drift se a regra estiver no canon.
     - **Anti-padrão:** `WHERE phone == sub_handle` direto sem strip. Em prod isso falha silenciosamente (sub tem `+`, DB não) — Plexco Tasks deps.py incidente 2026-05-15 + auth-service `resolve_identity_id_from_sub` incidente 2026-05-19 (commit `b3ad061`).
   - Hash SHA-256 do canonicalizado quando logado em audit.
2. **Rate limit por IP usar /64 em IPv6** (não /128). Cliente residencial tem 2^64 endereços por /128 — limite por /128 é zero proteção.
3. **Dual-key rate limit:** por IP **+** por destino (não OR; ambos os limites valem).
4. **Implementação:** Redis `INCR + EXPIRE`, prefixo `{slug}:rl:{tipo}:{chave}`.
5. **OTP storage no DB:** quando OTP for persistido em Postgres (e não só Redis), código deve ir como **bcrypt hash (rounds=10)** — nunca em plain text. Validação roda dentro de transação com **`SELECT ... FOR UPDATE`** na row do OTP pra evitar race condition no incremento de tentativas. Validado em prod no auth-service. (Aprendizado Fase 1.)

**Defaults razoáveis (auth-service):** 10/h por IP/64, 5/h por destino canonicalizado, 5 tentativas por OTP. (Pilar 1 v2: `/otp/request` emite OTP+magic num **único** request — conta 1 contra o limite por destino, não 2.)

**Gate de verificação:** smoke test com `user+1@`, `user+2@`, `user+3@` do mesmo email base — devem todos contar como mesmo destino. Smoke com 11 requests do mesmo /64 IPv6 — 11º deve bloquear.

**Anti-padrão:** rate limit "por email plain" sem normalizar. Plus-addressing burla trivialmente. Rate limit por IPv6 /128 idem.

---

## R16. SSO multi-domínio — subdomínio compartilhado + redirect-fragment

**Regra:** Auth do estúdio Percus opera em **dois modos** de SSO conforme o domínio do consumidor:

| Cenário | Padrão | Como funciona |
|---|---|---|
| Subdomínio compartilhado (mesmo apex) — ex.: `parceiros.ads4pros.com`, `gestao.ads4pros.com`, `vendas.ads4pros.com` | **Cookie compartilhado** | Cookie httpOnly em `.ads4pros.com` (apex). Login em qualquer subdomínio aparece logado em todos. |
| Domínio diferente (ex.: outro produto Percus em domínio próprio) | **Redirect-fragment SSO** | Frontend redireciona pra `auth.ads4pros.com/sso?return=...` → após login, redirect de volta com `#at=<jwt>` no fragment → JS lê fragment, salva, descarta. |

**Vetado:**
- `SameSite=None` cookies cross-site (frágeis em ITP/Brave/Chrome 2026+).
- Cookies de terceiro (third-party) — bloqueados por padrão na maioria dos browsers.
- Token via query string (`?at=`) — cai em logs de servidor/proxy.

**Gate de verificação:** abrir 2 subdomínios em abas, logar em uma → segunda recarregada já vê sessão sem novo login. Em domínio cross-apex, verificar redirect-fragment funciona sem cookie 3rd-party ativo.

**Implementação:** lib `percus-auth` expõe helpers (`PercusAuth.handleFragment()` no frontend) — projetos não reimplementam.

---

## R17. Magic links — primitiva centralizada no auth-service

**Regra:** Magic links (first-login, convite, reset de phone/email, login passwordless) são **primitivas do auth-service**, não reimplementadas em cada projeto.

**API canônica (quando auth-service v1 disponível):**
- `POST /auth/magic/issue { identity_id?|email|phone, purpose, redirect_uri, ttl_seconds }` → emite código + URL `/w/{code}`
- `GET /w/{code}` → valida (single-use, TTL), emite JWT, redireciona pro `redirect_uri` com `#at=JWT`
- `POST /auth/magic/consume { code }` → variante programática (retorna tokens em vez de redirect)

**Propriedades obrigatórias:**
1. **Single-use** — código consumido fica invalidado mesmo se URL for reutilizada.
2. **TTL configurável** (default 48h pra first-login, 1h pra reset).
3. **Bind a propósito** — `purpose` no payload impede reuso cross-fluxo (link de reset não vale como first-login).
4. **Rate limit** por `identity_id|destino` pra evitar flood de emissão.
5. **Observabilidade** (R14) — log de issue/consume/expiry.

**Pilar 1 — emissão combinada (Padrão Auth Percus v2, `PADRAO_AUTH_SERVICE.md` Seção L.1):** o magic deixa de ser só first-login/convite/reset — `/otp/request` passa a emitir um magic **junto com** todo OTP, na mesma mensagem, sem opt-in. Todas as propriedades acima (single-use, TTL, bind, rate-limit, observabilidade) seguem valendo. **Status:** 🔶 rollout Sprint A — não em prod; projetos novos já codam pro par.

**Vetado em projetos:** geração própria de magic-link, schema próprio de welcome_codes, validação local sem chamar `/auth/magic/consume`. Surface crítico de bugs (replay, TTL bypass, single-use race) **não pode** ter N implementações divergentes.

**Transição:** projetos pré-auth-service v1 podem manter implementação atual (ex.: `auth.welcome_codes` do Painel) — migram via runbook quando auth-service publicar. O Painel **ainda roda auth próprio** (não migrou); o caminho é o **Pilar 2** (Padrão Auth Percus v2, Seção L.2), ⬜ bloqueado por script de migração `old_user_id→identity_id`.

**Gate de verificação:** smoke E2E — emitir, consumir uma vez (sucesso), tentar consumir 2ª vez (falha). Smoke de TTL — emitir, esperar TTL+1s, tentar consumir (falha).

---

## R18. Tracking attribution é separado de auth

**Regra:** Cookies/SDK de **tracking de marketing** (`?ref=`, last-click attribution, UTM, pixels de afiliado) **não dependem de** e **não compartilham código com** o sistema de auth.

| Responsabilidade | SDK / Domínio | Vive onde |
|---|---|---|
| Identidade, login, sessão, JWT | `percus-auth` | auth-service + lib em cada projeto |
| Atribuição comercial, cookies de marketing, pixels | `percus-tracking` (peer separado) | Painel + SDK independente |

**Por que separar:**
- Tracking evolui em ritmo de marketing (mudanças semanais possíveis).
- Auth evolui em ritmo de segurança (mudanças trimestrais auditadas).
- Bump de tracking não pode forçar re-deploy de auth em N projetos.
- Cookie de marketing (`a4p_ref`, 90d, anônimo) ≠ cookie de identidade (httpOnly, JWT).

**Gate de verificação:** projeto que injeta tracking SDK funciona sem `percus-auth` carregado. Reciprocamente, lib `percus-auth` não tem dependência de cookie de marketing.

**Anti-padrão:** "vou adicionar `?ref=` na lib de auth porque já tá lá" — acopla domínios independentes, vira bola de neve.

---

## R19. Identidade canônica via auth-service — único dono, todos referenciam

**Regra:** Identidade de login é primitiva centralizada no `auth-service`. Outros projetos consomem via `identity_id`. Esta regra é a aplicação prática do contrato cross-projeto descrito em `D:\Claud Automations\OWNERSHIP.md` — leia aquele documento antes de mexer em qualquer tabela de user/profile/affiliate.

1. **Criar identidade de login = SÓ via auth-service** (`POST /internal/identities`). Nenhum projeto pode criar tabela própria de credencial (bcrypt + password, OTP local, refresh próprio, magic-link próprio). **Pilar 1 (Padrão Auth Percus v2):** o signup passa a coletar **`name + phone + email`** obrigatórios → contract `/internal/identities/v2` required (breaking, ≥60d, major bump `percus-auth`; ver `PADRAO_AUTH_SERVICE.md` B.1.v2). 🔶 Sprint A — V1 (optional) segue vigente até o `/v2`.
2. **Referenciar identidade = via `identity_id UUID`** (FK lógica pra `auth.identities.id`). FK lógica porque os DBs são fisicamente separados; integridade é mantida pela aplicação.
3. **Em tabelas multi-tenant** (`users`, `profiles`, `affiliates`): **NUNCA** use `UNIQUE` global em `email` ou `phone`. Sempre `UNIQUE(organization_id, email)` (e idem pra `phone`) **OU** drop unique confiando em `identity_id` como chave de identidade real. UNIQUE global quebra multi-org no primeiro usuário que existe em 2 orgs (bug real — Plexco Tasks sessão 33, convite `moacir@ads4pros.com`).
4. **Tracking de origem da identidade** mora em `auth.identities.origin` (TEXT). Formato canônico: `"<sistema>:<id-local>"` — exemplos: `"painel:affiliate-abc"`, `"plexco-tasks:invitation-7c8e1d"`, `"signup:lp-gate"`. Setado no momento de criação, não atualizado depois.
5. **Exceção transitória:** `Painel Gestão` ainda roda auth próprio (OTP+HS256) e mantém bcrypt local pra admin SaaS — **não migrou**. Sunset = **Pilar 2** do Padrão Auth Percus v2 (Seção L.2, ⬜ Sprint B, bloqueado por script de migração `old_user_id→identity_id`), antes pensado como Etapa 4 do Strangler Fig (ver `OWNERSHIP.md`). **Outros projetos não têm essa exceção** — sem bcrypt local, sem schema de credencial próprio.

**Gate de verificação:**

- `grep -r "UNIQUE.*email" backend/` no seu projeto não retorna unique global em coluna que pode repetir cross-org.
- Tabela de user/profile do projeto tem coluna `identity_id UUID`.
- Fluxo de convite faz lookup no auth-service antes de inserir local (evita duplicação de identity quando a pessoa já existe em outro produto).

**Anti-padrão proibido:**

- Criar `users.password_hash` em projeto novo.
- Reimplementar OTP local/magic-link próprio (já vetado em R7 e R17, R19 reforça).
- Migration que adiciona `UNIQUE(email)` global "porque é mais simples" — barra multi-org desde dia 1.
- Decidir "vou só guardar `email` na minha tabela e ignorar `identity_id`" — perde o link cross-produto, perde SSO, vira drift garantido.

**Referência primária:** `D:\Claud Automations\OWNERSHIP.md` (quadro de ownership + árvore de decisão "criar ou referenciar?").
**Receita prática:** `${env:PERCUS_CANON_DIR}\checklists\CHECKLIST_AUTH_NOVO_PROJETO.md`.

---

## R13. Roteamento de modelos — DeepSeek implementa, Claude arquiteta, conselho cross-provider revisa

**Regra:** Tarefas de implementação **mecânica** devem ser delegadas ao DeepSeek V4 via wrapper `${env:PERCUS_CANON_DIR}/scripts/deepseek-impl.{ps1,sh}`, seguindo o playbook em `${env:PERCUS_CANON_DIR}/04_MODEL_ROUTING.md` seção "Como delegar". Saída do DeepSeek é tratada como **rascunho** — sempre revisada por Claude (validação contra R1–R12) e pelo revisor cross-provider (R11 — DeepSeek + Cross-Claude) antes de virar commit. **Decisões arquiteturais permanecem com Claude.**

**Marker obrigatório no commit:** ao aplicar saída DeepSeek via wrapper (`-Apply`), o commit message **deve** terminar com o trailer Git:

```
Co-implemented-by: deepseek-v4
```

O router de review (R11) detecta esse trailer e roteia revisão pra Cross-Claude (Sonnet subagent), evitando DeepSeek auto-revisão. Marker visual `🤖` no PLANO/HANDOFF continua opcional; o trailer é o gate técnico.

**Quando delegar (todos os critérios):**
- Plano explícito em markdown, com arquivos-alvo nomeados
- Sem decisão arquitetural pendente
- Não toca pasta sensível (`auth/`, `payment*/`, `migrations/`, `credentials/`, `.env*`)
- Cabe em ≤3 arquivos OU é padrão repetido em N arquivos

**Quando NÃO delegar:**
- Brainstorm, exploração, decisão de trade-off
- Debug de causa desconhecida
- Pasta sensível (auth, pagamentos, migrations)
- Tasks visuais (segue R10 + `${env:PERCUS_CANON_DIR}/comandos/DESIGN_WORKFLOW.md`)

**Gate de verificação:**
1. `DEEPSEEK_API_KEY` carregada na sessão
2. Output do DeepSeek inspecionado em `--dry-run` antes de aplicar
3. Validação contra R1–R12 antes de aceitar
4. `/percus-review:review` (R11) sobre o resultado antes de marco/commit — router detecta trailer `Co-implemented-by: deepseek-v4` e roteia pra Cross-Claude

**Anti-padrão proibido:** rodar DeepSeek em `--apply` direto sem dry-run; ou aceitar saída sem validação Claude + revisor cross-provider.

**Exceções declaráveis em voz alta:**
- Task tão pequena que delegação tem mais overhead que ganho (ex.: trocar 1 string)
- DeepSeek API down — implementa direto no Claude e marca em voz alta
- Plano não está pronto ainda — volta pro arquiteto antes de delegar

**Detalhes operacionais:** `${env:PERCUS_CANON_DIR}/04_MODEL_ROUTING.md` (matriz + playbook completo). Wrapper: `${env:PERCUS_CANON_DIR}/scripts/deepseek-impl.{ps1,sh}`.

---

## R20. Decisões de conselho não autorizam ação externa pública

**Regra:** Consenso do conselho 3-membros (DeepSeek + Llama + Cross-Claude) é
**licença para ação reversível interna** — commit local, refactor, design choice,
escolha de stack em decisão de design. **Não é licença para ação externa pública**
baseada em premissa técnica.

### Definição de "ação externa pública"

Inclui (não exaustivo):
- Comment em PR de repositório público
- Mensagem em Slack/Discord/email coletivo
- Deploy em produção
- Push pra remote (main, tag, branch)
- Criação/fechamento de issue pública
- Resposta automatizada a sistema externo (Stripe, Linear, GitHub API, webhooks)

### Gate obrigatório antes de ação externa pública baseada em finding técnico

1. **Operador valida síntese do conselho explicitamente** — silêncio NÃO é OK.
   "Aprovado" textual (ou equivalente) é obrigatório.
2. **Findings críticos passaram por fact-check independente do código real**
   (ver R11 expansion + F3 fact-check pipeline do plugin).
3. **OU** operador declara explicitamente "ciente do risco, prosseguir"
   (R5 escape hatch com motivo declarado em voz alta).

### Anti-padrão (incidente Plexco Tasks 2026-05-18)

Conselho 3/3 votou OPÇÃO A (bloquear) em finding técnico → agente postou 4 PR
comments públicos pedindo bloqueio de merge → finding era alucinação do DeepSeek
sobre função importada que não foi lida → retração necessária. Operador perdeu
confiança no conselho. Plugin v6.7.0 introduz hook `external-action-guard.ps1`
que bloqueia tools externos quando council recente tem `premise_validity≠ok`
OU findings sem `fact_check: CONFIRMADO`.

### Gate verificável

- Antes de qualquer ação externa pública pelo agente:
  - Log explícito de `operator_approved: true` na conversa, OU
  - Variável de ambiente `PERCUS_EXTERNAL_OVERRIDE=1` com motivo declarado em commit/log
- **Logs de council consult NÃO contam como autorização** (são opinião, não gate)
- Hook `plugin/percus-review/hooks/external-action-guard.ps1` (v6.7.0+) faz
  enforcement runtime via PreToolUse bloqueando `gh pr comment`, `gh issue close`,
  `slack-cli`, `git push` sem aprovação explícita

### Relação com R5

R5 cobre operações **técnicas** irreversíveis (DELETE, drop, force-push, paid op).
R20 cobre operações **comunicação/sociais** irreversíveis (PR comment, Slack post)
baseadas em premissa técnica que pode ser alucinação.

R5 escape hatch é "ciente do risco técnico, prosseguir".
R20 escape hatch é "operador validou síntese do council + fact-check".

### Exceções (quando R20 não se aplica)

- Push de docs-only (.md, README) que não tocou código nem regra de negócio
- Comment em PR DO PRÓPRIO operador (não em PR de terceiros)
- Resposta a comando explícito do operador ("posta esse comment exato")

---

## R21. FK invariant pattern — parent INSERT upfront, não confiar em ordering implícito de TX

**Regra:** toda foreign key entre tabelas inseridas no mesmo TX OU em sequência rápida (mesmo handler, mesmo job, mesmo orchestrator step) exige uma das 3 abordagens — em ordem de preferência:

1. **Parent INSERT upfront (placeholder se necessário)** — preferido. Insere o pai antes de qualquer `db.flush()` que toque um filho. Se o pai depende de cálculo que só termina mid-TX (LLM call, async result, computed field), inserir com placeholder + marker `frozen_at IS NULL` (ou equivalente) e UPDATE no final. Filtros downstream `WHERE frozen_at IS NOT NULL` mantêm placeholders fora de endpoints de leitura.
2. **FK `DEFERRABLE INITIALLY DEFERRED`** — aceitável apenas em schemas simples sem risco de split TX futuro. **Mascara fragilidade:** refactor para async/split-job/multi-TX move o FK check para COMMIT, parent ainda não existe, silent failure idêntica sem o comentário CRITICAL avisando. Use só quando o invariante "parent e child sempre commitam juntos" for arquiteturalmente garantido.
3. **child.parent_id NULLABLE durante in-flight + UPDATE depois** — só pra casos onde child consegue existir sem parent (raro, geralmente é cheiro de modelagem errada).

**Why:** Coach `coach_cost_ledger.brief_id` FK NOT DEFERRABLE (mig 0029, 2026-05-12) + `brief_id = uuid.uuid4()` gerado upfront em `orchestrator.run_pipeline` + brief INSERT só em step f (compose_brief). Cada `db.flush()` em step intermediário (`record_cost` dentro de `extract_signals/stakeholders/commitments/memory`) violava FK. Bug DORMENTE 9 dias (v0.19.0 2026-05-13 → smoke PR#6 2026-05-22), silenciado por catch `IntegrityError` tratado como "race-resolved" sem distinguir tipo. Council 3-vozes 2/3 votou Opção B (placeholder upfront); Cross-Claude: "DEFERRABLE faria a mesma coisa — esconder a raiz".

**Gate de verificação:**

1. **Audit de schema** — script equivalente a `.tmp/audit_fk_deferrable.py` do Coach (query `information_schema.referential_constraints` + `pg_constraint.condeferrable`) lista FKs entre tabelas tocadas no mesmo handler. Output esperado: cada FK NOT DEFERRABLE tem justificativa documentada (parent-first ordering OU comentário linkando este R21).
2. **Cleanup cron de placeholders verifica FK ON DELETE de TODOS os children antes de implementar** — `SET NULL` perde audit trail, `CASCADE` perde rows, `RESTRICT` quebra cleanup. Decisão consciente documentada.
3. **Golden test E2E sem mock da camada que dispara FK** — se o orchestrator chama `record_cost(parent_id=...)` dentro de `_call_with_retry`, o teste pode mockar `_call_with_retry` (não a camada inteira `chat_json`), mantendo `record_cost` ativo. Mock que pula a função que dispara o INSERT do child **não exercita o invariante**.
4. **IntegrityError catch DIFERENCIADO** — UNIQUE viol (race-resolved legítimo) vs FK viol (bug). Catch genérico `except IntegrityError` é anti-padrão; deve distinguir por constraint name ou por tipo.

**Anti-pattern:** comentário `# CRITICAL: ... otherwise FK-violate` no código sem teste correspondente que valide a invariante. Sinal de dívida técnica conhecida não coberta. **Toda vez que se escreve CRITICAL, exige test que valide o invariante.**

**Refs:**
- Post-mortem completo: `huboperacional/plexco-coach/docs/post-mortems/2026-05-22-fk-not-deferrable-bug.md` (canary do problema).

---

## R22. Alocação central de portas locais — `PERCUS_PORT_BASE` obrigatório

**Regra:** todo projeto Percus tem um `PERCUS_PORT_BASE` único e determinístico alocado pelo Painel de Gestão via skill `percus-review:port-allocate`. As portas locais expostas no host devem ser `${PERCUS_PORT_BASE} + N` (N em `[0,19]`) seguindo a tabela de offsets em [02_INFRA_E_STACK_PERCUS.md](02_INFRA_E_STACK_PERCUS.md).

**Forbidden:**
- Hardcode de porta literal (`port: 5173`, `EXPOSE 8000`) em `vite.config.*`, `next.config.*`, `docker-compose*.yml`, `package.json` scripts ou `.env*` fora do bloco alocado.
- Rodar projeto novo sem antes ter alocado `port_base` (gera colisão a primeira vez que dois projetos rodam simultâneos).
- Consumir porta fora do range `[port_base, port_base+19]` mesmo que "sobre" no host — viola a contabilidade central.

**Why:** colisão real observada em 2026-05-26 (porta `52924` ephemeral atribuída por Vite/Node a dois projetos diferentes). Causa estrutural: Far-West de portas, cada projeto inventava as suas (3000 Next + 8000 FastAPI + 5273 Vite + 3100 Node + ...). Inventário mostrou 6 projetos ativos sem padrão. Solução: source of truth única no Painel (`projects.port_base INT UNIQUE`); bloco de 20 portas por projeto (v6.10.0 — expandido de 10 após observação de que full-stack + tooling consomem >10 slots fácil); range total 3000-9999 = ~349 projetos × 20 portas.

**Garantia de unicidade sob concorrência:** o endpoint `POST /admin/projects/port-allocate` serializa alocações concorrentes via `pg_advisory_xact_lock(4242)` + UNIQUE INDEX `uq_projects_port_base`. Duas chamadas simultâneas do mesmo slug retornam o **mesmo** `port_base` (idempotência); chamadas simultâneas de slugs diferentes recebem blocos diferentes — o advisory lock força ordem, e o UNIQUE INDEX é rede de segurança se o lock for bypassado.

**Tabela de offsets (canônica — bloco de 20, alinhada com [PORT_ALLOCATION_CONSUMER_GUIDE.md](D:/Claud%20Automations/Painel%20Gestao%20e%20Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md) §4.2):**

| Offset | Uso típico |
|---|---|
| `+0` | Dev server principal (Vite/Next/Fastify/uvicorn) |
| `+1` | Preview/build local (`vite preview`, `next start`) — ou backend secundário em full-stack |
| `+2` | Storybook |
| `+3` | Playwright UI mode |
| `+4` | Mock server / MSW |
| `+5` | Backend FastAPI/uvicorn (full-stack) |
| `+6` | Worker (celery/rq/cron-runner) |
| `+7` | Postgres local (se projeto subir Postgres dedicado em vez de usar VPS) |
| `+8` | Redis local (idem Postgres) |
| `+9` | MinIO / object storage local |
| `+10` | Mailhog / dev SMTP UI |
| `+11` | Outro daemon (Tauri sidecar, electron-builder, etc.) |
| `+12..+19` | Reserva — uso livre dentro do projeto, documente no `docs/PORTS.md` |

Convenção é **sugestão**, não trava: projetos full-stack (FastAPI + Next) podem mapear `+1` como backend principal em vez de preview. Decisão do projeto fica em `docs/PORTS.md` ou `README.md` pra agentes futuros / colegas. O que **não** muda: bloco é de **20 portas**, começa em `${PERCUS_PORT_BASE}`, e nenhuma porta exposta no host pode estar fora dele.

**Gate de verificação:**

1. Projeto tem `.percus-ports.json` versionado em git com `port_base`, `range_end`, `unverified: false` (ou `true` só se alocação foi feita offline e ainda não reconciliou — endpoint Painel está vivo em prod desde 2026-05-26, fallback offline é exceção).
2. Configs (`vite.config`, `next.config`, `docker-compose`, `package.json` scripts) referenciam `process.env.PERCUS_PORT_BASE` ou `${PERCUS_PORT_BASE}`, nunca literais.
3. `.env.example` declara `PERCUS_PORT_BASE=NNNN` (placeholder; valor real fica em `.env` local).
4. **`strictPort: true` obrigatório em Vite** (sem isso o Vite cai pra ephemeral e a alocação não tem efeito). Para Next.js: `next dev --port $PERCUS_PORT_BASE` no script de `package.json`. Storybook: `storybook dev -p $((PERCUS_PORT_BASE+2)) --no-open`.
   Se o projeto tinha bloco de 10 (canon ≤v6.9.x) e foi re-alocado pra bloco de 20 (canon ≥v6.10.0), o `port_base` provavelmente mudou — operador re-roda `percus-review:port-allocate`, atualiza `.env`, e re-aplica configs.
5. Convenção escolhida documentada em `docs/PORTS.md` do projeto (mapa offset → serviço real).

**Auditoria visual:** `https://gestao.ads4pros.com/projetos.html` mostra badge `PORTS 3100·3119` em cada card de projeto que tem alocação confirmada (bloco de 20 desde v6.10.0).

**Anti-pattern (item novo no resumo, final do arquivo):** "Hardcode de porta em vite.config/docker-compose depois de alocar `port_base`" — gera colisão silenciosa quando outro projeto pegar a mesma porta literal.

**Refs:**
- Skill: `percus-review:port-allocate` (canon `plugin/percus-review/skills/port-allocate/SKILL.md`)
- Wrapper Python: `plugin/percus-review/scripts/port_allocate.py`
- Endpoint Painel (VIVO em prod): `POST https://api.ads4pros.com/admin/projects/port-allocate` (X-Internal-Auth)
- Manual operacional Painel-side: `Painel Gestao e Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md`
- Migration aplicada: `Painel Gestao e Afiliados/execution/database/migration_port_base.sql`

---

## R23. Base de conhecimento — consultar antes de resolver, registrar depois (v6.19.0)

**Regra:** antes de gastar tempo debugando um problema que **parece conhecido**, consulte
`conhecimento/COMO_RESOLVER.md` (via skill `percus-review:consult-knowledge`). Se houver entrada que
case com a **classe** do sintoma, tente a solução de lá **primeiro**. Depois de resolver um problema
**novo** (não trivial, que custou tempo), **registre** uma entrada nova em `COMO_RESOLVER.md`. Padrões
de procedimento recorrentes vão pra `conhecimento/COMO_FAZER.md`.

**Forbidden:**
- Reabrir do zero um problema já catalogado em `COMO_RESOLVER.md` sem ter consultado (retrabalho).
- Resolver um incidente não-trivial e **encerrar a sessão sem registrar** a solução (conhecimento se perde, próximo projeto redescobre).
- Inventar procedimento de infra (deploy, VPS) divergente do `COMO_FAZER.md` sem atualizar o doc.

**Why:** o conhecimento de incidente ficava espalhado em ADRs + memory isolado por projeto — cada
projeto redescobria os mesmos bugs (prompt stale do council, hooks `.ps1` não-ASCII, etc.). Base única
versionada no git, consultável por **classe de sintoma** (lookup semântico, não grep literal — sintomas
variam em wording/stack/locale), sincroniza pra todas as máquinas via `git pull`.

**Gate de verificação:**
1. `conhecimento/COMO_RESOLVER.md` e `conhecimento/COMO_FAZER.md` existem no canon (sincronizados via git).
2. Ao bater num erro conhecido, há evidência de consulta antes do debug (a skill loga / o agente declara).
3. `CHECKLIST_ENCERRAR_SESSAO.md` tem o passo "problema novo resolvido foi pra COMO_RESOLVER?"; o
   `/checkpoint` reforça (a captura não depende de memória — fica num gate que já roda).

**Refs:**
- Skill: `percus-review:consult-knowledge` (`plugin/percus-review/skills/consult-knowledge/SKILL.md`)
- Base: `conhecimento/COMO_RESOLVER.md`, `conhecimento/COMO_FAZER.md`
- Gate: `checklists/CHECKLIST_ENCERRAR_SESSAO.md`, skill `percus-review:checkpoint`

---

## R24. Cadência de deploy — milestone / fim do dia / sob demanda, NÃO a cada processo (v6.20.0)

**Regra:** o deploy **não** é feito ao fim de cada feature/processo. O **padrão** é deployar em um de
três gatilhos:
1. **Fim de um milestone** (fase/épico fechado e aprovado no `milestone-review`).
2. **Fim do dia de trabalho** (consolidar o que avançou e está `[5-T]`).
3. **Sob solicitação direta do operador** ("deploya agora").

Durante o dia, o trabalho fica em commits locais + ambiente de dev; a produção só recebe nos gatilhos
acima. Deploy continua sujeito ao **R5** (confirmação antes de operação irreversível) e a um **smoke
test pós-deploy** + **rollback pronto** (ver `comandos/DEPLOY.md`).

**Forbidden:**
- Deployar automaticamente ao fim de **cada** feature/commit (desperdiça tempo e recursos — foi a dor
  que originou esta regra).
- Deployar código que não está `[5-T]` (ciclo CRUD testado) sem o operador autorizar o risco em voz alta.
- Deployar sem smoke test pós-deploy (`curl -I` + `docker service logs`) nem plano de rollback.
- Acumular dias de mudança sem deployar **e** sem registrar no HANDOFF o que está pendente de produção.

**Why:** deploy a cada processo consome tempo (build + push + rollout + smoke a cada micro-mudança) e
recursos (CI/Actions, banda, janelas de risco repetidas). Agrupar por milestone/EOD reduz o overhead e
concentra o risco numa janela controlada com smoke + rollback. Sob demanda continua disponível pra
hotfix.

**Gate de verificação:**
1. Deploy aconteceu num dos 3 gatilhos (não per-feature) — rastreável no HANDOFF/commits.
2. Smoke test pós-deploy registrado; rollback documentado e testável (`docker service rollback`).
3. `comandos/DEPLOY.md` é o playbook canônico (quando + como + smoke + rollback).

**Refs:**
- Playbook: `comandos/DEPLOY.md`
- Infra/como: `02_INFRA_E_STACK_PERCUS.md` §6 (VPS), §7 (acesso), §8 (Traefik), §9-10 (deploy/update via Portainer)
- Procedimento: `conhecimento/COMO_FAZER.md#deploy-vps`
- Confirmação irreversível: R5 · Marco: R11 (`milestone-review`)

---

## R25. Single-source-of-truth — não duplicar info; reforço = ponteiro pro único local vigente (v6.24.0)

**Regra:** uma informação tem **um único dono canônico**. Quando ela precisar ser reforçada em outro
lugar, **aponte para o doc canônico vigente** ("ver `X`") — **nunca copie o conteúdo**. O canon
**nunca cita arquivo efêmero/externo não-sincronizado** (planos de trabalho em `.claude-home/plans/*`,
diagnósticos transient, working files) — ref a algo fora do repo sincronizado quebra em qualquer outra
máquina.

**Forbidden:**
- **Duplicar** conteúdo entre docs do canon (a cópia diverge da fonte e gera erro silencioso).
- Citar `.claude-home/plans/*` ou qualquer arquivo de trabalho efêmero como referência (não existe pra quem clona).
- Criar um doc paralelo pra uma função que já tem dono — **edite/aponte o existente** (ver [[feedback_revisar_pasta_antes_de_criar]]: revisar a pasta antes de criar).
- Espalhar a mesma diretiva por vários docs — uma vez no dono canônico, ponteiro nos demais.

**Why:** info espalhada/duplicada diverge com o tempo → o leitor segue a cópia stale e erra. Ref a
arquivo efêmero externo é link morto fora da máquina de origem. Auditoria 2026-06-27 achou ~10 refs a
planos transient + uma família de docs duplicando framing stale ("atualizar projeto") — consolidados
num umbrella único. Princípio declarado pelo operador: "reforço = apontamento pro único local correto".

**Gate de verificação:**
1. Refs a **arquivo real** — `grep -rnE "\.claude-home[/\\\\]plans[/\\\\].+\.md" <canon>` — retornam **0** fora de `CANON_VERSION.md` (changelog histórico) e `.archive/`. (A definição desta R25 menciona o padrão `.claude-home/plans/*` de propósito — menção do padrão ≠ ref a arquivo, não conta.)
2. Nenhuma diretiva nova é **copiada** em 2+ docs — vive no dono canônico, os demais apontam.
3. Antes de criar doc novo numa pasta, confirmar que não há dono existente (revisar a pasta — incidente 2026-06-26).

**Refs:**
- Umbrella de exemplo: `comandos/REORGANIZAR_PROJETO.md` (consolidou a família "atualizar projeto").
- Roteamento mestre (aponta, não duplica): `00_LEIA_PRIMEIRO.md`.

---

## Resumo dos anti-padrões mais comuns

1. ❌ Marcar `[5-T]` sem rodar ciclo CRUD
2. ❌ `toast.success("Salvo!")` em mock
3. ❌ Criar `credentials.json` vazio ou comentar código que requer credencial
4. ❌ Reusar database/role/redis-namespace de outro projeto
5. ❌ Pular brainstorming porque "é simples"
6. ❌ Codar "rapidinho" tela nova sem draft (v0.dev/shadcn)
7. ❌ Encerrar sessão sem atualizar HANDOFF
8. ❌ Avançar status no PLANO sem verificar a condição
9. ❌ Usar GoTrue/PostgREST/Supabase em projeto novo
10. ❌ Reaproveitar JWT_SECRET de outro domínio
11. ❌ Commitar sem rodar `/percus-review:review` antes (R11)
12. ❌ Manter `AGENTS.md` desatualizado em relação ao `CLAUDE.md` — reviewer revisa com regra defasada
13. ❌ Avançar marco sem `/percus-review:milestone-review --base <commit>` do escopo do marco (R11 ampliada)
14. ❌ Rodar DeepSeek em `--apply` direto sem dry-run (R13)
15. ❌ Delegar pra DeepSeek tasks em pasta sensível (auth/payment/migrations) ou sem plano explícito (R13)
16. ❌ Aplicar saída DeepSeek sem trailer `Co-implemented-by: deepseek-v4` no commit (R13 + R11) — router não detecta auto-revisão
17. ❌ Implementar plano com 3+ tasks independentes serialmente em vez de via `superpowers:subagent-driven-development` (R9) — desperdiça contexto principal e tempo
18. ❌ Editar PLANO.md adicionando ✓ sem invocar `percus-review:close-milestone` antes (R11 ampliada)
19. ❌ Refresh JWT stateless (sem family invalidation) — token roubado vale TTL inteiro sem revogação (R7)
20. ❌ Reimplementar magic-link no projeto em vez de consumir `/auth/magic/*` do auth-service (R17)
21. ❌ Acoplar tracking SDK (`?ref=`, cookies de marketing) à lib de auth (R18)
22. ❌ Rate limit por email/IP sem canonicalização (`user+1@`, IPv6 /128) (R15)
23. ❌ Cookie SSO `SameSite=None` cross-domain quando subdomain-shared ou redirect-fragment resolveriam (R16)
24. ❌ Serviço tier-1 (auth, pagamento, webhook) em produção sem traces OTel + audit hash chain (R14)
25. ❌ Admin com username+pwd sem TOTP step-up (R7)
26. ❌ Auth próprio em projeto novo após auth-service v1 publicado (R7) — duplicação proibida
27. ❌ Gerar UUID do pai upfront e INSERT do pai só no final do TX, com filhos sendo flush no meio — viola R21 silenciosamente até primeiro novo registro real
28. ❌ Catch genérico `except IntegrityError` como "race-resolved" sem distinguir UNIQUE viol vs FK viol (R21) — silencia bug por dias
29. ❌ Hardcode de porta literal em `vite.config`/`next.config`/`docker-compose` depois de alocar `port_base` (R22) — gera colisão silenciosa quando outro projeto pegar a mesma porta
30. ❌ Rodar projeto Percus sem ter alocado `PERCUS_PORT_BASE` via skill `port-allocate` (R22) — primeira vez que dois projetos rodam juntos, conflito de porta
31. ❌ Debugar do zero um problema já catalogado em `COMO_RESOLVER.md` sem consultar antes (R23) — retrabalho evitável
32. ❌ Resolver incidente não-trivial e encerrar sessão sem registrar a solução em `COMO_RESOLVER.md` (R23) — conhecimento se perde, próximo projeto redescobre
33. ❌ Deployar a cada feature/commit em vez de agrupar por milestone/fim-do-dia/sob-demanda (R24) — desperdiça tempo e recursos
34. ❌ Deployar sem smoke test pós-deploy nem rollback pronto (R24) — janela de risco sem rede de segurança
35. ❌ Duplicar conteúdo entre docs do canon em vez de apontar pro dono canônico (R25) — cópia diverge e vira erro stale
36. ❌ Citar arquivo efêmero/externo (`.claude-home/plans/*`, working file) como referência no canon (R25) — link morto fora da máquina de origem
