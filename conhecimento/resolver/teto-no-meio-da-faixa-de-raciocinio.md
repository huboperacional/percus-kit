## Teto de tokens que cai NO MEIO da faixa de raciocínio: a mesma pergunta volta ok, cortada ou vazia na sorte {#teto-no-meio-da-faixa-de-raciocinio}

`tags: max_tokens, reasoning_tokens, modelo de raciocinio, deepseek-v4-flash, thinking, resposta vazia, truncated, finish_reason length, intermitente, flaky, variancia, system prompt, conselho, council`

**Sintoma:** uma perna de conselho (ou qualquer chamada a modelo que raciocina) volta vazia **às vezes**. Você reroda e funciona. Reroda de novo e volta cortada. Não há erro de API — todos os HTTP são 200. O aviso diz "gastou o teto raciocinando, suba `max_tokens`", você sobe um pouco, parece resolver, e três dias depois volta.

**Causa raiz — e é aqui que quase todo mundo erra o diagnóstico:** o teto não estava "pequeno demais". Ele estava **dentro da faixa de variação** do raciocínio daquele modelo para aquele tipo de prompt. Medido em 2026-08-16, `deepseek-v4-flash`, **o mesmo prompt**, três chamadas, teto 8192:

| chamada | reasoning_tokens | finish_reason | resultado |
|---|---|---|---|
| 1 | 8192 (bateu no teto) | length | **vazia** |
| 2 | 7649 | length | **cortada** no meio |
| 3 | 6784 | stop | ok, com 673 tokens de folga |

Três resultados diferentes, zero mudança de entrada. Um teto que fica na faixa de 6800–8200 produz os **três** estados na sorte. Por isso o bug parece intermitente e por isso "subir um pouco" não resolve: move a moeda, não tira a moeda.

**O multiplicador que ninguém olha: o system prompt.** O MESMO prompt de usuário, trocando só o system prompt do provider (genérico) pelo do modo `review`, **dobrou** o raciocínio — de ~3100 para 6784–8192+. Um system prompt que pede postura analítica (revisar, criticar, achar defeito) faz o modelo pensar muito mais. Ao medir teto, meça com o system prompt **de produção**, não com o default do wrapper.

**Solução:**
1. **Dimensione o teto pela faixa medida, não pelo pior caso que você viu uma vez.** Meça 3+ chamadas com o system prompt real e deixe folga de pelo menos 2×. 8192 → 16000 aqui.
2. **Não encolha o teto para economizar.** Em modelo que raciocina o teto cobre pensamento **+** resposta; cortar faz o modelo gastar tudo pensando e devolver vazio — você paga a chamada inteira e recebe nada. Encolha o **prompt**, não o teto.
3. **Suba o timeout junto.** São acoplados: chamadas que RESPONDERAM levaram 67s e 80s já no teto antigo. Subir teto sem subir timeout só troca "resposta vazia" por "erro de rede" — o defeito muda de nome e continua igualmente invisível.
4. **Classifique três estados** (`ok`/`empty`/`truncated`), nunca dois — ver [#conselho-perna-vazia-teto-tokens](conselho-perna-vazia-teto-tokens.md).

**Como suspeitar rápido:** se `reasoning_tokens ≈ max_tokens`, é este bug. Se `reasoning_tokens` fica entre 70% e 100% do teto **em chamadas que funcionaram**, é este bug esperando acontecer.

**Ref:** percus-kit 6.36.4, 2026-08-16. Origem: a 6.36.2 trocou `deepseek-v4-pro` → `-flash` por custo e não reavaliou o teto ao lado. Guarda: `provider-limites.tests.ps1` (teto mínimo por provider que raciocina + timeout comportando o teto).
