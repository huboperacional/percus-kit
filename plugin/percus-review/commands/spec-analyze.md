---
description: Analyze de uma spec de feature pelo conselho (detecção estruturada estilo spec-kit /analyze) antes de virar [0]
argument-hint: '<caminho/da/spec.md> [--deep]'
disable-model-invocation: true
allowed-tools: Read, Bash, Agent
---

# /spec-analyze — Conselho valida a spec antes da implementação

Roda o conselho em **modo analyze** (detecção estruturada: cobertura FR/SC, ambiguidade, edge case,
violação de constituição R1-R23, vazamento WHAT→HOW) sobre a `spec.md` de uma feature. Preenche o gap
do meio: a feature só vira `[0]` no `PLANO.md` depois de passar aqui sem CRITICAL pendente.

> **Quando rodar:** após escrever a `spec.md` (template `templates/spec.template.md`) e passar o
> auto-checklist (`templates/spec-checklist.template.md`), e depois do `/clarify`. Só para feature
> **não-trivial** — feature trivial usa mini-spec e pula (ver `feature-flow`).

## Passo 1 — Decidir providers (custo proporcional)

- **Default = 2 providers** (`deepseek,groq-llama`) — ~$0.002, ~2-6s. Mesmo tiering do `council:consult`.
- **3 providers** (`deepseek,groq-llama,cross-claude`) **se**: a spec toca **pasta/domínio sensível**
  (auth, pagamento, identidade, migrations) **OU** o usuário passou `--deep`.

## Passo 2 — Rodar o orchestrator em modo analyze

Arquivo temp **único** por invocação (anti-stale, padrão v6.16.1 — **nunca** nome fixo). O conteúdo é o
**texto real da spec** (caminho em `$ARGUMENTS`).

- **Windows (PowerShell):**
  ```bash
  pwsh -NoProfile -ExecutionPolicy Bypass -Command "$Q = Join-Path $env:TEMP ('spec-analyze-' + [guid]::NewGuid().ToString('N') + '.txt'); Copy-Item -LiteralPath '<caminho/da/spec.md>' -Destination $Q; & '${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1' -PromptFile $Q -Mode analyze -Providers 'deepseek,groq-llama'; Remove-Item -LiteralPath $Q -Force -ErrorAction SilentlyContinue"
  ```
- **Unix (bash):**
  ```bash
  Q=$(mktemp); cat "<caminho/da/spec.md>" > "$Q"; bash "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.sh" --prompt-file "$Q" --mode analyze --providers "deepseek,groq-llama"; rm -f "$Q"
  ```

(Troque `deepseek,groq-llama` por `deepseek,groq-llama,cross-claude` no caso sensível/`--deep`.)

## Passo 3 — Cross-Claude (só no caso de 3 providers)

Se o stderr emitir `__PERCUS_NEEDS_CROSS_CLAUDE__`: dispatch subagent via Agent tool com o prompt
mostrado (modelo no `---MODEL-HINT---`), salve a resposta num temp **único**
(`spec-analyze-cc-<guid>.txt`) e re-invoque o orchestrator com `-CrossClaudeFile $CC`. Nunca reuse
nome fixo.

## Passo 4 — Fact-check dos CRITICAL (guardrail R20)

Antes de tratar qualquer finding **CRITICAL** como bloqueio, passe-os pelo pipeline F3 — o conselho
não pode ratificar alegação não-verificada (anti-padrão Plexco Tasks 2026-05-18):

```bash
# Windows
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/fact-check.ps1"
# Unix
bash "${CLAUDE_PLUGIN_ROOT}/scripts/fact-check.sh"
```

(Passe os findings CRITICAL via stdin. Findings que não confirmam viram HIGH "a verificar", não bloqueio.)

## Passo 5 — Sintetizar e reportar

Leia o último log em `.deepseek/council-log/<ts>-analyze.jsonl`. Cada provider retorna findings +
linha `VEREDITO:`. Agrupe por severidade e consolide:

```
[spec-analyze] {feature}
Providers: {2 ou 3} · log: .deepseek/council-log/<ts>-analyze.jsonl

CRITICAL (consenso / fact-checked):
- {ref} — {defeito} — {correção}

HIGH:
- {ref} — {defeito} — {correção}

MEDIUM/LOW: {contagem} (detalhe no log)

VEREDITO CONSOLIDADO: PRONTA | AJUSTAR (N high) | BLOQUEADA (N critical)
```

Regra de avanço (espelha o gate `[S]` do `feature-flow`):
- **BLOQUEADA** → corrija a spec, re-rode o analyze. Não vira `[0]`.
- **AJUSTAR** → corrija os HIGH ou registre por que ficam (decisão consciente), depois vira `[0]`.
- **PRONTA** → cole a tabela na **§8 da `spec.md`** e marque a feature `[0]` no `PLANO.md`.

## Notas

- `analyze` ≠ `review`: review olha **diff de código** (R11, pré-commit); analyze olha **spec** (pré-`[0]`).
- Custo/latência: 2 providers ~$0.002/~2-6s; +cross-claude ~$0.005/~30s.
- Ref: `06_CONSELHO_PERCUS.md` (modos do conselho), `05_FEATURE_TRACKING.md` (mapeamento spec-kit↔Percus),
  `templates/spec.template.md`, skill `percus-review:feature-flow` (gate `[S]`).
