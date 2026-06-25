# Spec — {Nome da Feature}

_Feature: {slug-kebab-case} · Criada: {YYYY-MM-DD} · Status: DRAFT | ANALYZED | APROVADA_

> **O QUÊ e o PORQUÊ — não o COMO.** Esta spec é **tech-agnóstica**: descreve comportamento e
> valor, nunca stack/lib/arquitetura. Decisão técnica vive no `docs/PLANO.md` (o "plano"), não aqui.
> Adaptado do spec-kit (github/spec-kit) ao canon Percus. Ref: `comandos/SETUP_PROJECT_SKILLS.md`
> e o mapeamento spec-kit↔Percus em `05_FEATURE_TRACKING.md`.
>
> **Fluxo:** escrever spec → `/clarify` (≤5 perguntas) → `/percus-review:spec-analyze` → vira `[0]` no PLANO.

---

## 1. Cenários de usuário (priorizados)

> Fatias de história **testáveis independentemente**. Cada cenário em Given-When-Then.
> Prioridade: **P1** = MVP (sem isto a feature não existe) · **P2** = importante · **P3** = nice-to-have.

- **US1 (P1) — {título curto}**
  - **Given** {estado inicial} **When** {ação do usuário} **Then** {resultado observável}.
- **US2 (P2) — {título}**
  - **Given** {...} **When** {...} **Then** {...}.

---

## 2. Requisitos funcionais (FR)

> Numerados, verificáveis. Status: `COMPLETO` (claro e fechado) ou `NEEDS-CLARIFICATION`.
> Cada FR deve ter um critério de aceitação que dá pra **testar** (não "deve ser rápido").

- **FR-001** — {O sistema DEVE ...}. _Status: COMPLETO_
- **FR-002** — {O sistema DEVE ...}. _Status: COMPLETO_
- **FR-003** — {...}. _Status: NEEDS-CLARIFICATION_ → ver §7.

---

## 3. Critérios de sucesso (SC)

> **Mensuráveis** — número, threshold, taxa, prazo. Sem métrica não é SC, é desejo.

- **SC-001** — {ex.: 95% dos usuários completam o fluxo em < 30s}.
- **SC-002** — {ex.: 0 erros de validação em entrada válida}.

---

## 4. Entidades-chave (se data-driven)

> Só o modelo de dados em nível conceitual (nome + campos + relação). **Sem DDL, sem tipo de banco.**

- **{Entidade}** — {campos conceituais}; relaciona-se com {outra} por {cardinalidade}.

---

## 5. Edge cases

> Enumere explicitamente. Cada um deve linkar a um FR (ou virar um FR novo).

- {Entrada vazia / duplicada / limite} → {comportamento esperado} (FR-00X).
- {Falha de dependência externa} → {fallback esperado} (FR-00X).

---

## 6. Assumptions & Constraints

- **Assumptions:** {premissas silenciosas tornadas explícitas}.
- **Constraints:** {limites de escopo — o que esta feature NÃO faz}.
- **Dependências:** {features/serviços de que esta depende}.

---

## 7. Clarifications

> **Máximo 3** `NEEDS-CLARIFICATION` abertos por spec. Mais que isso = spec imatura, volte ao brainstorming.
> O `/clarify` resolve estes (≤5 perguntas de alto impacto) e move a resposta pro FR/SC relevante.

- **[NEEDS-CLARIFICATION: {pergunta concreta}]** — afeta FR-003.

### Sessão de clarificação {YYYY-MM-DD}
- _(preenchido pelo `/clarify`: pergunta → resposta → onde foi aplicada)_

---

## 8. Resultado do spec-analyze

> Preenchido por `/percus-review:spec-analyze`. A feature só vira `[0]` no PLANO depois de
> ANALYZED sem findings CRITICAL pendentes (ou com eles resolvidos).

- _(cole aqui a tabela de findings + veredito do analyze, ou link pro log em `.deepseek/council-log/`)_
