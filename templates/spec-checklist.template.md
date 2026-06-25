# Checklist de qualidade da spec — {Nome da Feature}

> Equivalente ao `requirements.md` do spec-kit. Roda **antes** do `/percus-review:spec-analyze` como
> auto-validação rápida (o que dá pra checar no olho) — o analyze faz a detecção semântica/cross-artifact.
> Marque cada item. Se algum falhar, conserte a spec antes de avançar pro analyze.

## Completude

- [ ] Todo **FR** tem critério de aceitação **testável** (não "deve ser rápido/robusto/amigável").
- [ ] Todo **SC** é **mensurável** (número, threshold, taxa, prazo) — não desejo vago.
- [ ] Todo cenário de usuário está em **Given-When-Then** e tem prioridade (P1/P2/P3).
- [ ] Existe ao menos **1 cenário P1** (sem ele a feature não tem MVP).
- [ ] **Edge cases** enumerados e cada um linka a um FR.

## Clareza

- [ ] **≤ 3** `NEEDS-CLARIFICATION` abertos (mais que isso = volte ao brainstorming).
- [ ] Nenhum FR depende de termo ambíguo não definido (ex.: "vários", "rápido", "seguro" sem número/definição).
- [ ] **Terminologia consistente** — o mesmo conceito tem o mesmo nome em toda a spec.

## Fronteira WHAT/HOW (regra herdada do spec-kit)

- [ ] A spec **não** menciona stack/lib/framework/tabela/endpoint específico (isso é do `PLANO.md`).
- [ ] **Constraints** declaram explicitamente o que a feature **NÃO** faz.
- [ ] **Dependências** de outras features/serviços estão listadas.

## Conformidade com a constituição

- [ ] Nada na spec viola `01_REGRAS_INEGOCIAVEIS.md` (ex.: auth próprio, mock em produção, JWT em localStorage).
- [ ] Nada contradiz `02_INFRA_E_STACK_PERCUS.md` (stack/infra canônica).
- [ ] Se a feature toca auth/pagamento/identidade → marcada como **pasta sensível** (analyze usa 3 providers).

---

**Resultado:** todos os itens marcados → seguir pro `/percus-review:spec-analyze`.
Algum desmarcado → corrigir a `spec.md` primeiro.
