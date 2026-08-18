## Conselho volta 1/3: provider `agent-marker` sendo chamado por HTTP {#conselho-agent-marker-chamado-por-http}

`tags: conselho, council-consult, cross-claude, agent-marker, __PERCUS_NEEDS_CROSS_CLAUDE__, effort, claude-haiku, 400, groq-llama 404, registry, degradado`

**Contexto:** `/percus-review:council-consult` devolveu `respostas_usaveis: 1`. Um voto não é
conselho — e o risco é aceitar uma opinião única como se fosse consenso.

**Causa raiz — são DUAS, e só uma costuma ser conhecida:**
1. `groq-llama` → **404**, `llama-3.3-70b-versatile` foi descontinuado. Conserto: apontar o
   `providers/_registry.json` para um modelo vivo.
2. `cross-claude` → **400 `This model does not support the effort parameter`**, chamando
   `claude-haiku-4-5`. Mas o `_registry.json` declara esse provider como **`type: agent-marker`**, com
   `marker: __PERCUS_NEEDS_CROSS_CLAUDE__` e `wrapper_ps1: null` — ou seja ele **não deveria ser
   chamado por HTTP**: deveria emitir o marcador para o agente despachar um subagente. O orchestrator
   está com um caminho HTTP que contradiz o registry, e ainda manda `effort` a um modelo que o recusa.

**Como reconhecer rápido:** leia o `.deepseek/council-log/<ts>-consult.jsonl` e olhe
`respostas_degradadas` e `respostas_usaveis` **antes** de sintetizar. Se `respostas_usaveis` for 1,
não escreva "o conselho recomenda" — escreva "um provider recomenda".

**Contorno que funciona hoje, sem tocar no kit:** despachar o Cross-Claude **na mão** (subagente
`general-purpose`) com a mesma pergunta e o mesmo contrato de resposta (escolha / razão principal /
maior risco da alternativa). Numa decisão real isso levou o conselho de 1 para 2 vozes — e a segunda
**inverteu** o resultado: o primeiro provider vetava a opção por um risco que a segunda desarmou
trocando um parâmetro (`font-display: swap` → `optional`). Com uma voz só, a decisão teria saído
errada por um argumento que nem era sobre o mérito.

**Não remende o cache do plugin** (`.claude-home/plugins/cache/...`): some no próximo update. O
conserto é no repo do kit.

Ver também `#conselho-status-ok-content-vazio` e `#conselho-perna-vazia-teto-tokens`.
