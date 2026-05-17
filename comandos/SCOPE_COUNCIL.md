---
tipo: comando-pronto
quando-usar: dia 1 de greenfield Percus, após templates iniciais e antes de fechar PLANO.md inicial
nao-toca-codigo: true
leitura: 3 min (execução: ~25 min com 3 etapas)
ultima-atualizacao: 2026-05-17
---

# Scope Council — mitigação de viés cross-provider no início de projeto

> **Cole o prompt abaixo no chat do Claude Code do projeto greenfield.**
>
> Ataca o gap de "Plan mode + Brainstorming sozinhos cobrem ~70-80% da decisão de scope/stack inicial, mas têm viés Anthropic-only". Solução: 3 etapas reusando o conselho 3-membros (DeepSeek + Groq-Llama + Cross-Claude) já configurado no plugin Fase 6+.
>
> **Atualização 2026-05-17 (Fase 6):** Etapas 2 e 3 do desenho original (2026-05-04) eram sequenciais e usavam só DeepSeek + 1 subagent. Agora rodam em **uma única chamada** via `/council:pre-mortem` (ou `council-orchestrator.ps1 -Mode pre-mortem`) com 3 providers em paralelo. Mais barato, mais rápido, mais perspectivas.

---

## Quando rodar

**SIM rodar:**
- Projeto vale 1+ mês de trabalho dedicado
- Decisão de stack ainda aberta (Next.js? FastAPI? T3?)
- MVP scope ainda não cristalizado
- Você não está sob pressão de tempo (decisão > velocidade)
- Mercado novo / produto novo / target audience nova

**PULAR:**
- Ferramenta interna 1-2 semanas (overhead > ganho)
- Stack já decidida por restrição externa (cliente exige X)
- Re-escrita seguindo arquitetura conhecida
- Você está em hot-fix / urgência

**Pergunta de gate:** "Esse projeto vale 1+ mês de trabalho dedicado E tenho decisão de stack/scope ainda aberta?"  
- **Sim** → roda o council
- **Não** → pula, segue greenfield default sem council

---

## Custo e tempo

- **Etapa 1** (Claude principal): ~10 min, $0 (plano já)
- **Etapa 2** (conselho 3-membros pre-mortem, paralelo): ~1 min, ~$0.005 (DeepSeek + Groq-Llama API; Cross-Claude via subagent, plano já)
- **Etapa 3** (síntese humana): ~10 min, $0
- **Total:** ~25 min, ~$0.005

> Custo caiu 10x vs versão 2026-05-04 ($0.05 → $0.005) e perspectivas dobraram (de 2 críticos pra 3) — mérito do conselho 3-membros Fase 6.

---

## Pré-requisitos

- Templates iniciais criados (CLAUDE.md, AGENTS.md, HANDOFF.md, docs/PLANO.md, docs/mock-audit.md, .gitignore)
- `DEEPSEEK_API_KEY` no .env
- `GROQ_API_KEY` no .env (Fase 6 — obter free em console.groq.com)
- `ANTHROPIC_API_KEY` no .env (opcional — se ausente, Cross-Claude vai por marker+subagent em vez de wrapper direto, funcional mesmo assim)
- Plugin percus-review instalado na versão canônica atual (ver `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`). `/council:pre-mortem` foi adicionado em v6.1.0 — qualquer v6.x+ funciona.
- `docs/scope-council/` ainda não existe (será criado)

---

## Prompt para colar

```
Vou rodar SCOPE_COUNCIL.md neste projeto greenfield. Confirme antes de cada etapa.

GATE — pergunta inicial:
1. Esse projeto vale 1+ mês de trabalho dedicado?
2. Decisão de stack/MVP ainda está aberta?

Se ambas SIM, prossiga. Se uma das duas NÃO, reporta isso ao usuário e pergunta se quer pular o council e seguir greenfield default.

ETAPA 1 — Análise solo Claude principal (~10 min, $0):
Lê CLAUDE.md, AGENTS.md, HANDOFF.md, docs/PLANO.md (estados iniciais).
Produz análise estruturada em docs/scope-council/scope-draft.md com:
1. MVP em 1 mês: 3-4 features no máximo (justifique cada uma)
2. Stack proposta + motivação por trade-off (alternativas consideradas)
3. Top 3 riscos arquiteturais nesse scope
4. Top 2 assumptions silenciosas (coisas tomadas como dadas que talvez não devessem)
5. Métricas de sucesso aos 30 dias (quantitativas, não "vai dar certo")

NÃO escreva código nessa etapa. Só análise.

Após Etapa 1, mostra ao usuário e aguarda confirmação pra Etapa 2.

ETAPA 2 — Conselho 3-membros pre-mortem (~1 min paralelo, ~$0.005):
Copie docs/scope-council/scope-draft.md pra /tmp/council-plan.txt (orchestrator le de path absoluto).

Voce mesmo (agente) roda — NAO peça pro user colar slash command:

  pwsh -NoProfile -ExecutionPolicy Bypass -File "${env:CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" `
      -PromptFile "/tmp/council-plan.txt" `
      -Mode pre-mortem `
      -Providers "deepseek,groq-llama,cross-claude"

(Se nao houver $env:CLAUDE_PLUGIN_ROOT no contexto, descubra com:
  Get-ChildItem "$env:CLAUDE_CONFIG_DIR\plugins\cache\percus-tools\percus-review" -Directory | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
 e use esse path.)

System prompt do mode pre-mortem ja esta otimizado: "Voce e consultor de pre-mortem Percus. Leia o plano e responda: SE este plano falhar em 30 dias, por que? Liste exatamente 3 motivos concretos em ordem de probabilidade decrescente, com 1 frase cada."

Se stderr tiver __PERCUS_NEEDS_CROSS_CLAUDE__ (acontece quando ANTHROPIC_API_KEY ausente, ou wrapper direto desabilitado):
1. Le o bloco entre ---PROMPT--- e ---END-PROMPT--- no stderr
2. Dispatch Sonnet subagent via Agent tool (subagent_type=general-purpose, model=sonnet) com esse prompt
3. Salva resposta em /tmp/council-cc.txt
4. Re-invoca o orchestrator passando -CrossClaudeFile "/tmp/council-cc.txt"

Le ultimo log em .deepseek/council-log/<ts>-pre-mortem.jsonl. Cada provider retornou 3 motivos.

Agrupe motivos por similaridade (manual ou inline). Risco que >=2 providers apontaram = **risco critico**.

Salva resumo agrupado em docs/scope-council/scope-pre-mortem.md (com tabela "consenso vs isolados" + recomendacoes de mitigacao por risco critico).

Apos Etapa 2, mostra ao usuario os 3 outputs lado-a-lado (Etapa 1 scope-draft + Etapa 2 pre-mortem agrupado) e pede pra ele(a) fazer Etapa 3.

ETAPA 3 — Síntese humana (~10 min, $0):
Você (usuário) lê os 3 outputs. Decide:
- Quais críticas atender → vão pro PLANO.md inicial como decisões consideradas
- Quais ignorar → declare em voz alta por quê
- Onde os 3 concordam → sinal forte
- Onde divergem → você arbitra com motivação

Resultado: PLANO.md inicial atualizado com scope-final + seção "Decisões consideradas no scope-council" referenciando docs/scope-council/.

Os 2 outputs intermediários (scope-draft + scope-pre-mortem) ficam em docs/scope-council/ pra trilha de auditoria.

R5 ativo: confirma comigo antes de qualquer commit, criação de DB/role, ou operação paga durante o council.
Não toque em código de negócio durante o council. Só análise + arquivos em docs/scope-council/.
```

---

## Estrutura de saída esperada

```
docs/
├── PLANO.md                          ← versão final pós-council
├── scope-council/
│   ├── scope-draft.md                ← Etapa 1 (Claude principal)
│   └── scope-pre-mortem.md           ← Etapa 2 (conselho 3-membros agrupado)
└── HANDOFF.md                        ← nota referenciando scope-council/
```

`PLANO.md` final tem header opcional:
```markdown
## Scope-Council aplicado em 2026-05-04
Outputs em `docs/scope-council/`. Decisões adotadas:
- {lista do que foi mudado vs scope-draft inicial}
- {lista do que foi ignorado e por quê}
```

---

## Limitações conhecidas

1. **Council não substitui entrevista com cliente real.** É um cross-check de viés do agente, não validação de mercado. Se o projeto depende de entender mercado, faça research separadamente (não substitui).

2. **Trilha de auditoria opcional.** `docs/scope-council/` pode ser .gitignored se você não quiser comitar análises iniciais. Default: comitar (vira parte da história do projeto).

3. **Cross-Claude via marker quando wrapper direto desabilitado.** Se `ANTHROPIC_API_KEY` não estiver no .env, o orchestrator emite `__PERCUS_NEEDS_CROSS_CLAUDE__` em stderr e o agente Claude tem que dispatchar Sonnet subagent via Agent tool, salvar resposta em arquivo, e re-invocar com `-CrossClaudeFile`. Funcional, só adiciona ~30s de latência humana de copy-paste do agente. Pra rodar 100% paralelo (mais rápido + cache hits potenciais quando SystemPrompt enriquecido — ver `_AUDIT_2026-05-17_eixo-f-pos-entrega.md` finding F.1), adicionar `ANTHROPIC_API_KEY`.

## Histórico

- **2026-05-04** (versão inicial): 4 etapas, Etapa 2 = DeepSeek solo via wrapper `percus-review-auto.ps1` (que era otimizado pra diff git, não markdown), Etapa 3 = Sonnet subagent challenger. Custo ~$0.05. Limitação: 2 críticos sequenciais, prompt R11 mal-encaixado pra scope-draft.
- **2026-05-17** (Fase 6 v6.1.0+): 3 etapas, Etapa 2 = conselho 3-membros pre-mortem paralelo via `council-orchestrator.ps1 -Mode pre-mortem`. Custo ~$0.005 (10x menor). 3 perspectivas críticas em vez de 2. System prompt pre-mortem já otimizado pra "se falhar em 30 dias, por quê".

---

## Anti-padrões

- ❌ Pular Etapa 1 ("Claude já tem opinião desde o brainstorming"). Etapa 1 produz artefato escrito com motivações — vital pra Etapa 2 ter o que criticar.
- ❌ Rodar Etapa 2 sem ler Etapa 1 primeiro — sem o draft, conselho não tem escopo definido pra criticar.
- ❌ Aceitar todas as críticas sem julgamento — council é insumo, não comando. Você decide.
- ❌ Marcar PLANO.md como "definitivo" sem fazer Etapa 3 — sem síntese humana, council vira teatro.
- ❌ Repetir council a cada decisão pequena — é gate de início de projeto, não ferramenta de iteração.
- ❌ **Agente pedir pro user colar slash command pra rodar Etapa 2** — orchestrator roda via Bash tool. Slash command `/council:pre-mortem` é a doc do flow, não o gatilho que o agente passa pro user.

---

## Quando NÃO usar este comando

- **Projeto em andamento** — usa `/percus-review:milestone-review --base <commit>` pra revisar mudanças de fase (já é dual)
- **Decisão pontual** durante implementação — Plan mode + 3 Plan agents paralelos cobre
- **Bug fix** — `superpowers:systematic-debugging` (1 LLM rápido)
- **Feature nova dentro de épico já decidido** — `superpowers:brainstorming` + `superpowers:writing-plans` cobrem

---

## Referências

- Brainstorm pré-council: `superpowers:brainstorming` (skill superpowers, não Percus)
- Plan agents paralelos: Plan mode com 3 Plan agents (cobre subset do council pra decisões menores)
- R11 (review cross-provider obrigatório): `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`
- Wrapper auto-trigger: `scripts/percus-review-auto.ps1` (Windows) / `.sh` (Unix)
- Justificativa pra não adotar `llm_council_skill` externo: análise comparativa em sessão de 2026-05-04 — concluiu que padrão "council" só vale em decisões raras e custosas, e implementação enxuta interna cobre o caso sem dependências externas
