## Gate que escreve o marcador de liberação antes de olhar se a resposta serve (fail-open no R11) {#gate-marcador-antes-de-validar}

`tags: gate, fail-open, R11, deepseek-review, latest.jsonl, marcador, commit liberado, review vazia, truncated, hook, PreToolUse, silencio`

**Sintoma:** nenhum. É esse o problema. O commit passa, o review "rodou", e o arquivo que o hook checa está lá, fresquinho. Só que ele está vazio.

**Causa raiz:** o `deepseek-review.ps1` escrevia `.deepseek/reviews/latest.jsonl` — **o arquivo cuja existência libera o commit** — incondicionalmente, logo depois da chamada HTTP. Se o modelo devolvesse `content` vazio (gastou o teto raciocinando) ou cortado, o marcador era escrito do mesmo jeito, com `findings: ""`. O hook só verifica se existe marcador recente; ele não lê o conteúdo. Resultado: **commit aprovado com zero review, e nada dizendo.**

Duas agravantes que valem por si:
- **Resposta CORTADA passa em qualquer teste de "vazio".** Ela tem texto. O que falta é o fim — inclusive a conclusão, que é justamente onde mora o finding mais grave. Checar `-z "$FINDINGS"` não basta: tem que olhar `finish_reason == "length"`.
- **O lado bash e o PowerShell divergiam na direção contrária da usual.** O `.sh` já barrava resposta vazia desde sempre; o `.ps1` não barrava nada. Ao procurar paridade, não assuma que o runtime "principal" é o mais correto.

**Solução:** classifique a resposta **antes** de escrever o marcador e, quando não for `ok`, **não escreva o marcador** e saia com código não-zero. Sem marcador fresco, o gate segue fechado por construção — não é preciso um bloqueio novo, basta não mentir. Mensagem tem que dizer o que fazer: "rode de novo; se repetir, encolha o diff".

**A regra geral, que vale pra qualquer gate:** o artefato que libera não pode ser produzido no mesmo fôlego da tentativa. Fail-open num gate é pior que não ter gate — sem gate você sabe que não tem.

**Como caçar em outros lugares:** procure a escrita do artefato de liberação (marcador, flag, cache "verificado", `touch`) e olhe o que existe **entre** ela e a checagem de sucesso. Se não existe nada, é este bug.

**Ref:** percus-kit 6.36.4, 2026-08-16 (`scripts/deepseek-review.ps1` + `.sh`). Guarda: `provider-limites.tests.ps1`, Describe "R11 nao libera commit com review vazia ou cortada" — compara índice da classificação com índice da escrita do marcador. Relacionado: [#conselho-status-ok-content-vazio](conselho-status-ok-content-vazio.md).
