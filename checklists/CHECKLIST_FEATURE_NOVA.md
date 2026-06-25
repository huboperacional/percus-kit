---
tipo: checklist-imperativo
quando-usar: ao iniciar implementação de qualquer feature nova (não bug fix isolado)
leitura: 2 min
ultima-atualizacao: 2026-06-25
---

# CHECKLIST — Feature Nova

> **Execute na ordem.** Cada passo tem gate verificável. Se pular, declare em voz alta o porquê.

---

## Pré-flight (~30 segundos)

### G0. Trigger lexical de design?

Se o pedido contém: `landing page`, `home`, `redesign`, `dashboard`, `painel`, `hero section`, `fluxo de cadastro/onboarding/checkout`, `pitch deck`, `melhorar UI/UX`, `mais bonito`, `modernizar visual`, ou envolve **mais de 1 tela nova**:

→ **PARE.** Aplique `01_REGRAS_INEGOCIAVEIS.md` R10 + `comandos/DESIGN_WORKFLOW.md`. Não continue até draft visual aprovado (via shadcn MCP, v0.dev, ou Excalidraw conforme o tipo).

---

## Fluxo principal (na ordem)

### 1. Brainstorming — `superpowers:brainstorming`

5-10 min antes de qualquer código. Explora 2-3 abordagens com tradeoffs. Usuário escolhe.

**Exceção declarável:** "Pulando brainstorming porque é trivial — só {X}". Se a feature toca >2 arquivos, brainstorming não é trivial.

### 2. Exploração — `Explore` (subagent)

Se vai mexer em código que você não escreveu nesta sessão, lance `Explore` antes. Não faça grep manual em loop.

### 3. Plano — `superpowers:writing-plans`

Obrigatório se a feature:
- Toca 3+ arquivos
- Cria schema novo
- Tem 3+ subtarefas independentes

Plano escrito ≠ plano mental. Reduz drift no meio da execução.

### 3.5 Gate [S] — spec + analyze antes do `[0]` (feature não-trivial, v6.19.0)

Feature **não-trivial** (toca schema + endpoint + UI, ou pasta sensível) passa por spec antes de virar `[0]`:

1. Escreva `spec.md` do template `${env:PERCUS_CANON_DIR}/templates/spec.template.md` (WHAT/WHY, tech-agnóstico).
2. Auto-valide com `templates/spec-checklist.template.md`.
3. `/clarify` — ≤5 perguntas de alto impacto via AskUserQuestion.
4. `/percus-review:spec-analyze <spec.md>` (conselho Modo 5; 2 providers default, 3 se sensível/`--deep`).
5. **VEREDITO PRONTA** → cole na §8 da spec, segue pro passo 4. **BLOQUEADA** → corrige e re-roda.

**Feature trivial** pula este gate: declare mini-spec de 3 linhas no PLANO (o quê / por quê / critério de pronto).

### 4. Adicionar ao `docs/PLANO.md`

Adicione a feature na frente correta, status `[0]` (precedido por `[S]` se passou pelo gate 3.5). Marcação visual:
- `🎨` se tem mockup aprovado
- `🎨?` se feature visual sem mockup ainda (não pode sair de `[0]` — bloqueio R10)
- (sem ícone) se backend-only

---

## G-DELEGA. Essa task é elegível para DeepSeek? (R13)

**Antes de começar a executar**, aplique a checklist em `04_MODEL_ROUTING.md` seção "Quando o Claude DEVE delegar":

- ✅ Plano markdown escrito + arquivos-alvo nomeados
- ✅ Sem decisão arquitetural pendente
- ✅ Não toca pasta sensível (`auth/`, `payment*/`, `migrations/`, `credentials/`, `.env*`)
- ✅ Cabe em ≤3 arquivos OU é padrão repetido em N arquivos

**Se TODOS forem ✅:** delegação é regra, não exceção. Siga o playbook "Como delegar" em `04_MODEL_ROUTING.md` (6 passos, sempre dry-run primeiro).

**Se algum critério falhou:** implementação fica com o Claude. Declare em voz alta o motivo:
> "Mantendo implementação local porque {decisão arquitetural | pasta sensível | escopo > 3 arquivos sem padrão | task ambígua}."

**Após delegação (se aplicável):** retornar pra este checklist no passo de execução com o output já aplicado, e seguir normalmente até G1 + G-MARCO.

---

## Execução por etapa — atualize PLANO imediatamente após cada uma

### `[0]` → `[1-S]` Schema
1. Escreva migration Alembic
2. Rode `alembic upgrade head`
3. Verifique tabela existe: `psql -c "\d nova_tabela"`
4. **Atualize PLANO** → `[1-S]`

### `[1-S]` → `[2-E]` Endpoint
1. **TDD obrigatório** — `superpowers:test-driven-development`. Vitest/pytest pequeno ANTES do código.
2. Escreva endpoint + service
3. Verifique: `curl -X POST http://localhost:8000/seu/endpoint -d '...'` → 2xx
4. **Atualize PLANO** → `[2-E]`

### `[2-E]` → `[3-H]` Hook
1. Crie hook/service no frontend
2. Verifique: chame na console do browser ou abra a tela; network tab mostra request 2xx
3. **Atualize PLANO** → `[3-H]`

### `[3-H]` → `[4-C]` Componente
1. Renderize dado real do banco na tela
2. Verifique olhando a tela — sem mock-data, sem array hardcoded
3. **Atualize PLANO** → `[4-C]`

### `[4-C]` → `[5-T]` Ciclo CRUD testado
1. Execute manualmente:
   ```
   Criar X → F5 → confere
   Editar X → F5 → confere
   Deletar X → F5 → confere
   ```
2. Se Playwright MCP está configurado, automatize esse ciclo aqui.
3. **Só agora** atualize PLANO → `[5-T]`

---

## Gate de marco — antes de declarar feature pronta OU avançar de fase

### G-MARCO. Review cross-provider do escopo do marco (R11, OBRIGATÓRIO)

Antes de declarar a feature em `[5-T]` **ou** antes de seguir pra próxima fase numerada de um plano em execução, rodar:

```
/percus-review:milestone-review --base <commit-de-inicio-do-marco>
```

Cobre o **conjunto** de mudanças do marco (DeepSeek + Cross-Claude duplo) — não só o último diff.

- Identifique o range do marco (ex.: `git diff <commit-inicio-fase>..HEAD`)
- Trate findings de bug ou regressão antes de marcar marco concluído
- Findings de "preferência de estilo" podem ser ignorados, mas declare em voz alta
- Sem milestone-review rodado = marco não está concluído (mesmo que `[5-T]` em si esteja)

**Após review aprovar o marco:** adicionar marcação **`✓`** nas features afetadas pelo marco em `docs/PLANO.md` e `HANDOFF.md` (R2 marcações visuais). Diferencia "feature em [5-T] mas marco ainda não auditado" de "feature em [5-T] com marco aprovado pelo revisor cross-provider".

Exemplo de antes/depois:
```
- [5-T] {Feature X} — testada
  ↓ após /percus-review:milestone-review aprovado
- [5-T] ✓ {Feature X} — testada, marco aprovado
```

Esse gate é **adicional** ao `/percus-review:review` antes do commit (G1) — propósitos diferentes: G1 protege o commit individual (pode disparar DeepSeek apenas); G-MARCO protege a transição de etapa com defesa em profundidade (sempre duplo).

---

## Paralelização

Se backend e frontend são independentes (não compartilham state mid-flight), use `superpowers:dispatching-parallel-agents`:
- Agente A: backend (`[1-S]` + `[2-E]`)
- Agente B: frontend prep (`[3-H]` skeleton com mock que vai ser trocado)

Você orquestra + decide.

---

## Antes de commit

### G1. Review cross-provider — `/percus-review:review` (R11, OBRIGATÓRIO)

Rodar `/percus-review:review` no chat (router decide reviewer auto: DeepSeek default, Cross-Claude se commit veio do wrapper DeepSeek com trailer `Co-implemented-by: deepseek-v4`, duplo se toca pasta sensível).

Override manual: `/percus-review:deepseek-review`, `/percus-review:cross-claude-review` quando quiser forçar canal específico.

- **Bug ou regressão:** corrigir antes de commitar
- **Violação de regra Percus:** corrigir OU declarar em voz alta por que ignora
- **Preferência de estilo:** ignorar é OK, mas declare em voz alta

Sem review rodado nos últimos 5 minutos = não pode commitar.

Primeira vez no projeto sem plugin `@percus/review` configurado? → rodar `comandos/SETUP_REVIEW_ROUTING.md` antes.

### G1b. Code review extra (opcional) — `superpowers:requesting-code-review`

Se diff > 500 linhas ou mexeu em auth/permissões/segurança, vale rodar code-review do Claude Code também (em paralelo ao Codex). Cobertura redundante para mudanças sensíveis.

### G2. Verification — `superpowers:verification-before-completion`

Pergunte a si mesmo: "se eu fechar tudo agora e o usuário abrir essa tela amanhã, ela funciona end-to-end?"

Se a resposta tem qualquer "talvez" ou "depende", **não está em `[5-T]`**.

### G3. Atualize HANDOFF e mock-audit (se frontend)

Antes do `git commit`, atualize:
- `HANDOFF.md` → tabela de status reflete novo estado
- `docs/mock-audit.md` → se a feature converteu mock em real, mover linha de ⚠️/❌ para ✅

---

## Quando NÃO seguir esse checklist completo

- **Bug fix em código existente** que não muda comportamento de feature: pode pular brainstorming/plano. Ainda precisa TDD se mexer em endpoint, e ainda precisa atualizar HANDOFF.
- **Refactor sem mudança funcional**: pode pular tracking `[0]→[5-T]`. Ainda precisa code-review.
- **Hot fix em produção**: protocolo separado — corrige primeiro, documenta depois, mas declare em voz alta o que está sendo pulado.

---

## Anti-padrões clássicos

- ❌ "Já sei o que fazer, vou direto pro endpoint" → pulou brainstorming, vai retrabalhar.
- ❌ "Componente tá funcionando, marco [5-T]" → não rodou ciclo CRUD com F5.
- ❌ "Deixo pra atualizar PLANO no fim" → no fim você esquece, fica defasado.
- ❌ "TDD pra esse endpoint pequeno é overkill" → endpoint pequeno hoje vira regressão amanhã.
- ❌ "Code review em commit pequeno é overkill" → pequeno não é o critério; sensibilidade é.
- ❌ "Vou commitar e rodar `/percus-review:review` depois" → derrota o propósito. Antes do commit, sempre.
- ❌ "Termino a fase inteira e rodo review só no fim do épico" → marco intermediário tem gate próprio (G-MARCO). Erros se acumulam.
