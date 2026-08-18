## Smoke verde pode não ter exercitado a guarda — e smoke vermelho pode ser bug do harness {#smoke-verde-pode-nao-ter-exercitado-a-guarda}

`tags: smoke, discriminador, prova fraca, roteamento, psql, boolean, harness, falso positivo, falso negativo`

Duas faces do mesmo erro: **confundir o desfecho com o mecanismo**. As duas apareceram na mesma sessão (2026-08-18), em direções opostas.

### Face A — verde sem ter medido nada

**Sintoma:** o smoke passa, mas a guarda nova nunca rodou. A entrada foi **roteada para outro caminho** antes de chegar nela.

**Caso medido:** um smoke afirmava que a mensagem `"sim"` não vira lançamento. Passou — e a métrica de recusa marcou **zero**, provando que o extrator sequer foi chamado: o classificador mandou `"sim"` para o ramo de conversa. O teste seria **igualmente verde com o código velho**. Pior: o incidente real acontecera justamente quando o roteamento caiu no outro ramo.

🔑 "Nada foi escrito" é prova **fraca**: seria verdade também se a mensagem tivesse morrido dez camadas antes. Prova forte é **positiva** — um rastro que só existe se a guarda tiver executado.

**Solução:**
- Todo smoke de guarda precisa de um **discriminador positivo**: linha de log/tabela emitida pela própria guarda. Sem ele o caso é **INCONCLUSIVO**, e inconclusivo tem de bloquear igual à falha (só muda o diagnóstico).
- Escolha uma entrada que comprovadamente **alcança** o caminho. Se `"sim"` roteia para conversa, use uma frase que roteia para o caminho sob teste mas continua inválida (ex.: `"paguei o mercado"` — tem verbo e alvo, não tem valor).
- ⚠️ **O discriminador também nasce fraco:** contar as linhas do serviço **inteiro** dá verde por causa da atividade de outro usuário na mesma janela. Isole por identificador próprio (família/tenant/id da rodada). Um discriminador que mede o vizinho não discrimina nada.

### Face B — vermelho com a produção correta

**Sintoma:** o smoke reprova e a conclusão automática é "a produção quebrou". Pode ser o **assert**.

**Caso medido:** o assert comparava `(expira_em > now())::text` com `"t"`. Em Postgres, `psql -t -A` renderiza um boolean **cru** como `t`/`f`, mas o **cast explícito** `(bool)::text` produz `true`/`false` — a comparação era False sempre, com o produto 100% certo.

**Solução:** antes de reportar incidente a partir de smoke vermelho, rode um diagnóstico **read-only** que imprima os valores **crus** (o dado gravado, o relógio, o delta) em vez do booleano já avaliado. Se os valores crus estão certos, o defeito é do assert. Em SQL de smoke, devolva o dado bruto e compare em Python, ou aceite `("t", "true")` nos dois sentidos.

⚠️ **Diagnosticar não é consertar.** Quando a regra da rodada é "se o smoke reprovar, pare e chame", medir a causa **antes** de reportar é parte de parar — não uma violação. O contrário produz incidente falso e pode motivar rollback de código correto.
