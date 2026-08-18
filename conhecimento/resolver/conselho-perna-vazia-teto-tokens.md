## Conselho devolve "3 providers ok" com uma perna vazia e outra cortada (teto de tokens × modelo de raciocínio) {#conselho-perna-vazia-teto-tokens}

`tags: conselho, council, orchestrator, deepseek, cross-claude, groq-llama, max_tokens, 1024, reasoning_tokens, resposta vazia, truncado, finish_reason, length, stop_reason, max_tokens, status ok, falso verde, pre-mortem, consenso falso`

**Origem:** percus-kit, 2026-07-31 — o pre-mortem do plano 2 devolveu "3 providers chamados" quando
só **um** havia respondido.

Duas falhas encaixadas, e é a segunda que transformou a primeira em silêncio.

**A primeira é o teto de tokens contra modelo de raciocínio.** Em modelos como `deepseek-v4-pro`, os
`reasoning_tokens` contam **dentro** de `completion_tokens`. Com `max_tokens = 1024`, uma pergunta
difícil faz o modelo gastar o teto inteiro pensando e devolver `content: ""`. Medido no mesmo dia,
lado a lado:

| Chamada | completion | reasoning | sobrou pra resposta |
|---|---|---|---|
| pergunta curta | 611 | 498 | 113 → respondeu |
| pre-mortem com plano inteiro | 1024 | 1024 | **0 → vazio** |

Do ponto de vista do HTTP, os dois deram **200**. Não há erro para capturar.

**A segunda é o provider chamar isso de sucesso.** O código gravava `status = "ok"` sempre que a
chamada não lançava exceção, sem nunca olhar o conteúdo. Na mesma rodada, o Cross-Claude bateu no
mesmo teto por outro caminho — devolveu texto **cortado no meio de uma frase** — e também foi
reportado como `ok`. Duas das três pernas degradadas, zero sinal.

- **A regra:** `HTTP 200` ≠ resposta. Classifique **três** estados, não dois: `ok`, `empty`
  (conteúdo vazio ou só espaço) e `truncated` (`finish_reason == "length"`, ou `stop_reason ==
  "max_tokens"` na API da Anthropic). Vazio e cortado nunca podem se chamar `ok`.
- **O aviso tem que nomear a causa**, não só o sintoma. "vazio" manda procurar erro de API;
  "gastou o teto raciocinando, suba `max_tokens`" manda consertar o que é.
- **O agregador tem que dizer a conta.** `providers_called` não é `providers que responderam` — se
  quem lê precisa derivar isso, alguém vai ler errado. Emita `respostas_usaveis: N de M` e liste as
  degradadas em stderr.
- **Como caçar:** procure `status\s*=\s*"ok"` em qualquer wrapper de API. Se estiver numa linha que
  não olha o conteúdo, é este bug. Depois confira `max_tokens` contra a natureza do modelo — teto
  que serve para modelo sem raciocínio é pequeno demais para modelo com.
- **Por que passa despercebido:** o consumidor recebe uma lista com o número certo de elementos.
  Contar elementos dá o resultado esperado; só ler o conteúdo revela que um deles está vazio.

**Relacionado:** [Fact-check marca REAL como INFUNDADO](fact-check-infundado-e-nao-verificado.md) — a
mesma confusão entre "não consegui" e "não tem", uma camada acima.
