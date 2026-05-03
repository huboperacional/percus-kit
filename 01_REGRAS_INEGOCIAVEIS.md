---
tipo: regras-universais
prevalece-sobre: [02_INFRA_E_STACK_PERCUS, comandos/*, templates/*]
prevalecido-por: [CLAUDE.md do projeto atual]
quando-usar: SEMPRE que executar trabalho em projeto Percus
leitura: 8 min
ultima-atualizacao: 2026-04-25
---

# 01 — Regras Inegociáveis

> Cada regra abaixo tem **gate verificável**. Se você não consegue verificar, a regra não foi cumprida — não invente que cumpriu.
> Ordem das seções por frequência de uso, não por importância.

---

## Convenção de paths neste arquivo

Paths citados nas regras seguem duas formas:

- **Path absoluto** (`D:/Claud Automations/_Novo_Projeto/...`): aponta para arquivo do **kit Percus** (regras, templates, comandos, scripts auxiliares). NÃO existe no repo do projeto que está sendo revisado — é referência cross-projeto. Vale para toda regra que entra em `AGENTS.md` via transclusão (R10, R11, R13).
- **Path relativo** (`docs/...`, `HANDOFF.md`, `CLAUDE.md`): aponta para arquivo **dentro do repo do projeto atual**. É criado pelos templates do kit no setup inicial.

**Para revisores não-Claude (Codex, etc.):** se um path absoluto começando com `D:/Claud Automations/_Novo_Projeto/` for citado, **NÃO** trate como referência morta no repo do projeto — é arquivo do kit, fora do repo, propositalmente externo.

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

**Por que marcações em vez de novas tags `[6-R]`/`[7-D]`:** R2 é um pipeline linear (técnico). Codex review é gate cross-cutting (commit + marco), DeepSeek é mecanismo de execução. Ambos ortogonais ao pipeline — viram metadata, não fase.

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

**Regra:** Todo projeto novo usa **OTP via WhatsApp + JWT próprio em FastAPI**. Detalhes em `02_INFRA_E_STACK_PERCUS.md` Seção 2.

**Vetado em projetos novos:** GoTrue, PostgREST, `@supabase/supabase-js`, NextAuth, magic-link puro sem WhatsApp, senha pura sem 2FA.

**Projetos legados:** seguem `comandos/MIGRAR_AUTH.md`. Não improvise migração ad-hoc.

**JWT_SECRET dedicado:** nunca reaproveite secret de outro domínio (NEXTAUTH, public-token, webhook). Cada um tem o seu.

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

**Anti-padrão proibido:** pular brainstorming porque "já sei o que fazer". TDD opcional. Code-review pulado em bulk edit. Implementar plano grande serialmente quando subagent-driven-development cabe.

**Guia rápido de skills:** `comandos/USANDO_SUPERPOWERS.md`.

**Detalhes do fluxo passo-a-passo:** `checklists/CHECKLIST_FEATURE_NOVA.md`.

---

## R10. Design — gate por trigger lexical (v0.dev + shadcn MCP, NÃO Claude artifacts)

**Regra:** Se o pedido contém qualquer um destes triggers, **PARE antes de codar** e siga `D:/Claud Automations/_Novo_Projeto/comandos/DESIGN_WORKFLOW.md`:

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
> Essa tarefa é visual. Antes de codar, vou seguir `D:/Claud Automations/_Novo_Projeto/comandos/DESIGN_WORKFLOW.md`:
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

Justificativa do design: dois provedores diferentes (DeepSeek Inc + Anthropic) cobrem viés de modelo de cada um. Cross-Claude é grátis (consome plano Claude). DeepSeek é ~$0.02/call. Custo agregado mensal estimado: $2-5.

### Quando dispara

1. **Antes de cada `git commit`** que muda código (não vale para commits só de docs/configs).
2. **Ao concluir cada marco** de plano em execução — fim de fase numerada (Fase 1, Fase 2…), conclusão de feature dentro de épico, ou ponto onde o agente diria *"pronto, próxima etapa"*. O escopo da revisão de marco é o **conjunto** de mudanças do marco (não só do último diff).

### Setup primeira vez

Seguir `D:/Claud Automations/_Novo_Projeto/comandos/SETUP_REVIEW_ROUTING.md`. Cada projeto precisa de:
- `DEEPSEEK_API_KEY` no `.env`
- Plugin `@percus/review` instalado (uma vez globalmente)
- `AGENTS.md` na raiz (template em `D:/Claud Automations/_Novo_Projeto/templates/AGENTS.template.md`) — sem isso, o reviewer revisa cego

### Tratamento de findings

- **Bug ou regressão:** corrigir antes de commitar
- **Risco / violação de regra Percus:** corrigir antes de commitar **OU** declarar em voz alta por que está ignorando
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

### Exceção estrutural — kit Percus (`_Novo_Projeto/`)

O próprio kit de iniciação (`D:/Claud Automations/_Novo_Projeto/`) é **exceção a R11**. Mudanças nele (regras, templates, comandos, scripts auxiliares) **não exigem review** porque:

1. Kit é convenção/regra, não código de produção
2. Reviewer precisaria de `AGENTS.md` espelhando R1-R13 — manter sincronizado seria atrito puro
3. Auditoria do kit é feita por revisão humana + outro Claude paralelo (cross-Claude na própria sessão) — suficiente para o tipo de mudança que o kit recebe

Mudanças no kit ainda devem: (a) ser feitas via plano explícito, (b) ser revisadas pelo usuário antes de virar canon, (c) passar por verificação de consistência cruzada (greps de referências mortas, validação de sintaxe).

**Esta exceção NÃO se estende a projetos reais.** Todo projeto Percus mantém R11 ampliada (commit + marco) sem afrouxamento.

---

## R12. Toda regra precisa de verificação verificável

**Meta-regra:** Se uma regra não tem como você verificar objetivamente que cumpriu, ela é decoração. Se você se pegar pensando "acho que cumpri", você não cumpriu — vá verificar.

**Para R1-R11 e R13**, a coluna "gate de verificação" ou "como verificar" é o ponto crítico. Quando ausente, a regra não está apta a ser auditada — nesse caso, peça ao usuário para esclarecer.

---

## R13. Roteamento de modelos — DeepSeek implementa, Claude arquiteta, Codex revisa

**Regra:** Tarefas de implementação **mecânica** devem ser delegadas ao DeepSeek V4 via wrapper `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.{ps1,sh}`, seguindo o playbook em `D:/Claud Automations/_Novo_Projeto/04_MODEL_ROUTING.md` seção "Como delegar". Saída do DeepSeek é tratada como **rascunho** — sempre revisada por Claude (validação contra R1–R12) e por Codex (R11) antes de virar commit. **Decisões arquiteturais permanecem com Claude.**

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
- Tasks visuais (segue R10 + `D:/Claud Automations/_Novo_Projeto/comandos/DESIGN_WORKFLOW.md`)

**Gate de verificação:**
1. `DEEPSEEK_API_KEY` carregada na sessão
2. Output do DeepSeek inspecionado em `--dry-run` antes de aplicar
3. Validação contra R1–R12 antes de aceitar
4. `/percus-review:review` (R11) sobre o resultado antes de marco/commit — router detecta trailer `Co-implemented-by: deepseek-v4` e roteia pra Cross-Claude

**Anti-padrão proibido:** rodar DeepSeek em `--apply` direto sem dry-run; ou aceitar saída sem validação Claude + Codex.

**Exceções declaráveis em voz alta:**
- Task tão pequena que delegação tem mais overhead que ganho (ex.: trocar 1 string)
- DeepSeek API down — implementa direto no Claude e marca em voz alta
- Plano não está pronto ainda — volta pro arquiteto antes de delegar

**Detalhes operacionais:** `D:/Claud Automations/_Novo_Projeto/04_MODEL_ROUTING.md` (matriz + playbook completo). Wrapper: `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.{ps1,sh}`.

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
