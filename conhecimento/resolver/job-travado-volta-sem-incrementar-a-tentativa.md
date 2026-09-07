## Job travado volta pra fila SEM incrementar a tentativa — heurística baseada em `attemptsMade` confunde o próprio worker com um intruso {#job-travado-volta-sem-incrementar-a-tentativa}

`tags: bullmq, stalled, attemptsMade, retry, claim, idempotencia, worker morto, linha presa, PENDING eterno, dois caminhos, lock`

**Origem:** CL_Liliflow, 2026-09-07. Achado por review cross-Claude e confirmado lendo o Lua do BullMQ.

**Contexto.** Dois caminhos enfileiravam o mesmo comentário (webhook e reconciliador de polling), e
o segundo podia enviar DM duplicada. A defesa escrita foi: *"se existe uma linha `PENDING` recente e
`job.attemptsMade === 0`, então outro worker já reivindicou isto — cede"*.

**Causa raiz.** `attemptsMade` **não** é incrementado quando o BullMQ redevolve um job travado.
Verificável em `node_modules/bullmq/dist/cjs/commands/moveStalledJobsToWait-8.lua`:

```lua
local stalledCount = rcall("HINCRBY", jobKey, "stc", 1)
```

O contador que sobe é `stc` (*stalled count*), separado. `atm` (*attemptsMade*) só sobe em
`moveToFinished`, isto é, em **falha explícita**. Então o cenário real é:

1. worker A cria a linha `PENDING` e **morre** antes de terminar;
2. o BullMQ detecta o stall (~30-60s) e reentrega o **mesmo** job, com `attemptsMade` ainda **0**;
3. a heurística classifica a própria continuação do job como intruso, faz `continue` **em silêncio**;
4. o job termina como *completed*, sem exceção. A linha fica `PENDING` **para sempre** e nada
   dispara retry.

O modo de falha é o pior tipo: sem erro, sem log, sem job falhado. Só uma linha que nunca sai do
lugar e uma pessoa que nunca recebe a mensagem.

**Solução.** Não infira posse a partir de contadores de tentativa. Grave **o `job.id`** na linha no
momento da reivindicação e compare:

```ts
const isOwnContinuation =
  (job.id !== undefined && existingLog?.claimedByJobId === job.id) ||
  requeueAttempt > 0;
```

O `job.id` é estável entre reentregas por stall **e** entre retries do BullMQ. A segunda metade
cobre o requeue por rate limit, que é a única continuação legítima que chega sob um id **novo**.

- **O sinal que denuncia:** a defesa depende de um contador que outro sistema mantém, e você não
  leu a fonte dele. "Retry" e "reentrega por stall" parecem a mesma coisa e não são.
- **Acoplamento implícito que ficou pra trás na primeira correção:** a versão anterior só funcionava
  porque `IN_FLIGHT_MS` (10 min) era menor que `REQUEUE_DELAY_MS` (30 min) — duas constantes em
  arquivos diferentes, sem nada documentando a relação. Baixar o requeue pra 5 min faria DMs sumirem.
  Correção por identidade explícita elimina a dependência entre as duas.
- **Teste que prova:** reintroduza a heurística antiga e o teste do stall precisa **falhar**. Sem
  essa mutação, um teste que passa com `attemptsMade: 0` não distingue nada.

**Ref:** `CL_Liliflow/app/lib/queue/dm-worker.ts` (`isOwnContinuation`, `claimedByJobId`),
`__tests__/dm-worker.test.ts` ("resumes its own row after a stalled redelivery").
