## Restaurar mutação com `git checkout --` apaga o trabalho não commitado junto {#restaurar-mutacao-com-trabalho-pendente}

tags: `mutation-testing`, `git-checkout`, `perda-de-trabalho`, `TDD`, `restore`

**Sintoma.** Você faz mutation-testing durante um ciclo TDD, roda `git checkout -- <arquivo>` para restaurar — e perde a implementação inteira que ainda não tinha commitado.

**Causa raiz.** A regra "restaure mutação com `git checkout --`, nunca com replace cego" pressupõe **arquivo limpo**: a mutação é o único delta contra o índice. Durante TDD o arquivo carrega também a task em andamento, e o checkout leva as duas.

**Solução.** Com trabalho pendente no arquivo, restaure por replace **com asserção de contagem**:

    alvo = "<trecho mutado exato>"
    assert t.count(alvo) == 1, f"ancora ambigua -- nao mutar as cegas"
    p.write_text(t.replace(alvo, "<original>"), encoding="utf-8")

e confirme com `git diff` que só a mutação sumiu. Alternativas: `git stash` antes de mutar, ou commitar a task e só então mutar (aí o `checkout --` volta a ser seguro).

**Ref:** Família Milionária, 2026-08-17, ciclo TDD da leitura de sessão pura.
