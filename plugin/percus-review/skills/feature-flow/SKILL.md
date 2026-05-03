---
name: feature-flow
description: Use when starting any feature or bugfix in a Percus project. Orchestrates R1->R13 workflow (brainstorming -> plan -> subagent-driven execution -> TDD -> /percus:review -> mark [5-T]). Replaces loading R1+R9+R11+R13 separately.
---

# Percus Feature Flow

Quando começar feature nova OU bugfix em projeto Percus, siga este fluxo.

## Quando NÃO usar
- Bug fix de 1 linha, rename trivial, typo → só faz e roda `/percus:review`
- Sessão de consulta (ler código, explicar) → não aplicável

## Fluxo (passos numerados)

### 1. Brainstorming se não-trivial (R9)
Invoque `superpowers:brainstorming` antes de codar quando feature tem qualquer ambiguidade.

### 2. Plano se 3+ arquivos (R9)
Invoque `superpowers:writing-plans`. Output: `docs/plans/<topic>.md` com tasks numeradas.

### 3. G-DELEGA pra cada task (R13)

| Característica da task | Para onde |
|---|---|
| Mecânica + plano explícito + ≤3 arquivos OU padrão repetido + fora de pasta sensível | DeepSeek (wrapper + trailer `Co-implemented-by: deepseek-v4`) |
| Decisão arquitetural / debug / pasta sensível (auth/payment/migrations) | Claude direto |
| 3+ tasks independentes | `superpowers:subagent-driven-development` OBRIGATÓRIO |

### 4. TDD pra endpoint novo (R9)
Invoque `superpowers:test-driven-development`. Vitest/pytest antes do código.

### 5. Pipeline R2: [0]→[1-S]→[2-E]→[3-H]→[4-C]→[5-T]
Avança SÓ com verificação. Não arredondar.

### 6. Review pre-commit (R11) — IMPORTANTE
**INVOQUE `/percus:review` ATIVAMENTE antes de commitar.** Não espere o hook bloquear — o hook é safety net, não fluxo.

Por quê: se commitar sem review, hook pre-commit bloqueia E você perde 5-10s de retrabalho. Rodar review proativamente é mais rápido E garante que findings são tratados antes do commit.

### 7. Marco
Invoque `percus:close-milestone` ao fechar fase/feature/épico (skill irmã).

### 8. Marcações visuais (R2)
- 🤖 = delegado pro DeepSeek (commit deve ter trailer `Co-implemented-by: deepseek-v4`)
- ✓ = milestone-review aprovado
- 🎨 = draft de design aprovado (R10)

## Gates inline (não esquece)

- **R1:** [5-T] só após ciclo CRUD completo (Criar→F5→Editar→F5→Deletar→F5)
- **R3:** mock = banner MODO DEMO + toast "salvo localmente"
- **R7:** auth Percus, nunca Supabase/NextAuth/localStorage pra JWT
- **R10:** tela nova = v0.dev/shadcn, nunca Claude artifacts em produção
- **R13:** trailer `Co-implemented-by: deepseek-v4` no commit se aplicar saída do wrapper

## Referência completa
`D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`

## Skills upstream que invoco
Ver `D:/Claud Automations/_Novo_Projeto/comandos/USANDO_SUPERPOWERS.md` (tabela Tier 1).
