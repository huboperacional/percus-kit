---
# Template — Recipe de projeto (workflow composto)
# Copiar para: skills/recipes/recipe-{workflow}/RECIPE.md
# Baseado em: github.com/lucianfialho/gmp-cli (skills/recipe-* pattern)
# Ref completo: _Novo_Projeto/comandos/SETUP_PROJECT_SKILLS.md

name: recipe-{workflow}     # kebab-case; prefix "recipe-" obrigatório
version: 1.0.0
description: "Workflow composto: {o que encadeia} → {resultado final}"
project: {project-slug}
composes:
  - skills/{skill1}/SKILL.md
  - skills/{skill2}/SKILL.md
  - percus-review:{canon-skill}    # skill do plugin percus-review usada neste recipe
---

# Recipe: {Nome do Workflow}

Encadeia **{skill A}** → **{skill B}** → **{resultado}**.
Use quando {condição gatilho}: elimina a decisão manual de "o que fazer se X falhar
na etapa Y" e garante que as dependências entre etapas sejam respeitadas.

## Quando usar / não usar

| Cenário | |
|---|---|
| {Caso completo A — todas as etapas fazem sentido} | ✅ use esta recipe |
| {Caso B — só parte do workflow é necessária} | ❌ use `skills/{X}/SKILL.md` diretamente |
| {Caso C — etapa crítica tem bloqueador externo} | ❌ resolva bloqueador antes de rodar recipe |

## Pré-requisitos

- Working tree limpa (todas as mudanças pendentes commitadas).
- {Env var necessária, ex: `PERCUS_PORT_BASE` setado}
- {Dep ou serviço externo necessário}

---

## Sequência de execução

### Etapa 1 — {Nome} (`{skill ou ferramenta}`)

**Por quê primeiro:** {justificativa de ordem — o que esta etapa desbloqueia para as próximas}

{instrução ao agente — o que fazer, qual skill invocar, qual comando rodar}

**Critério de avanço:** {o que precisa estar OK (verde, sem erro, artefato criado) para ir pra etapa 2}
**Se falhar:** {ação de abort — ex: "reverter via `git checkout -- .`; não avançar"}

---

### Etapa 2 — {Nome} (`{skill}`)

**Por quê depois de 1:** {dependência explícita}

{instrução ao agente}

**Critério de avanço:** {ok condition}
**Se falhar:** {abort action}

---

### Etapa 3 — {Nome} (`{skill ou verificação}`)

{instrução}

**Critério de avanço:** {ok condition}

---

### Verificação final

- [ ] {Check 1 — evidência concreta de sucesso end-to-end}
- [ ] {Check 2}
- [ ] {Check 3}

**Saída esperada:** {artefato ou estado final do sistema após recipe completo}

---

## Abort protocol

Se qualquer etapa não passar no Critério de avanço:

1. **Parar imediatamente** — não avançar com estado parcial.
2. {Rollback específico, se necessário — ex: "reverter migration via `alembic downgrade -1`"}
3. Reportar ao operador:
   ```
   [recipe-{workflow}] ABORT na etapa N ({nome}) — {motivo}.
   Estado: {o que já foi feito e o que não foi}.
   Ação necessária: {o que o operador deve fazer antes de re-tentar}.
   ```

## Custo e duração estimados

| Métrica | Estimativa |
|---|---|
| Tempo de execução | {ex: ~15 min} |
| Tokens / custo | {ex: ~$0.005 (3 providers)} |
| Commits gerados | {N} |

## Referências

- Skills usadas: `skills/{skill1}/SKILL.md`, `skills/{skill2}/SKILL.md`
- Plugin canon: `${env:PERCUS_CANON_DIR}/plugin/percus-review/skills/{canon-skill}/SKILL.md`
- Guia geral: `${env:PERCUS_CANON_DIR}/comandos/SETUP_PROJECT_SKILLS.md`
