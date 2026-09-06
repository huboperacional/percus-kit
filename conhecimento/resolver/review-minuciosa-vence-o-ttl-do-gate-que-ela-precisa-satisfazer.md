## A review minuciosa vence o TTL do gate que ela precisa satisfazer {#review-minuciosa-vence-o-ttl-do-gate-que-ela-precisa-satisfazer}

`tags: review, gate, hook, ttl, r11, commit, percus, subagente, tempo`

### Contexto

O hook R11 (`pre-commit-check`) bloqueia `git commit` quando o último review tem **mais de 5
minutos**. Um subagente Cross-Claude que faz o trabalho direito — abre worktree, roda a suíte,
contra-prova por mutação, baixa a página ao vivo — leva **8 a 12 minutos**.

Sintoma: a review termina, você vai commitar, e o gate responde
`ultimo /percus-review:review tem 6.2 min (max 5)`. Repetir a review completa reinicia o mesmo
ciclo — ela vence de novo antes de você terminar de escrever a mensagem de commit.

Em 2026-09-05 isso custou três rodadas na mesma sessão.

### Causa raiz

O TTL foi dimensionado para uma review rápida. **A review boa custa mais tempo do que o gate
tolera** — não é um bug do hook nem da review, é um descasamento entre os dois. Quanto melhor a
review, mais garantido o bloqueio.

### Solução

1. **Prepare a mensagem de commit ANTES** de disparar a review minuciosa, para commitar no
   instante em que ela voltar.
2. **Quando vencer, NÃO repita a minuciosa.** Dispare uma review **estreita**, com escopo
   explicitamente limitado — "faça exatamente 3 checagens, não abra código de produção, não rode
   a suíte, responda em 10 linhas". Volta em ~30 s e satisfaz o gate. A minuciosa já cumpriu o
   papel dela; o que falta é carimbo de frescor, não análise.
3. Peça à review estreita que grave o `latest.jsonl` **mesmo sem findings** — é esse arquivo que
   a Layer 1 lê, e sem ele o commit segue barrado.
4. Não confunda com o **gate de tamanho**: `PERCUS_GATE_OVERSIZE` é outra coisa, e é específico —
   ele diz o arquivo e o número (`HANDOFF.md tem 152 linhas (teto 150)`). Ali o certo é corrigir,
   não declarar escape: escape reincidente vira achado de `loops/drift.md`.

### Armadilha

A review estreita **não substitui** a minuciosa. Se você pular direto pra ela, o commit passa com
carimbo e sem análise — que é exatamente o que o R11 existe pra impedir. A ordem importa:
minuciosa primeiro, estreita só como renovação de frescor.

**Ref:** hook `percus-review/hooks/pre-commit-check.ps1`; sessão tiatendo 2026-09-05.

**Relacionado:** [as duas camadas do hook R11 leem arquivos diferentes](escape-de-gate-deixa-o-repo-bloqueando-toda-sessao.md) ·
[achado de review satura com o tamanho do diff](achado-de-review-satura-com-o-tamanho-do-diff.md) ·
[cross-claude review queima 16000 e volta vazio](cross-claude-review-queima-16000-e-volta-vazio.md)
