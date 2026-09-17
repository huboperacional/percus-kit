## Reinvocar o conselho com `--cross-claude-file` roda DeepSeek e groq DE NOVO — há duas respostas de cada {#conselho-reinvocado-com-cross-claude-roda-os-outros-de-novo}

`tags: conselho, council, orchestrator, cross-claude, cross-claude-file, subagente, reinvocacao, deepseek, groq-llama, analyze, pre-mortem, veredito, log, R23`

**Sintoma:** sem `ANTHROPIC_API_KEY` (ou com `PERCUS_CROSS_CLAUDE=subagent`), a primeira chamada ao
`council-orchestrator` devolve DeepSeek e groq e deixa `cross_claude_pending: true`. O fluxo manda
disparar o subagente e reinvocar com `--cross-claude-file`. Quem reinvoca espera só anexar a terceira
voz — e o log final traz respostas **diferentes** de DeepSeek e groq das que já tinham sido lidas.

**Reprodução real** (Empresa Milionária, `analyze` da spec da Meta PJ, 2026-09-13): na 1ª chamada o
DeepSeek deu `AJUSTAR (2 high)` e o groq `AJUSTAR "(1 high)"` sem listar HIGH nenhum; na reinvocação,
o DeepSeek deu `AJUSTAR (5 high)` — incluindo "derivações não confirmadas pelo operador", que a 1ª não
trazia — e o groq trouxe um HIGH novo (paginação). Consolidar só a 1ª leitura teria perdido achado
procedente; consolidar só a 2ª teria apagado o que a 1ª viu.

**Por que acontece:** a reinvocação é uma chamada completa ao orchestrator; o arquivo do Cross-Claude
só dispensa o subagente, não os outros provedores. Modelos com raciocínio não são determinísticos na
mesma pergunta.

**Como tratar:**

1. Leia as **duas** respostas de cada provedor e trate a união como a rodada 1 — a regra de parada
   (teto de 2 rounds) conta rodadas de pergunta, não chamadas.
2. Registre na síntese que houve duas chamadas, com o veredito de cada uma lado a lado.
3. **Não reenvie a spec editada** na reinvocação: o orchestrator lê o prompt de novo, e editar entre
   as duas chamadas mistura veredito de textos diferentes.

**Junto disso, confira o stderr:** a perna do groq tem teto próprio (~5.000 tokens) e o orchestrator
trunca só ela, avisando uma linha (`prompt truncado de 6234 -> ~4933`). O veredito dela é sobre menos
texto que o das outras.

**Relacionados:** [[conselho-perna-vazia-teto-tokens]], [[conselho-trunca-o-prompt-antes-de-enviar]].
