## Conselho volta 1/3: provider `agent-marker` sendo chamado por HTTP {#conselho-agent-marker-chamado-por-http}

> ✅ **RESOLVIDO em 6.42.0 (2026-08-19).** As duas causas cairam: a perna Groq foi para
> `openai/gpt-oss-120b` (6.41.0) e o `effort` virou condicional (6.42.0). Consulta real logo apos:
> `respostas_usaveis: 3`, `respostas_degradadas: 0`. O verbete fica pelo raciocinio -- e por uma
> correcao que importa mais que o conserto, no bloco final.

`tags: conselho, council-consult, cross-claude, agent-marker, __PERCUS_NEEDS_CROSS_CLAUDE__, effort, claude-haiku, 400, groq-llama 404, registry, degradado`

**Contexto:** `/percus-review:council-consult` devolveu `respostas_usaveis: 1`. Um voto não é
conselho — e o risco é aceitar uma opinião única como se fosse consenso.

**Causa raiz — são DUAS, e só uma costuma ser conhecida:**
1. `groq-llama` → **404**, `llama-3.3-70b-versatile` foi descontinuado. Conserto: apontar o
   `providers/_registry.json` para um modelo vivo.
2. `cross-claude` → **400 `This model does not support the effort parameter`**, chamando
   `claude-haiku-4-5`. Os wrappers montavam `output_config.effort` **incondicionalmente**, e o
   `ValidateSet` do parâmetro não tinha valor para desligar. O roteador manda Haiku 4.5 só no modo
   `consult` — por isso **só o consult quebrava**, e `review`/`pre-mortem` passavam.

   ⚠️ **A segunda metade desta linha estava ERRADA, e o erro veio de um arquivo, não de um palpite.**
   O verbete dizia que o provider "não deveria ser chamado por HTTP" porque o `_registry.json` o
   declarava `type: agent-marker` com `wrapper_ps1: null`. **O registry é que mentia.** Nenhum script
   lê esse arquivo: quem decide HTTP-vs-marcador é o `council-orchestrator` (Test-Path do wrapper +
   `ANTHROPIC_API_KEY`), e o caminho direto existe de propósito, porque é o único que habilita
   `cache_control`. 🔑 **Documentação com aparência de configuração induz diagnóstico errado com a
   mesma autoridade de um log** — e aqui induziu o meu. Corrigido em 6.42.0: o registry passou a
   `type: http-or-marker` com os wrappers reais, e `provider-registry-sync.tests.ps1` cobra a
   sincronia com o código. Antes de citar um arquivo de config como prova de comportamento,
   **confirme que alguém o lê**: `grep` pelo nome dele no runtime.

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

**Matriz medida (2026-08-19, `POST /v1/messages`, `max_tokens:16`) — o dado reutilizável:**

| modelo | sem `effort` | `effort=low` | `effort=xhigh` |
|---|---|---|---|
| `claude-haiku-4-5` | 200 | **400** `does not support the effort parameter` | — |
| `claude-sonnet-4-6` | 200 | 200 | **400** `Supported levels: high, low, max, medium` |
| `claude-sonnet-5` / `claude-opus-5` / `claude-opus-4-7` | 200 | 200 | 200 |

Confere com o catálogo da skill `claude-api`. A tabela virou dado em
`providers/_effort-capabilities.json`, lido pelo `.ps1` **e** pelo `.sh` — arquivo único, porque a
mesma regra em dois interpretadores foi como o `temperature` sobreviveu um mês
(`#regra-duplicada-ps1-sh`). **Refaça a medição ao acrescentar modelo; não deduza do nome** —
`claude-sonnet-4-6` aceita `effort` mas recusa `xhigh`, e nada no nome diz isso.

Ver também `#conselho-status-ok-content-vazio`, `#conselho-perna-vazia-teto-tokens`,
`#cross-claude-400-sampling` (a classe irmã, na direção oposta) e
`#direcao-da-enumeracao-por-qual-lado-falha-alto` (por que a tabela lista quem RECUSA).
