---
tipo: comando-pronto
quando-usar: dia 1 de greenfield Percus, após templates iniciais e antes de fechar PLANO.md inicial
nao-toca-codigo: true
leitura: 3 min (execução: ~30 min com 4 etapas)
ultima-atualizacao: 2026-05-04
---

# Scope Council — mitigação de viés cross-provider no início de projeto

> **Cole o prompt abaixo no chat do Claude Code do projeto greenfield.**
>
> Ataca o gap de "Plan mode + Brainstorming sozinhos cobrem ~70-80% da decisão de scope/stack inicial, mas têm viés Anthropic-only". Solução: 4 etapas reusando providers já configurados (Claude principal + DeepSeek + Cross-Claude Sonnet). Zero tool externo.

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
- **Etapa 2** (DeepSeek cross-provider): ~5 min, ~$0.02
- **Etapa 3** (Cross-Claude challenger): ~5 min, $0 (subagent, plano já)
- **Etapa 4** (síntese humana): ~10 min, $0
- **Total:** ~30 min, ~$0.05

---

## Pré-requisitos

- Templates iniciais criados (CLAUDE.md, AGENTS.md, HANDOFF.md, docs/PLANO.md, docs/mock-audit.md, .gitignore)
- DEEPSEEK_API_KEY no .env
- Plugin percus-review v5.0.9+ instalado (pra wrapper auto-trigger funcionar)
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

ETAPA 2 — DeepSeek cross-provider review (~5 min, ~$0.02):
Stage docs/scope-council/scope-draft.md (git add).
Roda: pwsh -File "D:\Claud Automations\_Novo_Projeto\scripts\percus-review-auto.ps1"
Wrapper vai disparar DeepSeek com prompt R11 padrão (revisor cross-provider).
NOTA: prompt padrão revisa CÓDIGO. Pra revisar SCOPE-DRAFT (markdown), use comando explícito alternativo:

  pwsh -File "<plugin-path>/scripts/deepseek-review.ps1" + ajuste de prompt no system message do wrapper

Se o wrapper não tem opção de prompt customizado, adapte: roda wrapper normal, e na etapa de síntese (4) você (humano) interpreta os findings DeepSeek como "feedback sobre o scope-draft" em vez de bugs.

Output: docs/scope-council/scope-deepseek-review.md (cole o output do wrapper aqui).

Após Etapa 2, mostra ao usuário e aguarda confirmação pra Etapa 3.

ETAPA 3 — Cross-Claude challenger (~5 min, $0):
Dispara Sonnet subagent via Agent tool (subagent_type=general-purpose) com prompt:

> Você é o adversário do scope-draft em docs/scope-council/scope-draft.md. Lê o draft com olho crítico e responde:
> 1. Quais 3 coisas mais prováveis de matar esse projeto em 90 dias se seguirmos esse scope/stack como está?
> 2. Onde o draft está sendo otimista? Cite trecho específico do draft + por quê parece otimista.
> 3. Que decisão de stack/scope alguém com 10 anos de experiência em produtos similares faria diferente? Por quê?
> 4. Que assumption silenciosa o draft fez que você não faria?
> Seja direto, não hedge. Aponta com nome e linha.

Salva output em docs/scope-council/scope-challenger.md.

Após Etapa 3, mostra ao usuário os 3 outputs lado-a-lado e pede pra ele(a) fazer Etapa 4.

ETAPA 4 — Síntese humana (~10 min, $0):
Você (usuário) lê os 3 outputs. Decide:
- Quais críticas atender → vão pro PLANO.md inicial como decisões consideradas
- Quais ignorar → declare em voz alta por quê
- Onde os 3 concordam → sinal forte
- Onde divergem → você arbitra com motivação

Resultado: PLANO.md inicial atualizado com scope-final + seção "Decisões consideradas no scope-council" referenciando docs/scope-council/.

Os 3 outputs intermediários ficam em docs/scope-council/ pra trilha de auditoria.

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
│   ├── scope-deepseek-review.md      ← Etapa 2 (DeepSeek)
│   └── scope-challenger.md           ← Etapa 3 (Sonnet adversário)
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

1. **Wrapper auto-trigger não tem prompt customizado de scope-review.** Por padrão revisa código (diff git). Pra revisar markdown de scope, use o caminho manual: rode `deepseek-review.ps1` direto e adapte system prompt — ou interprete output padrão como feedback sobre arquivos staged (que serão o scope-draft markdown).

2. **Sonnet subagent é stateless.** Cada dispatch é fresco; ele não vê resultados anteriores. Pra compor com Etapa 1 + 2, prompt da Etapa 3 precisa referenciar paths dos arquivos das etapas anteriores explicitamente.

3. **Council não substitui entrevista com cliente real.** É um cross-check de viés do agente, não validação de mercado. Se o projeto depende de entender mercado, faça research separadamente (não substitui).

4. **Trilha de auditoria opcional.** `docs/scope-council/` pode ser .gitignored se você não quiser comitar análises iniciais. Default: comitar (vira parte da história do projeto).

---

## Anti-padrões

- ❌ Pular Etapa 1 ("Claude já tem opinião desde o brainstorming"). Etapa 1 produz artefato escrito com motivações — vital pras outras etapas terem o que criticar
- ❌ Rodar Etapas 2 e 3 sem ler Etapa 1 primeiro — sem o draft, providers críticos não têm escopo definido pra criticar
- ❌ Aceitar todas as críticas sem julgamento — council é insumo, não comando. Você decide
- ❌ Marcar PLANO.md como "definitivo" sem fazer Etapa 4 — sem síntese humana, council vira teatro
- ❌ Repetir council a cada decisão pequena — é gate de início de projeto, não ferramenta de iteração

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
- R11 (review cross-provider obrigatório): `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`
- Wrapper auto-trigger: `scripts/percus-review-auto.ps1` (Windows) / `.sh` (Unix)
- Justificativa pra não adotar `llm_council_skill` externo: análise comparativa em sessão de 2026-05-04 — concluiu que padrão "council" só vale em decisões raras e custosas, e implementação enxuta interna cobre o caso sem dependências externas
