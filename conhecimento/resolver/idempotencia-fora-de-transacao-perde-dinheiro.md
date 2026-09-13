## Marcar a idempotência fora da transação faz o webhook engolir dinheiro em silêncio {#idempotencia-fora-de-transacao-perde-dinheiro}

`tags: webhook, idempotencia, transacao, atomicidade, pagamento, asaas, stripe, pagarme, reentrega, retry, 200, indice unico, prisma, silencioso`

**Contexto:** webhook de gateway de pagamento que credita alguma coisa (licença, saldo, plano).
O desenho parece certo: uma tabela com índice único na chave do pagamento impede crédito duplo, e a
rota devolve 500 em erro para o gateway reentregar. Os testes passam. Mesmo assim existe um caminho
em que **o dinheiro entra e o benefício não sai, sem ninguém saber**.

**Causa raiz:** a marca de idempotência é gravada num commit próprio, **antes** e **fora** da
transação que concede o benefício. A sequência que quebra:

1. `INSERT` na tabela de idempotência — commita sozinho.
2. O passo seguinte falha (blip de rede, deadlock, banco reiniciando).
3. A rota devolve **500**, e o gateway reentrega, como deveria.
4. Na reentrega, a marca **já existe** -> o handler conclui "duplicado" -> a rota devolve **200**.
5. O gateway para de reentregar. Fim.

O 500 não salva ninguém: ele só compra uma reentrega que vai ser recusada pela marca que ficou para
trás. E como "duplicado" é um resultado normal, ninguém loga nada — o modo de falha é mudo.

**Solução:** a marca de idempotência e a concessão do benefício têm de estar **na mesma transação**.
Se qualquer passo falhar, o `INSERT` é desfeito junto e a reentrega funciona de verdade.

```ts
// a rota abre a transação; o repositório recebe o cliente dela, não o global
const r = await db.$transaction((tx) => processar(evento, repositorio(tx), new Date()));
```

Dois cuidados que vêm junto:

- **A checagem prévia não é o árbitro.** `findUnique` antes do `create` é caminho rápido; quem
  resolve a corrida é o índice único. Deixe a violação derrubar a transação e traduza o código de
  unicidade (`P2002` no Prisma) para "duplicado" **fora** da transação — dentro, o Postgres já
  abortou e qualquer query seguinte falha.
- **O handler não pode engolir erro.** Se ele capturar a falha e devolver sucesso, a transação
  commita e você recriou o mesmo buraco por outro caminho. Vale um teste que force o passo de
  concessão a lançar e exija que a exceção **propague**.

**Sintoma correlato, mesma família:** enviar e-mail com `await` dentro do handler. Um SMTP lento
segura a resposta por dezenas de segundos, o gateway estoura o timeout e reentrega um pagamento já
processado. Aviso não é parte do commit — mande depois da resposta (`after()` no Next, fila em
outros stacks) e nunca deixe a falha propagar.

**Como perceber antes de doer:** procure no handler o ponto em que a marca é gravada e pergunte "se
a próxima linha falhar, a reentrega conserta?". Se a resposta for "não, ela vira duplicado", o
buraco está lá.

**Ref:** LiliCalc, Fase 4 (2026-09-12). Achado pelo conselho de 3 membros num diff que tinha 33
testes verdes — nenhum deles pegava, porque todos exercitavam o handler com repositório em memória,
onde não existe commit parcial. **Relacionado:** [`1/1` no Swarm não significa roteável](swarm-1de1-nao-significa-roteavel.md).
