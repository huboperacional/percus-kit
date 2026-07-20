# Formato: `docs/PLANO.md` — o quê e em que estado

**Dono de:** as features e o estado real de cada uma.

**Base:** `${env:PERCUS_CANON_DIR}/templates/PLANO.template.md` (V1). O V2 mantém a estrutura — ela funciona — e reforça as regras de honestidade abaixo.

## Estados (execução vertical)

| Tag | Significa |
|---|---|
| `[0]` | planejado (spec aprovada) |
| `[1-S]` | schema |
| `[2-E]` | endpoint |
| `[3-H]` | hook |
| `[4-C]` | componente |
| `[5-T]` | **ciclo testado** — ponta a ponta, verificado |
| `✓` | marco aprovado pelo revisor cross-provider |

Marcadores auxiliares: `🎨` draft de design aprovado · `🎨?` precisa de draft antes de `[1-S]` · `🤖` implementado via DeepSeek.

## As duas regras que sustentam o artefato

**1. Nunca arredonde para cima.** UI pronta sem ciclo testado é `[4-C]`, não `[5-T]`. O estado inflado é pior que estado atrasado: ele faz você deployar o que não funciona e some com o trabalho que falta.

**2. `[5-T]` exige verificação observada.** Não é "implementei e deve funcionar" — é "rodei o ciclo e vi". Evidência, não asserção (Constituição §3).

## Estrutura mínima

```markdown
# PLANO — {projeto}

## Frente {nome}
| Feature | Estado | Próxima ação |
|---|---|---|
| {nome} | `[2-E]` 🎨 | criar hook + componente |
| {nome} | `[5-T]` ✓ | — (marco aprovado) |
```

## Fronteira com os outros artefatos

- Feature **pronta** vive aqui, não no `HANDOFF` (lá só entra o que está em obra).
- **Por que** a feature é assim vive no ADR, não aqui.
- **Termo** usado no nome da feature vive no `CONTEXT.md`.

## Manutenção

Encerrou uma frente inteira? Ela sai para `docs/historico/`. O `PLANO` é mapa do que está vivo — plano que só cresce vira arqueologia.
