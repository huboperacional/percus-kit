## `asyncio.sleep(X)` acorda ANTES de X no Windows — asserção "demorou pelo menos X" fica intermitente {#asyncio-sleep-acorda-antes-do-prazo-no-windows}

`tags: teste flaky, asyncio, sleep, time.monotonic, windows, resolucao do relogio, dublê lento, timeout, orcamento de tempo, pytest-asyncio`

**Sintoma:** um teste que prova "o dublê dormiu a demora inteira" (`await dublê(demora=0.3)` e
`assert time.monotonic() - inicio >= 0.3`) passa quase sempre e cai de vez em quando — inclusive numa rodada de
sabotagem que mexia em **outra** coisa, o que faz parecer que a sabotagem atingiu o teste errado.

**Causa raiz:** no Windows, o laço do `asyncio` agenda o despertar com a resolução do relógio do sistema (~15,6 ms), e
`asyncio.sleep(0.3)` pode voltar **um pouco antes** do que `time.monotonic()` mede. Medido em 2026-09-16 (Empresa
Milionária, Python 3.12, `IocpProactor`): 40 execuções de `await asyncio.sleep(0.3)` → mínimo **0,297 s**, **3 de 40**
abaixo de 0,3.

**Por que engana:** o limiar `>= X` parece a tradução literal de "dormiu X". E a falha é rara o bastante para ser lida
como carga da máquina — ou, pior, como efeito colateral da mudança que você acabou de fazer.

**Como resolver:** dê margem **na direção que não aproxima os dois casos que o teste separa**. Se o teste distingue
"dormiu 0,3 s" de "respeitou um `timeout` de 0,01 s", `>= 0.25` continua separando (o segundo volta em ~0,016 s). Escreva
no comentário a medição que justificou a margem. O mesmo vale para `<= X` do outro lado: o `sleep` também pode acordar
**depois**, então asserção de teto precisa de folga larga (ex.: prazo de 0,5 s, teto de 1,5 s).

**Como confirmar que era isso:** meça fora do teste — um laço de 40 `sleep` contra `time.monotonic()`, guardando o
mínimo e quantos ficaram abaixo. Se aparece valor abaixo do pedido, o limiar exato é o defeito.

Relacionado: [[timer-solto-no-mock-atravessa-a-fronteira-do-teste]].
