## Taxa de cache de 24% parecia defeito e era o TETO — extrapolei uma razão sem checar o máximo dela {#taxa-de-cache-tem-teto-estrutural}

`tags: prompt cache, cache hit rate, deepseek, prompt_cache_hit_tokens, custo, telemetria, metrica mal interpretada, teto estrutural, extrapolar taxa, otimizacao inexistente, review R11`

**Sintoma:** você olha uma métrica de eficiência — taxa de acerto de cache, cobertura de teste, hit ratio de qualquer coisa — vê um número baixo (24%), assume que o alvo é ~100%, e calcula uma economia enorme em cima da diferença. No caso real: *"levar o cache de 24% para 80% economiza $1,75 dos $4,06"*. O número da economia era inventado.

**Causa raiz:** o cache da DeepSeek (como o da Anthropic) é **por prefixo**. Só o pedaço estável do início da requisição pode ser reaproveitado; tudo depois do primeiro byte que muda é sempre miss. No prompt de review a estrutura é:

```
[system prompt: ~250 tokens]  [AGENTS.md: 1.100–3.200 tokens]  [git diff: 8.000+ tokens]
└──────────── estável, cacheável ────────────┘  └── diferente a cada chamada ──┘
```

**A taxa de acerto é, por construção, `prefixo / entrada total`.** Com prefixo de ~2.500 e entrada mediana de ~11.000, o teto é ~23%. Os 24% medidos não eram cache falhando: eram cache **acertando o prefixo inteiro, todas as vezes**.

**Como confirmar em 1 comando, e é o que eu deveria ter feito antes de propor:** compare os tokens que bateram no cache com o tamanho do prefixo estável, por projeto. Se a razão `hit / prefixo` for ~1,0, o cache está no máximo e não há nada a consertar.

| projeto | hit mediano | prefixo estimado | hit/prefixo |
|---|---|---|---|
| Paid Midia | 2.432 | 1.935 | 1,26 |
| Micro Investors | 3.456 | 2.729 | 1,27 |
| Empresa-Milionária | 4.352 | 3.460 | 1,26 |
| salas-flex | 1.280 | 1.350 | 0,95 |

🔑 **A lição não é sobre cache, é sobre razões: antes de calcular economia a partir de uma taxa, calcule o TETO daquela taxa.** Uma razão cujo denominador contém algo intrinsecamente não-otimizável (aqui, o diff — que *precisa* mudar) nunca chega a 100%, e a diferença até 100% não é oportunidade, é definição.

**Sinal de alerta que eu ignorei:** a proposta de conserto era vaga ("agrupar chamadas no tempo"). Otimização real aponta para uma linha de código; otimização que só existe na planilha aponta para "reestruturar o fluxo". Quando o conserto não tem endereço, desconfie do número que o justifica.

**Relacionado:** [#r11-diff-truncation-silent] (outra métrica de review que engana: resposta limpa em diff truncado) · [#achado-de-review-satura-com-o-tamanho-do-diff] (medição irmã, da mesma investigação de custo).

**Ref:** percus-kit, investigação de gasto DeepSeek de 2026-08-24. A proposta chegou a ser aprovada pelo operador ("ok, bora aplicar") antes de a medição derrubá-la — aprovação não valida premissa.
