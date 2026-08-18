## Perna do conselho volta 429 ou vazio — declarei "N de 3" sem re-disparar {#perna-conselho-nao-e-perna-morta}

`tags: council, conselho, orchestrator, 429, too many requests, groq, llama, deepseek, vazio, empty, maxtokens, perna degradada, parcial, rate limit`

**Contexto:** o `council-orchestrator` devolve `respostas_degradadas` e você escreve "2 de 3 pernas
responderam" — que a regra do loop `conselho` exige. O problema não é a regra: é aceitar o
diagnóstico do orquestrador como se fosse veredito final.

**Causa raiz — DUAS causas diferentes, o mesmo erro de leitura:**

| perna | sintoma | causa REAL |
|---|---|---|
| DeepSeek | `status: empty`, `content: ""` | **teto de saída**: `deepseek-v4-pro` é modelo de RACIOCÍNIO e gasta os 8192 tokens pensando, sem sobrar resposta |
| groq-llama | HTTP **429** | **teto de tokens por MINUTO** — o orquestrador dispara as pernas em PARALELO e o burst estoura |

Nos dois casos o orquestrador **diagnostica e não deixa consertar**: `-MaxTokens` só existe no
wrapper do provider, e não há retry pro 429.

**Solução:** antes de contar as pernas, **re-dispare cada uma que falhou, direto pelo wrapper**:

```
providers\deepseek.ps1   -PromptFile <arquivo> -MaxTokens 32000
providers\groq-llama.ps1 -PromptFile <arquivo>
```

Medido (tiatendo, 13-14/08/2026): mesmo prompt, DeepSeek 8192 → vazio 2× e 32000 → resposta
completa **que discordou da outra perna e mudou uma decisão de desenho**. groq: 429 sete vezes em
3 dias, e o **mesmo prompt** que falhou respondeu em **3,8s** ao ser re-disparado (um ping de 71
tokens também passou na hora — exclui conta bloqueada/cota diária).

**Custo de não fazer:** publiquei "2 de 3" e tratei um CRITICAL como convergência de duas pernas.
A que faltava, re-disparada, devolveu o **MESMO finding em 1º lugar** — o achado era **3/3**, e eu
subestimei a evidência que sustentava a minha própria correção.

**Regra:** erro de transporte (429/timeout) e resposta cortada (vazio por teto) **não são opinião
ausente — são opinião que você não foi buscar.**

**Ref:** memória `feedback_perna_do_conselho_que_falha_nao_e_perna_morta_re_dispare`;
`loops/conselho.md` ("Nunca apresente conselho parcial como completo").
