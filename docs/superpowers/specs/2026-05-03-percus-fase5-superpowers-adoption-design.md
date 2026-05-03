# Percus Fase 5 — Superpowers Adoption (Design)

**Data:** 2026-05-03
**Autor:** Claude (sessão Percus) + usuário (Percus)
**Estado:** design aprovado, pendente spec review

---

## 1. Context / Why

### Problema
Após Fase 4 (review cross-provider via DeepSeek + Cross-Claude), foi observado que:
1. **Janela de contexto enche rapidamente** em todos os projetos Percus ativos — sessões longas (>30 turnos) saturam.
2. **Skills do plugin `superpowers` (já instalado a nível de usuário) são subutilizadas:**
   - `subagent-driven-development` quase nunca invocada apesar de R9 mencionar
   - `using-git-worktrees`, `executing-plans`, `writing-skills`: zero uso
   - Causa raiz: agente "esquece" de invocar; canon escrito não basta sem mecanismo
3. **Disciplina humana falha:** R8 (HANDOFF) e R11 (review pre-commit) são esquecidas em ~30-40% das sessões observadas

### Decisões prévias (registradas)
- **Critério de sucesso:** B — adoção forçada de skills/gates (medida via inspeção qualitativa, não métrica de tokens)
- **Tolerância a fricção:** A — alta nos primeiros 7 dias, com calibração ativa
- **Razão:** tokens/tempo/qualidade são consequência de adoção. Sem adoção, métrica é vazia. Hooks são o único mecanismo barato que funciona sem disciplina humana.

### Outcome esperado
- Sessões 60+ turnos viáveis (vs ~30 hoje)
- Adoção de `percus-review:feature-flow` em 80%+ das features novas
- 100% dos commits passam por `/percus-review:review` (gate mecânico)
- 95%+ das sessões com edição de código têm HANDOFF.md atualizado
- Custo DeepSeek mantido em $2-5/mês (target Fase 4 preservado)

---

## 2. Goals

- Adoção forçada de superpowers via 2 hooks bloqueantes (pre-commit, on-stop) e 2 skills internas Percus
- Cobertura mecânica de R8 e R11 (não confiar só em disciplina)
- Skill central `percus-review:feature-flow` que carrega R1+R9+R11+R13 numa invocação (corte de ~70% no contexto consolidado por feature)
- Roll-out em 7 dias com calibração diária

## 3. Non-goals

- **Não substituir** componentes da Fase 4 (DeepSeek + Cross-Claude routing já estável)
- **Não criar plugin novo** — extender o existente `@percus/review`
- **Não automatizar** o que já funciona (R10 design, R13 implementação)
- **Não medir tokens** com instrumentação formal — métrica é qualitativa nos primeiros 7 dias
- **Não remover** Codex como opção em projetos ad-hoc (já deprecado, mas histórico preservado)

---

## 4. Architecture

### 4.1 Camadas

Sistema dividido em **3 camadas com responsabilidades distintas**:

```
┌─────────────────────────────────────────────────────────┐
│ Camada A — SKILLS (memória ativa do agente)             │
│   percus-review:feature-flow      (orquestra R1→R13)           │
│   percus-review:close-milestone   (gate de marco)              │
└─────────────────────────────────────────────────────────┘
                          │ invocadas pelo agente
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Camada B — HOOKS (gates mecânicos do harness)           │
│   pre-commit-check        (bloqueia commit sem review)  │
│   on-stop-check           (bloqueia stop sem HANDOFF)   │
└─────────────────────────────────────────────────────────┘
                          │ disparados pelo Claude Code
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Camada C — CANON + DOCS (fonte de verdade)              │
│   01_REGRAS_INEGOCIAVEIS.md  (R8, R9 atualizadas)       │
│   comandos/USANDO_SUPERPOWERS.md  (guia rápido)         │
└─────────────────────────────────────────────────────────┘
```

**Princípio:** as 3 camadas resolvem problemas diferentes, sem sobreposição:
- Skill resolve "agente esquece de carregar regras"
- Hook resolve "agente esquece de invocar gates"
- Canon resolve "agente não sabe que regra existe"

### 4.2 Componentes

#### Skill `percus-review:feature-flow`

- **Localização:** `plugin/percus-review/skills/feature-flow/SKILL.md`
- **Tamanho alvo:** ~4 KB
- **Trigger:** auto via `description` ("Use when starting any feature or bugfix in a Percus project")
- **Carrega:** fluxo R1→R13 consolidado, tabela de gates, matriz G-DELEGA, marcações R2
- **Referencia (não duplica):** `superpowers:brainstorming`, `:writing-plans`, `:subagent-driven-development`, `:test-driven-development`
- **Ganho:** corte de ~70% no contexto consolidado por feature (4 KB vs 24 KB de regras puxadas avulsas)

#### Skill `percus-review:close-milestone`

- **Localização:** `plugin/percus-review/skills/close-milestone/SKILL.md`
- **Tamanho alvo:** ~1.5 KB
- **Trigger:** auto via `description` ("Use when closing a milestone — end of phase, feature group, or 'next step' transition")
- **Faz:** identifica commit-inicio-marco → roda `/percus-review:milestone-review` → trata findings → marca `✓` no PLANO + HANDOFF
- **Substitui:** hook frágil de pre-marco (descartado por ter heurística de detecção problemática)

#### Hook `pre-commit-check`

- **Localização:** `plugin/percus-review/hooks/pre-commit-check.{ps1,sh}`
- **Trigger:** `PreToolUse` + matcher `Bash`
- **Lógica:**
  1. Lê stdin (JSON com `tool_input.command`)
  2. Se command não contém `git commit` → exit 0
  3. Se `git commit --amend --no-edit` (rebase) → exit 0
  4. Se diff só de docs (heurística por extensão) → exit 0 + warning
  5. Procura mais recente `.deepseek/reviews/*.jsonl`. Se mtime > 5 min → bloqueia
  6. Bloqueio: exit 2 + stderr orientativo
- **Performance:** < 100 ms
- **Falha graceful:** qualquer erro → exit 0 (nunca bloqueia commit por bug do hook)

#### Hook `on-stop-check`

- **Localização:** `plugin/percus-review/hooks/on-stop-check.{ps1,sh}`
- **Trigger:** evento `Stop` do harness
- **Lógica:**
  1. Lê input com `transcript_path`
  2. Parseia transcript JSONL procurando tool calls de `Edit`/`Write`/`NotebookEdit`
  3. Classifica edições:
     - **Código:** `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.sql`, `.go`, `.rs`, `.java`, `.css`, `.html`, `.vue`, `.svelte`
     - **Não-código:** `.md`, `.yml`, `.json`, `.txt`, lockfiles (`package-lock.json`, `yarn.lock`, `requirements.txt`, etc.)
  4. Decisão:
     - Zero edições de código → exit 0 (sessão de consulta, libera)
     - Edições de código + HANDOFF.md modificado nessa sessão → exit 0 (R8 cumprida)
     - Edições de código + HANDOFF não modificado → bloqueia stop
- **Skip válido:** `$env:PERCUS_SKIP_HANDOFF=1` libera com log em `.deepseek/handoff-skipped.log`
- **Performance:** < 300 ms (sessão típica), < 1 s (transcript >5 MB)
- **Falha graceful:** qualquer erro → exit 0

### 4.3 Atualizações no canon (`01_REGRAS_INEGOCIAVEIS.md`)

#### R8 — adicionar gate mecânico

Após o gate atual ("se eu fechar tudo agora..."):

> **Gate mecânico:** plugin `@percus/review` instala hook `on-stop` que bloqueia encerramento de sessão com edições de código se HANDOFF.md não foi atualizado. Pra burlar: `$env:PERCUS_SKIP_HANDOFF=1` antes do Stop, motivo declarado em voz alta. Skip fica logado em `.deepseek/handoff-skipped.log`.

#### R9 — adicionar 2 linhas na tabela + bullet

Adicionar à tabela "Para cada feature nova":

| Início orquestrado | `percus-review:feature-flow` | Toda feature/bugfix não-trivial |
| Execução paralela | `superpowers:subagent-driven-development` | Plano com 3+ tasks independentes — OBRIGATÓRIO |

Após a tabela:
> **Cobertura mecânica:** plugin `@percus/review` instala hook `pre-commit` que bloqueia commit sem `/percus-review:review` rodado nos últimos 5 min (R11 reforço).

#### Anti-padrões — adicionar 2

- 17. ❌ Implementar plano com 3+ tasks independentes serialmente em vez de via `subagent-driven-development` (R9)
- 18. ❌ Editar PLANO.md adicionando ✓ sem invocar `percus-review:close-milestone` antes (R11 ampliada)

### 4.4 Documentação `comandos/USANDO_SUPERPOWERS.md`

Guia de bolso ~1.2 KB com tabela de skills (Tier 1 obrigatórias, Tier 2 otimizações, internas Percus). Linkado de R9.

---

## 5. Data flow

### Fluxo de feature nova (caminho feliz)

```
Você: "implementa endpoint de produtos"
   │
   ▼
Agente: auto-invoca `percus-review:feature-flow` (description matcher)
   │
   ▼ (carrega 4 KB de fluxo consolidado)
   │
Agente: invoca `superpowers:brainstorming` (R9)
Agente: invoca `superpowers:writing-plans` (R9, 4 tasks)
   │
   ▼ G-DELEGA aplicada
   │
   ├──► Tasks mecânicas → DeepSeek wrapper + trailer
   ├──► Tasks arquiteturais → Claude direto
   └──► 3+ tasks indep. → `superpowers:subagent-driven-development`
   │
Agente: TDD (R9) → executa código
Agente: pipeline R2 [0]→[5-T]
   │
   ▼
Agente: git commit
   │
   ▼
HOOK pre-commit: checa .deepseek/reviews/*.jsonl
   │
   ├──► review > 5min OU ausente → BLOQUEIA, agente roda /percus-review:review
   └──► review fresco → LIBERA
   │
   ▼
[ciclo repete por feature, marco fechado]
   │
Agente: invoca `percus-review:close-milestone` ao fechar fase
   │
   ▼
Agente: roda /percus-review:milestone-review --base <commit>
Agente: marca ✓ no PLANO + HANDOFF
   │
   ▼
Você: "ok valeu"
   │
   ▼
Agente: tenta Stop
   │
   ▼
HOOK on-stop: parseia transcript
   │
   ├──► zero edição de código → LIBERA silencioso
   ├──► edição de código + HANDOFF atualizado → LIBERA
   └──► edição de código + HANDOFF não atualizado → BLOQUEIA
        └──► (escape: $env:PERCUS_SKIP_HANDOFF=1)
```

---

## 6. Error handling

| Falha | Comportamento |
|---|---|
| Hook script crash (PowerShell ausente, etc) | exit 0 graceful — nunca bloqueia workflow |
| Transcript path inválido | exit 0, log em stderr |
| `.deepseek/reviews/` ausente em projeto ainda não migrado | hook detecta + exit 0 + warning "rode SETUP_REVIEW_ROUTING primeiro" |
| Skill `feature-flow` ignorada pelo agente (não auto-trigger) | comportamento antigo, sem regressão — aceita-se na V1, calibra description no D7 |
| DeepSeek API down durante hook | irrelevante — hook só checa filesystem, não chama DeepSeek |
| `/percus-review:review` falha durante o uso (não no hook) | router fallback Cross-Claude (já existente Fase 4) |

---

## 7. Testing strategy

### Testes manuais (smoke)

- **T1 — Plugin install end-to-end** (depende de fix de marketplace.json wrapper):
  - `/plugin marketplace add D:/Claud Automations/_Novo_Projeto/plugin`
  - `/plugin install percus-review`
  - Verificar: `/plugin` lista percus-review + 4 commands + 2 skills

- **T2 — Hook pre-commit bloqueia:**
  - Em projeto Fase 4, fazer Edit em arquivo `.py`
  - `git add` + `git commit -m "test"`
  - Esperado: bloqueio com mensagem orientativa
  - Rodar `/percus-review:review`, commitar de novo → libera

- **T3 — Hook pre-commit libera commit só de docs:**
  - Edit em `*.md`, `git commit`
  - Esperado: passa com warning "commit só de docs, R11 dispensa"

- **T4 — Hook on-stop em sessão de consulta:**
  - Sessão só de leitura (Read, Grep)
  - Stop
  - Esperado: libera silencioso, zero atrito

- **T5 — Hook on-stop bloqueia legítimo:**
  - Edit em `.tsx`, commit, sem atualizar HANDOFF
  - Stop
  - Esperado: bloqueia com mensagem orientativa
  - Atualizar HANDOFF, Stop de novo → libera

- **T6 — Skill `feature-flow` auto-invocada:**
  - Em sessão nova, dizer "implementa feature X"
  - Esperado: agente invoca a skill (visível no transcript)

- **T7 — Skill `close-milestone` invocada explícita:**
  - Dizer "fechamos a Fase 1"
  - Esperado: agente invoca a skill, roda milestone-review, marca ✓

### Validação qualitativa (D+7)

5 perguntas curtas pro usuário (ver Roll-out plan).

### Validação de não-regressão

- Custo DeepSeek na semana < $2 (sinal de que routing não foi quebrado)
- Zero reclamação de "feature deixou de funcionar" (R10, R13 intactos)

---

## 8. Roll-out plan

| Dia | Atividade | Tempo |
|---|---|---|
| **D1** | **T0a — Smoke test:** validar formato `tool_input.command` no hook `PreToolUse` matcher `Bash` (criar hook minimal que só `echo` o stdin recebido, disparar via Bash trivial, conferir formato real vs esperado pelo spec) | ~15 min |
| **D1** | **T0b — Smoke test:** validar evento `Stop` recebe `transcript_path` (mesma técnica — hook minimal `echo` stdin) | ~15 min |
| **D1** | Resolver problema de instalação — criar `.claude-plugin/marketplace.json` wrapper (ver **Anexo A**) | ~15 min |
| **D1** | Criar 2 skills (feature-flow, close-milestone) — feature-flow inclui nota explícita "INVOQUE `/percus-review:review` ativamente, não espere o hook bloquear" | ~1 h |
| **D1** | Criar 2 hooks (pre-commit, on-stop) + handlers PS+SH — formato baseado nos resultados de T0a/T0b | ~1 h |
| **D1** | Editar canon (R8, R9, anti-padrões) | ~20 min |
| **D1** | Criar `USANDO_SUPERPOWERS.md` | ~20 min |
| **D1** | Atualizar `SETUP_REVIEW_ROUTING.md` + `UPGRADE_PARA_FASE4.md` (nova sintaxe) | ~30 min |
| **D2** | Smoke tests T1-T7 num projeto Fase 4 (ex: Padrão Comportamento Humano) | ~1 h |
| **D2** | Reinstalar plugin nos projetos Fase 4 já existentes | ~30 min |
| **D3-7** | Uso real + calibração | uso normal |
| **D7** | Retrospectiva + decisão de promoção pra estado canônico | ~30 min |

### Critérios de pivô

- **Pivô leve:** >2 falsos positivos no on-stop em 24h → adicionar extensão à lista de ignore
- **Pivô médio:** feature-flow auto-invocada em **menos de 4 das próximas 5 features novas observadas** → reescrever `description` ou aceitar invocação manual reforçada em R9
- **Rollback completo:** 5+ reclamações de fricção/dia OU custo DeepSeek > $10/semana → desativar hooks via `$env:PERCUS_HOOKS_DISABLED=1`

### Mínimo viável de calibração (para D7 retrospectiva ter base)

Pra retrospectiva D7 ter dados suficientes:
- **Mínimo:** 5+ features novas iniciadas + 10+ commits totais entre D3 e D7
- **Se uso real for menor:** prolongar janela de calibração até D14 antes de promover pra estado canônico
- **Métrica de adoção feature-flow:** contar invocações em `git log --grep` ou inspeção de transcripts. Se < 4/5 features observadas, dispara pivô médio.
- **Métrica on-stop:** contar entradas em `.deepseek/handoff-skipped.log` por dia. > 1/dia consistente sinaliza fricção indevida.

---

## 9. Risks

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Falha de instalação do plugin (sintoma atual) | Alta | Resolver D1 com wrapper marketplace.json |
| `feature-flow` auto-trigger não funciona | Média | Tunar description, fallback pra invocação manual via R9 |
| Hook on-stop tem falsos positivos | Média | Lista de extensões "código" tunável + skip flag |
| Hook pre-commit irrita | Baixa | Agente adapta no 1º bloqueio, mensagem orientativa |
| Custo DeepSeek dispara | Baixa | Monitorar dashboard, threshold de 5 min do hook é conservador |
| Skills competem com superpowers existentes | Baixa | feature-flow referencia (não duplica) skills do `superpowers-dev` |
| Plugin não suporta hooks declarados em manifest | Baixa-Média | Fallback: registrar hooks em `~/.claude/settings.json` via SETUP |

---

## 10. Dependencies

- Plugin `@percus/review` (Fase 4) — base instalada
- Plugin `superpowers-dev` v5.0.5+ — instalado a nível de usuário
- DeepSeek API funcional — `DEEPSEEK_API_KEY` em cada projeto
- PowerShell 5.1+ (Windows) ou Bash 4+ (Linux/Mac/WSL) — pra hooks
- Claude Code v2.x+ — suporte a hooks declarados em plugin manifest

---

## 11. References

- **Canon:** `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` (R8, R9, R11, R13)
- **Plugin existente:** `D:/Claud Automations/_Novo_Projeto/plugin/percus-review/`
- **Memória Percus:** `project_fase4_review_routing.md`, `reference_review_matriz.md`
- **Plugin superpowers:** `~/.claude/plugins/superpowers-dev/skills/`
- **Decisões registradas:** transcript da sessão 2026-05-03 (brainstorming)
- **Bloqueador identificado:** problema de instalação `/plugin install <path>` falhando — fix com wrapper marketplace.json no D1

---

## 12. Open questions / parking lot

Itens fora do escopo da V1, registrados pra revisita:

- Hook que bloqueia `git commit --no-verify` (escape de hook pre-commit)
- Skill `percus:start-session` que executa CHECKLIST_INICIO_SESSAO automaticamente
- Métrica formal de tokens consumidos (instrumentação) — adiar pra Fase 6 se necessário
- Integração `percus-review:feature-flow` com `superpowers:executing-plans` em sessão separada (otimização Tier 2)
- Hook que detecta uso de `localStorage` em código TS (R7 reforço mecânico)
- **Git invocado fora da Bash tool não é detectado pelo hook pre-commit.** Cenário raro em Percus (DeepSeek wrapper não commita; subagentes geralmente delegam volta pro main). Documentar limitação em R13 quando virar problema. Eventual mecanismo: hook `PostToolUse` + Stop hook que detecta commits feitos via subprocess próprio comparando `git log` antes/depois da sessão.

---

## Anexo A — `marketplace.json` wrapper para instalação local do plugin

**Problema observado:** `/plugin install <path>` direto não funciona no Claude Code v2.x — comando espera `marketplace_source` que aponta pra um diretório com `.claude-plugin/marketplace.json` registrando os plugins disponíveis.

**Solução:** criar wrapper em `D:/Claud Automations/_Novo_Projeto/plugin/.claude-plugin/marketplace.json` (1 nível acima do plugin `percus-review/`):

### Estrutura de pastas final

```
D:/Claud Automations/_Novo_Projeto/plugin/
├── .claude-plugin/
│   └── marketplace.json          ← wrapper criado
└── percus-review/
    ├── plugin.json
    ├── commands/
    ├── scripts/
    └── (Fase 5) skills/, hooks/
```

### Conteúdo do `marketplace.json`

```json
{
  "name": "percus-tools",
  "description": "Percus internal tooling — review cross-provider plugin",
  "owner": { "name": "Percus" },
  "plugins": [
    {
      "name": "percus-review",
      "description": "Review cross-provider Percus (DeepSeek + Cross-Claude)",
      "version": "1.0.0",
      "source": "./percus-review"
    }
  ]
}
```

### Como usar (substitui doc atual de SETUP_REVIEW_ROUTING.md Passo 2)

```
/plugin marketplace add D:/Claud Automations/_Novo_Projeto/plugin
/plugin install percus-review
```

A primeira linha **registra o marketplace** (a pasta `_Novo_Projeto/plugin/` que tem o `.claude-plugin/marketplace.json`).
A segunda linha **instala o plugin** pelo nome (`percus-review`) registrado no marketplace.

Após instalado, o plugin fica em `~/.claude/plugins/` a nível de usuário, disponível em todos os projetos.

### Atualização do SETUP_REVIEW_ROUTING.md

Após implementar Fase 5, atualizar `comandos/SETUP_REVIEW_ROUTING.md` Passo 2 com a sintaxe acima. Atualizar também `comandos/UPGRADE_PARA_FASE4.md` Caminho B/C com a mesma instrução.

### Validação

```powershell
# Após instalação
Get-ChildItem "$env:USERPROFILE\.claude\plugins" | Where-Object { $_.Name -match 'percus' }
# Esperado: pasta percus-review listada

# No chat Claude Code
/plugin
# Esperado: percus-review listado como instalado, com 4 commands + (Fase 5) 2 skills + 2 hooks
```
