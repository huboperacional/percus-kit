---
name: feature-flow
description: Use when starting any feature or bugfix in a Percus project. Orchestrates R1->R13 workflow (brainstorming -> plan -> subagent-driven execution -> TDD -> /percus-review:review -> mark [5-T]). Replaces loading R1+R9+R11+R13 separately.
---

# Percus Feature Flow

Quando começar feature nova OU bugfix em projeto Percus, siga este fluxo.

## Quando NÃO usar
- Bug fix de 1 linha, rename trivial, typo → só faz e roda `/percus-review:review`
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
**Auto-trigger via wrapper kit-level (v5.1.0+):** antes de cada `git commit` que você for executar via Bash tool, rode:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\Claud Automations\_Novo_Projeto\scripts\percus-review-auto.ps1"
```

(ou `.sh` em Unix). Wrapper resolve plugin instalado + decide router + dispatch DeepSeek. Se output stderr tiver marker `__PERCUS_NEEDS_CROSS_CLAUDE__`, dispatch Sonnet subagent IMEDIATAMENTE via Agent tool com prompt R11 cross-claude-review e salve findings em `.deepseek/reviews/<ts>-cross-claude.jsonl`.

Não pede pro usuário colar slash command — o agente faz tudo. Hook pre-commit (Layer 1+2) é safety net se você esquecer.

Para invocação humana (fora do agente), `/percus-review:review` no chat ainda funciona.

### 7. Marco
Invoque `percus-review:close-milestone` ao fechar fase/feature/épico (skill irmã).

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
