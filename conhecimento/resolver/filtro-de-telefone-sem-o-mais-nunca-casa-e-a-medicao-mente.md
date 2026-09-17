## Filtro de telefone sem o `+` nunca casa, e a medição mente sem falhar {#filtro-de-telefone-sem-o-mais-nunca-casa-e-a-medicao-mente}

tags: medicao, sql, telefone, e164, faixa-reservada, falso-dado

**Sintoma.** Uma consulta de medição devolve números plausíveis, você tira conclusões deles, e as
conclusões estão erradas. Nada falha: a query roda, o resultado vem, o filtro simplesmente não
filtrou nada.

**O caso.** Medindo o pico de mensagens por número para calibrar um limiar (2026-09-17), usei:

```sql
WHERE direcao = 'enviado' AND numero_destino NOT LIKE '5500000%'
```

A faixa `+5500000…` é a reservada para testes desta casa. O filtro **nunca excluiu nada**, porque a
coluna grava o número em E.164 **com o `+`** (`+550000077777`), e `LIKE '5500000%'` ancora no
primeiro caractere. Resultado: o "pico real de envios" apareceu como **90/hora** — e vinha de números
de teste. O pico verdadeiro era **32/hora**. Um limiar calibrado no número inflado teria nascido ~3×
frouxo demais, e o guard que ele protege teria passado o loop inteiro.

**O conserto.** `NOT LIKE '%5500000%'`, ou normalize antes de comparar. Melhor: tenha **uma** função
de normalização (E.164 com `+`) usada tanto na gravação quanto na consulta — formas divergentes entre
as duas pontas são a mesma classe de erro, e aí o sintoma é pior: o registro nunca casa com quem o
criou.

**O que torna esta classe cara.** Filtro que não casa **não falha**: devolve mais linhas, e mais
linhas parecem "dado abundante". O erro só aparece se você olhar *quais* linhas vieram. Por isso, ao
medir para calibrar um limiar:

1. Imprima **uma amostra** das linhas que sobraram, não só o agregado.
2. Confira se o filtro de exclusão de fato excluiu — conte os dois lados (`count(*)` com e sem).
3. Desconfie de pico muito acima da média: na FM, média 5,3/h contra "pico" de 90/h era o sinal.

⚠️ Mesma família do erro em [[semear-estado-com-a-chave-errada-cria-segunda-linha]]: o `+` do telefone é um
caractere significativo, e tratá-lo como decoração já custou duas vezes nesta casa.
