## Espaçar disparo pausando ANTES do envio faz o worker dormir também na iteração que descobre a fila vazia — pause DEPOIS do envio confirmado {#pausar-antes-do-envio-dorme-na-iteracao-que-descobre-fila-vazia}

`tags: whatsapp, rate limit, fila, worker, drenagem, espacamento, throttle, banimento, laco, asyncio, TDD, R23`

**Sintoma:** você adiciona espaçamento entre envios num worker que drena uma fila (WhatsApp, e-mail,
SMS, webhook) para não disparar em rajada. O código fica assim, e parece o mais elegante — não deixa
pausa pendurada no fim do lote:

```python
for _ in range(BATCH_SIZE):
    if enviados:                       # "se já enviei algo, espaça"
        await asyncio.sleep(ESPACAMENTO)
    tratou = await processar_um()
    if tratou == 0:
        break
    enviados += 1
```

O resultado observável é **mais pausas do que envios**: 3 envios produzem **4** pausas.

**Causa raiz:** a iteração que **descobre que a fila acabou** também é uma iteração. Ela dorme
primeiro e só então chama `processar_um()`, que devolve zero e sai pelo `break`. Ou seja: o worker
paga uma pausa inteira **em todo tick de fila vazia** — que é o caso normal, não a exceção.

**Por que isso é pior do que parece:** workers assim costumam ter **vários laços sequenciais** no
mesmo tick (fila legada, outbox, entrada). A pausa desperdiçada de cada laço **atrasa os seguintes**.
Num caso medido (Plexco Tasks, 2026-09-07) eram 3 laços com espaçamento de 3s: até ~6s de tick ocioso
atrasando o laço de mensagens **RECEBIDAS**. O bot ficaria mais lento para **responder** por causa de
um ajuste feito para proteger o **envio** — uma regressão em cima do usuário, nascida de uma melhoria
de infraestrutura.

**Correção — pausar DEPOIS do envio confirmado:**

```python
for _ in range(BATCH_SIZE):
    tratou = await processar_um()
    if tratou == 0:
        break                          # fila vazia sai SEM dormir
    enviados += 1
    await asyncio.sleep(ESPACAMENTO)   # só depois de um envio que aconteceu
```

Custa uma pausa a mais no fim de um lote **que teve tráfego** — barata, e que ainda garante o
espaçamento entre o último disparo deste tick e o primeiro do próximo. Nunca custa nada quando não há
o que enviar.

**O invariante que interessa** não é "N-1 pausas para N envios"; é **"nunca dois disparos a menos de
`ESPACAMENTO` um do outro"**. As duas formas satisfazem esse invariante — só uma delas não cobra
imposto do caminho ocioso.

**Como testar sem esperar em tempo real:** substitua `asyncio.sleep` do módulo por um espião que só
registra o valor, e asserte na **lista de pausas**. O teste mede a *decisão* de pausar, não a pausa —
roda em milissegundos e não precisa de banco nem de rede:

```python
pausas = []
async def espiao(s): pausas.append(s)
with patch.object(worker.asyncio, "sleep", new=AsyncMock(side_effect=espiao)):
    await worker._tick()
assert pausas == [3.0, 3.0, 3.0]
```

⚠️ **O caso que discrimina é o TICK VAZIO.** Os testes de "3 envios" e "espaçamento configurável"
passam nas DUAS implementações. Sem um caso que exercite a fila vazia (e outro que a esvazie no
meio), a versão errada passa no verde e vai para produção.

**Enfileirar não substitui espaçar.** Trocar um envio direto por `enqueue` só muda **onde** a rajada
nasce: se o worker drena o lote sem pausa, a rajada continua existindo, agora com um passo a mais.
Número de mensageria é bloqueado por **padrão de disparo**, não por volume total.
