## A mensagem de uma guarda é parte da guarda — texto ambíguo desliga a proteção sem deixar rastro {#mensagem-de-guarda-e-parte-da-guarda}

`tags: teste, guarda, mensagem de assert, review, R11, desligar guarda, xfail, skip, agente, instrucao no assert, falso conserto, diff invisivel`

**Origem:** Empresa Milionária, 2026-08-25 — apontado por review cross-provider, sobre uma guarda
escrita minutos antes.

**Sintoma:** não há sintoma. A guarda existe, roda, está verde — e no dia em que ela finalmente
falhar, quem ler a mensagem vai **apagá-la** em vez de investigar. E apagar por instrução da
própria mensagem não parece errado no code review: parece seguir o combinado.

**O caso:** uma guarda de coerência entre instrumento e produto tinha, no ramo do estado atual:

```
"Se o instrumento já foi reescrito, apague este ramo — ele existe só para
 documentar a coerência atual."
```

O revisor viu o que eu não vi: essa frase **instrui a remover a proteção** exatamente no caso
que ela existe para pegar. Um agente (ou uma pessoa com pressa) vê o vermelho, lê "apague", apaga
— e a dessincronia passa calada.

**Causa raiz:** quem lê a mensagem de um assert está, **por definição**, no pior momento
possível: o teste acabou de barrar o trabalho dele, e ele quer seguir. Uma instrução ambígua ali
tem mais poder que o código do teste. E desligar por texto **não deixa rastro no diff** como
apagar um arquivo deixaria — some um `assert`, e a mensagem que autorizava some junto.

**Solução — a mensagem de falha responde três coisas, nesta ordem:**

1. **que estado é este** (nomeie: *"dessincronia inversa"*, *"conserto por subtração"*),
2. **qual é o dano concreto** — não "isto é inconsistente", e sim *"o harness vai reprovar o bot
   por não fazer o que ele nunca prometeu"*,
3. **o que fazer**, com a saída legítima explícita — e, quando cabe, **"não apague este teste
   para seguir"**, com a alternativa (reverter, ou registrar a decisão em ADR).

⚠️ **Nunca escreva "apague/remova/comente este teste" numa mensagem de assert.** Se um ramo do
teste é temporário, o que o expira é a **condição** (`if backendJáMigrou:`), não uma instrução
de texto para um humano apressado.

📌 **Corolário para review:** ao revisar teste, leia as mensagens de falha como código. Elas são
a interface da guarda com o futuro, e é onde a proteção costuma vazar.

Relacionado: [alarme-falso-mata-o-alarme](alarme-falso-mata-o-alarme.md) — o outro caminho pelo
qual uma guarda viva deixa de proteger.
