---
description: Force review via DeepSeek API (cross-provider real, sem router)
argument-hint: '[--base <ref>]'
disable-model-invocation: true
allowed-tools: Read, Bash
---

# /deepseek-review — Force DeepSeek

Roda o wrapper DeepSeek diretamente, sem passar pelo router. Útil quando você quer cross-provider real garantido (ex: validar regressão antes de merge).

## Execução

Detecte plataforma e rode:

- **Windows (PowerShell):**
  ```bash
  pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.ps1" $ARGUMENTS
  ```
  (fallback: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`)

- **Unix (bash):**
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/deepseek-review.sh" $ARGUMENTS
  ```

Retorne o stdout **verbatim** (já vem formatado com cabeçalho `## Findings DeepSeek`).

## Requisitos

- `DEEPSEEK_API_KEY` no ambiente ou em `.env` do projeto.
- `git` disponível.

## Notas

- Logs vão para `.deepseek/reviews/<timestamp>.jsonl`.
- Se diff vazio, sai com mensagem amigável.
- Argumentos suportados: `-Base <ref>` (PS) / `--base <ref>` (bash).
