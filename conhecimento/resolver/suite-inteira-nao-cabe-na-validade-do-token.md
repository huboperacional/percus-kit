## A suíte inteira não cabe na validade do token, e o corte limpo é a assinatura {#suite-inteira-nao-cabe-na-validade-do-token}

`tags: 401, credenciais invalidas, token expirado, globalSetup, playwright, suite E2E, harness R1, workers 1, execucao sequencial, corte limpo, falha espalhada, auth-service, TTL, varredura completa, verde nao verificavel`

**Sintoma:** a suíte E2E inteira, que "estava verde", devolve metade de falhas numa varredura
completa. Muitas delas são `401` / credenciais inválidas, e há vermelhos em specs que ninguém
tocou — inclusive specs que **passaram sozinhos minutos antes**.

A leitura tentadora é "interferência entre specs" ou "a última mudança quebrou coisa". As duas
levam a caçar o culpado errado por horas.

**O que discrimina, e é barato:** olhe a **ordem de execução**, não o placar.

Num harness sequencial (`workers: 1`, `fullyParallel: false`), imprima a sequência de `ok`/`x` e
procure a **forma** da falha:

- **Falhas espalhadas** — passa, falha, passa, falha — é interferência entre specs, estado
  compartilhado sujo, ou defeito de código.
- **Fronteira única** — tudo passa até o N-ésimo, **nada** passa do N+1 em diante, sem uma única
  exceção nos dois lados — é **algo que expira com o tempo**. Quase sempre o token.

```
ok   2 aprovacao-por-link     ok   9 contas
ok   3 aprovacao-por-link     ok  10 dividas
ok   4 carga                  ok  11 liquidacao
...                           ok  13 orcamento-editor
ok   8 centros-custo          ───────── corte ─────────
                              x   14 orcamentos ... x 28 visao-geral
```

Nenhuma falha antes do 13, nenhum acerto depois do 14. Numa execução sequencial isso não é
coincidência: é o relógio.

**A causa estrutural:** o harness autentica **uma vez**, no `globalSetup`, contra o auth-service,
e guarda o token no storage state. A suíte inteira dura **mais** que a validade do token. Os
specs que rodam cedo passam; os que rodam tarde levam `401` — e o `401` aparece na primeira
chamada HTTP de cada um, que costuma ser uma leitura banal (`GET /pessoas`), o que faz parecer
defeito daquele spec.

**A consequência que mais importa, e que sobrevive ao caso concreto:**

> **"A suíte inteira está verde" pode não ser verificável em uma execução só.**

Se o TTL do token é menor que a duração da suíte, **nenhuma** execução única pode observar tudo
verde. Então:

- Um relato de *"N/N verde"* só é comparável se disser **em quantos lotes** foi obtido. Sem isso,
  dois números que parecem iguais podem descrever coisas diferentes — um lote grande que não cabe
  no token e vários lotes que cabem.
- Rodar em **lotes** que caibam na janela é uma saída legítima e honesta, desde que declarada.
- A correção de raiz é o `globalSetup` **renovar** o token no meio da execução (ou o harness
  reautenticar por spec), não "rodar mais rápido".

⚠️ **Não conclua "o token expirou" só porque viu um `401`.** Um `401` isolado tem muitas causas
(chave morta, env stale, audience errada). O que sustenta a conclusão é o **par**: `401`
predominante **e** fronteira única numa execução sequencial. Sem a segunda metade, é palpite.

📌 **Erro de instrumentação que esconde este achado:** capturar a saída com `| tail -N`. As
falhas interessantes ficam no **começo** do relatório, e o `tail` guarda o fim. Numa varredura de
17 minutos onde só 2 de 15 falhas sobreviveram no log, foi impossível diagnosticar e a execução
teve de ser refeita inteira. **Saída de execução que você ainda não entende se captura completa.**

Ver também [[401-identico-nao-e-env-stale-pode-ser-chave-morta]] (o `401` sozinho tem muitas
causas) e [[tres-jeitos-de-uma-guarda-produzir-verde-falso]].
