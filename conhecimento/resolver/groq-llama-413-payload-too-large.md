## Groq/Llama devolve 413 (Payload Too Large) num diff grande que a DeepSeek aceita — reduzir `-MaxInputTokens` só daquela perna {#groq-llama-413-payload-too-large}

`tags: council-orchestrator, groq-llama, 413, payload too large, MaxInputTokens, truncar, api limit, llama-3.3-70b, deepseek aceita mesmo diff`

**Sintoma:** `council-orchestrator.ps1 -Providers "deepseek,groq-llama,cross-claude"` com um diff de
~14k tokens (`original_token_count`) devolve `"groq-llama: error"` com `"ATENCAO: 2 de 3 pernas
responderam"`. A perna DeepSeek, com o MESMO prompt, responde normal. Retentar a chamada idêntica
falha de novo (não é transitório).

**Causa raiz:** a API da Groq tem um limite de tamanho de payload **HTTP** menor que o da DeepSeek pro
mesmo texto — não é o `-MaxInputTokens` do script (esse só controla a truncagem **client-side** via
`Limit-Prompt`; setar um valor ALTO pra "não truncar" piora o problema, porque manda o payload inteiro
sem cortar). O erro exato aparece em `responses[].error`:
`"Response status code does not indicate success: 413 (Payload Too Large)"`.

**Solução:** re-rodar **só a perna `groq-llama`** (`-Providers "groq-llama"`) com
`-MaxInputTokens` **baixo** (ex. `5000`, abaixo do default de 8000) — isso ativa o `Limit-Prompt`
client-side (preserva ~1000 tokens do início + o resto do fim, avisa
`"prompt truncado de N -> ~5000 tokens"`) e o payload menor passa no limite da Groq. Não precisa
re-rodar DeepSeek/Cross-Claude, que já responderam ao prompt completo.

**Trade-off aceito:** a resposta da Llama nessas condições cobre só um RECORTE do diff (o meio é
cortado) — trate como perspectiva parcial, não substituto do que DeepSeek/Cross-Claude já viram
inteiro. Combina com [#conselho-perna-vazia-teto-tokens] (outra causa de perna degradada) — sintomas
parecidos (`status: error` ou `content` vazio), causas diferentes (413 de payload vs. teto de
`max_tokens`/`reasoning_tokens`).

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05.
