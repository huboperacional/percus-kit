## Script de mutação é RÉGUA — e régua sem aferição própria mede errado em silêncio {#script-de-mutacao-e-regua-afira-a-regua}

`tags: mutacao, runner, regua, exit code, parser, pytest, falso verde, falso vermelho, baseline, R1, R2`

**Sintoma:** o script de mutação imprime um placar convincente (`14/14 mortas`, árvore restaurada
byte-a-byte) e você usa isso como evidência. Só que o **instrumento** está errado, e o erro dele se
disfarça de resultado do produto. Dois modos, e os dois já ocorreram no mesmo script:

**1. Falso VERDE — baseline inválido aceito.** O gate era `if "passed" in saida`. Com o diretório
temporário indisponível, o baseline saiu `59 passed, 8 errors` — e o script **não abortou**: começou
a classificar mutantes contra um baseline quebrado. Pior, a regra de morte era `"failed" in linha`,
então **falha de ambiente/coleta virava "prova de mutação"**.

**2. Falso VERMELHO — comparação que inclui o tempo.** O pós-restauração exigia
`linha == baseline`, e a linha do pytest carrega a duração (`67 passed in 6.37s` ×
`67 passed in 6.25s`). Uma restauração perfeita fazia o processo sair **1**.

🪤 **O que torna o modo 2 traiçoeiro: ninguém olha o exit code.** O script foi rodado **quatro
vezes**, todas com `14/14 mortas` impresso, e saiu com código 1 em todas — e passou despercebido,
porque o placar no terminal convence. O exit code é justamente o que um CI leria.

🔑 **A regra:** medir por **substring** e por **linha com tempo** é a mesma classe de erro que a
mutação existe para pegar. O resultado tem que ser **estruturado**.

**Como resolver:**
1. **Parse, não substring.** Extraia contagens (`passed`/`failed`/`errors`/`skipped`) da linha de
   resumo — cuidado com `error` **singular** e plural. Procure no **stdout** (onde o terminal
   reporter escreve), não no `stdout+stderr` concatenado: um plugin escrevendo depois do resumo faz
   o scan reverso pegar a linha errada.
2. **Baseline/pós-restauração válidos** só com `rc==0`, **≥1 teste executado** e **zero**
   `failed`/`errors`. `passed + errors` **não é verde**.
3. **MORTA exige falha de ASSERÇÃO:** `rc==1` **e** `failed>=1` **e** `errors==0`. Erro de
   setup/coleta/uso/interrupção vira `INVÁLIDO`, que **não pontua**. Verde com contagem de `passed`
   diferente do baseline também é inválido (a suíte mudou de tamanho).
4. **Compare contagens normalizadas**, nunca a linha.
5. **Formato desconhecido → fail-closed** (resumo vazio reprova o baseline).
6. **Dê teste ao runner.** Funções puras (`parseResumo`/`baselineValido`/`classificarMutante`/
   `mesmoResultado`) + saídas **sintéticas**: verde · `passed + errors` · falha de asserção ·
   `no tests ran` · verde com **duração diferente**. Mais um teste de **comportamento** provando que
   o `main()` **aborta sem iniciar mutante** — e cuidado: se o `main` restaura no `finally`,
   comparar bytes ali é **vácuo**; quem prova o abort é o **contador de execuções da suíte**.

**Comando (o mínimo que fecha o modo 2):**
```bash
python scripts/mutacao<Frente>.py; echo "EXIT CODE = $?"
```
Placar impresso não é o contrato — o **exit code** é.

**Não faça:** confiar no placar sem olhar o retorno; nem tratar `errors` como ruído — em runner de
mutação, `errors` é o que separa "o teste pegou a mudança" de "o ambiente caiu".

**Ref:** tiatendo, 2026-09-05 — runner do `§00w-onboarding`. Defeito reportado por revisor
independente (`grupo-de-discussao/120`), corrigido em `4a82ff4` com 21 testes do próprio runner.
