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
pwsh -NoProfile -ExecutionPolicy Bypass -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"
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

## Gate R1 — ciclo CRUD obrigatorio antes de [5-T]

Ao tentar marcar uma feature como `[5-T]` (testado), **exija confirmacao explicita do operador das 3 acoes CRUD com F5**:

| # | Acao | F5 (refresh apos) | Verifica |
|---|---|---|---|
| 1 | Criar registro | ✓ | persistido no DB + UI |
| 2 | Editar registro | ✓ | mudanca refletida apos refresh |
| 3 | Deletar registro | ✓ | removido apos refresh |

Voce (agente) **NAO pode marcar `[5-T]` sozinho**. Antes de marcar, pergunte ao operador:

```
[R1 gate] Antes de marcar [5-T] na feature <X>, confirme as 3 acoes CRUD com F5:
  - [ ] Criei + F5 mostra persistido
  - [ ] Editei + F5 mostra mudanca
  - [ ] Deletei + F5 mostra removido
Posso marcar [5-T]? (sim/nao)
```

Se operador responde "sim sem ter testado", marque `[4-C]` em vez de `[5-T]` (codigo concluido + nao testado E2E) e registre no HANDOFF que testes E2E ficaram pendentes. **Nunca arredonde [4-C] -> [5-T] sem CRUD real.**

## Outros gates inline (não esquece)

- **R3:** mock = banner MODO DEMO + toast "salvo localmente"
- **R7:** auth Percus, nunca Supabase/NextAuth/localStorage pra JWT
- **R10:** tela nova = v0.dev/shadcn, nunca Claude artifacts em produção
- **R13:** trailer `Co-implemented-by: deepseek-v4` no commit se aplicar saída do wrapper

## Referência completa
`${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`

## Skills upstream que invoco
Ver `${env:PERCUS_CANON_DIR}/comandos/USANDO_SUPERPOWERS.md` (tabela Tier 1).
