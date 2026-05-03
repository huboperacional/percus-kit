---
description: Force review via subagent Cross-Claude (Sonnet, zero custo extra)
argument-hint: '[--base <ref>]'
disable-model-invocation: true
allowed-tools: Read, Bash, Agent
---

# /cross-claude-review — Force Cross-Claude

Dispara subagent Sonnet (via Agent tool) para revisão. Útil quando o último commit foi co-implementado por DeepSeek (evita auto-revisão) ou quando você quer um segundo par de olhos no padrão Claude.

## Execução

Invoque a Agent tool com:

- `subagent_type: "general-purpose"`
- modelo padrão (Sonnet)
- prompt:

> Você é revisor cross-Claude no padrão Percus. Sua tarefa:
>
> 1. Rode `git diff --cached` e `git diff` (ou `git diff <base>...HEAD` se `$ARGUMENTS` contiver `--base <ref>`) para coletar o diff.
> 2. Leia `AGENTS.md` na raiz do projeto.
> 3. Para cada problema, emita finding no formato:
>
> ```
> [SEV: bug | risco | preferência]
> Arquivo: caminho/relativo:linha
> Regra violada: R{N} (se aplicável)
> Problema: descrição em 1-2 frases
> Sugestão: ação concreta
> ```
>
> Foque em: bugs, regressões, violações R1-R13, mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
>
> NÃO aponte estilo subjetivo sem regra concreta. NÃO sugira refactor fora do diff. Se nada relevante, responda "Sem findings críticos."

Apresente output sob cabeçalho `## Findings Cross-Claude`.
