---
description: Review do diff via router auto (DeepSeek default, escala pra duplo em pasta sensível)
argument-hint: '[--base <ref>]'
disable-model-invocation: true
allowed-tools: Read, Bash, Agent
---

# /review — Router auto cross-provider

Roda o router para decidir qual reviewer usar (DeepSeek API, subagent Cross-Claude, ou ambos), depois executa a decisão.

## Passo 1 — Rodar router

Detecte plataforma e rode o script apropriado, repassando os argumentos do usuário (`$ARGUMENTS`):

- **Windows (PowerShell):**
  ```bash
  pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/review-router.ps1" -Json $ARGUMENTS
  ```
  (fallback: `powershell.exe` se `pwsh` indisponível)

- **Unix (bash):**
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-router.sh" --json $ARGUMENTS
  ```

Parseie o JSON retornado: `{ "decision": "deepseek" | "cross-claude" | "dual", "sensitive": bool, "from_deepseek": bool, "files_count": N }`.

## Passo 2 — Executar decisão

### Se `decision == "deepseek"`
Rode o wrapper DeepSeek e retorne o stdout **verbatim**:
- Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.ps1" $ARGUMENTS`
- Unix: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.sh" $ARGUMENTS`

### Se `decision == "cross-claude"`
Dispare subagent Sonnet via Agent tool (`subagent_type: "general-purpose"`) com o prompt:

> Revise o diff atual contra AGENTS.md. Leia `git diff` (cached + working tree, ou `<base>...HEAD` se `--base` foi passado) e `AGENTS.md`. Reporta findings no formato:
>
> ```
> [SEV: bug | risco | preferência]
> Arquivo: path:linha
> Regra violada: R{N}
> Problema: ...
> Sugestão: ...
> ```
>
> Foque em bugs, regressões, violações R1-R13. Se nada relevante, responda "Sem findings críticos."

Apresente output do subagent sob cabeçalho `## Findings Cross-Claude`.

### Se `decision == "dual"`
Rode **ambos** em paralelo:
1. DeepSeek wrapper (como em `decision == "deepseek"`).
2. Subagent Sonnet (como em `decision == "cross-claude"`).

Apresente consolidado:
```
## Findings DeepSeek
{stdout do wrapper}

## Findings Cross-Claude
{output do subagent}
```

## Notas

- O router já detecta pasta sensível (auth/, payment*/, migrations/, credentials/, .env) e trailer `Co-implemented-by: deepseek` no último commit.
- `$ARGUMENTS` repassa `--base <ref>` se usuário forneceu.
- Se diff vazio, wrapper sai com mensagem amigável (exit 0).
