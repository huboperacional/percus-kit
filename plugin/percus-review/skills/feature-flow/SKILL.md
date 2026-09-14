---
name: feature-flow
description: Use when starting any feature or bugfix in a Percus project. Orchestrates R1->R13 workflow (brainstorming -> plan -> subagent-driven execution -> TDD -> /percus-review:review -> mark [5-T]). Replaces loading R1+R9+R11+R13 separately.
---

# Percus Feature Flow

Quando começar feature nova OU bugfix em projeto Percus, siga este fluxo.

## Passo 0 — declare o trilho (R9)

Na primeira resposta da feature, declare o trilho **P, M ou G** e a estimativa, pela tabela única de
`${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` (R9, "Trilho P / M / G"). Tudo abaixo vale **conforme o
trilho**. Sessão de consulta (ler código, explicar) não é feature e não declara trilho.

## Fluxo (passos numerados)

### 1. Brainstorming pelo caminho do trilho (R9)
`superpowers:brainstorming`: P → caminho **Spike**; M → **Bounded**; G → **Architectural**.

### 1.5 Decisões visuais antes do plano (R9, R10)
Tarefa visual M ou G: mockup ou tabela aprovados + lista de "decisões fechadas" (até 10 linhas) **antes** do
plano. Em P, itere na tela real.

### 2. Plano conforme o trilho (R9)
- **P:** lista de tarefas de até 1 página (no chat ou no PLANO).
- **M:** **plano de contrato** — por tarefa: arquivos, assinaturas, casos de teste (entrada → saída),
  critério de pronto, armadilhas. Código só onde há armadilha concreta. Até ~600 linhas.
- **G:** `superpowers:writing-plans` completo.

### 3. G-DELEGA pra cada task (R13)

| Característica da task | Para onde |
|---|---|
| Mecânica + plano explícito + ≤3 arquivos OU padrão repetido + fora de pasta sensível | DeepSeek (wrapper + trailer `Co-implemented-by: deepseek-v4`) |
| Decisão arquitetural / debug / pasta sensível (auth/payment/migrations) | Claude direto |
| Trilho M | `superpowers:subagent-driven-development` em **lotes de 2–4 tarefas** por implementador, uma revisão por lote |
| Trilho G | `superpowers:subagent-driven-development`, uma tarefa por implementador |

### 4. TDD pra endpoint novo (R9)
Invoque `superpowers:test-driven-development`. Vitest/pytest antes do código.

### 4.5 Gate [S] — spec + analyze ANTES de [0] (só trilho G)

Trilho **G** passa por um gate de spec antes de virar `[0]`:

1. Escreva a `spec.md` da feature do template `${env:PERCUS_CANON_DIR}/templates/spec.template.md`
   (WHAT/WHY tech-agnóstico — stack fica no PLANO, não na spec).
2. Auto-valide com `${env:PERCUS_CANON_DIR}/templates/spec-checklist.template.md`.
3. `/clarify` — resolva ambiguidades com **≤5 perguntas** de alto impacto via AskUserQuestion.
4. `/percus-review:spec-analyze <spec.md>` — conselho Modo 5 (detecção estruturada). Default 2
   providers; 3 se pasta sensível ou `--deep`. CRITICAL passa por fact-check F3.
5. **VEREDITO PRONTA** → cole na §8 da spec e marque a feature `[0]`. **BLOQUEADA** → corrija e re-rode.

Trilhos **P e M** **pulam o gate**: declare uma **mini-spec de 3 linhas** no `PLANO.md` (o quê / por quê /
critério de pronto) e siga direto pro `[0]`. No M, o operador pode pedir o analyze. O gate vale quando o
trilho pede, não vira cerimônia.

Ref: `06_CONSELHO_PERCUS.md` Modo 5 + mapeamento spec-kit↔Percus.

### 5. Pipeline R2: [0]→[1-S]→[2-E]→[3-H]→[4-C]→[5-T]
Avança SÓ com verificação. Não arredondar. (`[S]` do passo 4.5 precede `[0]` no trilho G.)

### 6. Review pre-commit (R11) — IMPORTANTE
**Auto-trigger via wrapper kit-level (v5.1.0+):** antes de cada `git commit` que você for executar via Bash tool, rode:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"
```

(ou `.sh` em Unix). Wrapper resolve plugin instalado + decide router + dispatch DeepSeek. Se output stderr tiver marker `__PERCUS_NEEDS_CROSS_CLAUDE__`, dispatch Sonnet subagent IMEDIATAMENTE via Agent tool com prompt R11 cross-claude-review e salve findings em `.deepseek/reviews/<ts>-cross-claude.jsonl`.

Não pede pro usuário colar slash command — o agente faz tudo. Hook pre-commit (Layer 1+2) é safety net se você esquecer.

Para invocação humana (fora do agente), `/percus-review:review` no chat ainda funciona.

### 7. Marco (conforme o trilho)
- **P:** não há marco; a feature fecha no `[5-T]`.
- **M:** a revisão final do branch (sonnet) fecha o marco.
- **G:** `percus-review:close-milestone` ao fechar fase/feature/épico (skill irmã), com `milestone-review` duplo.

### Verificação de feito (R1) no trilho
Mudança sem gravação de dado (layout, texto, filtro de exibição) usa a **forma visual** da R1: tela real
conferida pelo operador depois de F5 e trailer `UI-verified: YYYY-MM-DD HH:MM`. Qualquer caminho que grava
dado exige o ciclo CRUD abaixo.

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

### Ao marcar [5-T] (v6.12.0+): trailer + atualizar PLANO E HANDOFF juntos

Quando o operador confirma o ciclo CRUD e voce vai marcar `[5-T]`, faca as TRES coisas na MESMA operacao (elimina drift na origem):

1. **Atualize `docs/PLANO.md` E `HANDOFF.md` na mesma leva de edits** — a feature vira `[5-T]` nos dois. Nunca atualize so um (o hook on-stop `state-drift-check` bloqueia o encerramento se PLANO e HANDOFF divergirem).
2. **Inclua o trailer `CRUD-verified: YYYY-MM-DD HH:MM`** no commit que marca `[5-T]`. Use a data/hora reais da confirmacao. Exemplo:

   ```
   git commit -m "feat(x): finaliza feature Y" -m "CRUD-verified: 2026-05-30 14:32"
   ```

   (Em PowerShell, use o here-string single-quoted `@'...'@` se a mensagem tiver multiplas linhas.)
3. O hook pre-commit `crud-evidence-warn` **avisa** (nao bloqueia) se voce marcar `[5-T]` sem o trailer. Se o aviso aparecer e voce de fato rodou o ciclo, re-commite com o trailer. Se NAO rodou, reverta pra `[4-C]`.

**Hooks de enforcement desta release (so observabilidade — sem promocao automatica warn->block):**
- `crud-evidence-warn` (pre-commit, warn-only): avisa `[5-T]` adicionado sem trailer. Skip: `$env:PERCUS_SKIP_CRUD_WARN=1`.
- `state-drift-check` (on-stop, BLOQUEIA): impede encerrar sessao com PLANO ≠ HANDOFF no status de alguma feature. Skip: `$env:PERCUS_SKIP_DRIFT_CHECK=1` (declarar motivo).

## Outros gates inline (não esquece)

- **R3:** mock = banner MODO DEMO + toast "salvo localmente"
- **R7:** auth Percus, nunca Supabase/NextAuth/localStorage pra JWT
- **R10:** tela nova = v0.dev/shadcn, nunca Claude artifacts em produção
- **R13:** trailer `Co-implemented-by: deepseek-v4` no commit se aplicar saída do wrapper

## Referência completa
`${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`

## Skills upstream que invoco
Ver `${env:PERCUS_CANON_DIR}/comandos/USANDO_SUPERPOWERS.md` (tabela Tier 1).
