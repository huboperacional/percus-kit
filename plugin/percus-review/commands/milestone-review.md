---
description: Review duplo (DeepSeek + Cross-Claude) para marco/PR — escopo <base>..HEAD
argument-hint: '[--base <ref>]'
disable-model-invocation: true
allowed-tools: Read, Bash, Agent
---

# /milestone-review — DeepSeek + Cross-Claude duplo

Para marcos importantes (PR, release, feature completa). Roda **ambos** os reviewers no escopo `<base>..HEAD` e apresenta findings consolidados.

## Passo 1 — Resolver base

- Se `$ARGUMENTS` contiver `--base <ref>`, use esse ref.
- Caso contrário, detecte branch padrão:
  ```bash
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
  ```
  Fallback na ordem: `main` → `master` → primeiro ref encontrado em `git branch -a`.

## Passo 2 — Rodar DeepSeek com escopo

- **Windows:**
  ```bash
  pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.ps1" -Base <base>
  ```
- **Unix:**
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.sh" --base <base>
  ```

Capture stdout (chamamos de `$DEEPSEEK_OUT`).

## Passo 3 — Rodar Cross-Claude com mesmo escopo

Dispare subagent Sonnet via Agent tool (`subagent_type: "general-purpose"`) com prompt:

> Revisão cross-Claude no padrão Percus para marco. Escopo: `git diff <base>...HEAD` (use `<base>` resolvido no passo 1).
>
> Leia `AGENTS.md`. Para cada problema, emita finding no formato:
>
> ```
> [SEV: bug | risco | preferência]
> Arquivo: caminho/relativo:linha
> Regra violada: R{N}
> Problema: ...
> Sugestão: ...
> ```
>
> Foque em bugs, regressões, violações R1-R13. Se nada relevante, responda "Sem findings críticos."

Capture output (chamamos de `$CROSS_CLAUDE_OUT`).

## Passo 4 — Apresentar consolidado

Saída final exata:

```
## Findings DeepSeek
{$DEEPSEEK_OUT (já vem com seu próprio cabeçalho — remova-o se duplicar)}

## Findings Cross-Claude
{$CROSS_CLAUDE_OUT}
```

## Notas

- Idealmente os dois rodam em paralelo (Bash + Agent na mesma resposta).
- Se DeepSeek falhar (sem `DEEPSEEK_API_KEY`), prossiga com Cross-Claude e avise no output.
