## "Recebi a mesma mensagem 2x" num teste onde todos os registros apontam pro MESMO destino não é duplicata — é o teste que não consegue distinguir {#teste-mesmo-destino-nao-distingue-duplicata}

`tags: disparo duplicado, falso alarme, teste com telefone unico, mesmo destinatario, whatsapp, deduplicacao, evidencia, log antes de concluir`

**Sintoma:** o operador reporta "chegou duplicado" durante um teste de disparo, com print da caixa
de entrada mostrando duas mensagens parecidas. Regra de segurança manda pausar na hora — mas a
investigação não acha duplicação nenhuma no sistema.

**Causa raiz:** os N registros de teste foram criados apontando todos para o **mesmo destinatário**
(o telefone/e-mail do próprio operador, que é o jeito seguro de testar). Cada um dispara **uma**
mensagem, corretamente, mas todas caem **na mesma conversa** — e a caixa de entrada não tem como
mostrar que vieram de registros diferentes. O que parece "a mesma mensagem 2x" é "2 registros
distintos, 1 mensagem cada", ainda mais convincente quando o conteúdo é idêntico por design
(mesmo template).

**Como decidir em um minuto, sem depender da caixa de entrada:** cruze com o log de disparo antes de
concluir qualquer coisa.

```sql
SELECT lead_id, event_type, created_at FROM <tabela_de_log>
WHERE event_type = '<evento_de_disparo>' ORDER BY created_at DESC;
```

Duas linhas com **ids diferentes** = comportamento correto. Duas linhas com o **mesmo id** = a
duplicata é real. Confira também o intervalo contra a regra de espaçamento configurada: se bate com
a faixa esperada (ex.: 5-15min), é o agendador funcionando.

**Não relaxe a regra por causa disto.** Pausar primeiro e investigar depois continua certo — o custo
de pausar é baixo, o de uma duplicata real com pessoa de verdade não é. O que muda é a ordem: pause,
**depois** cruze com o log, e só reative com causa-raiz fechada.

**O resíduo costuma ser real.** No caso de referência, o alarme era falso para um canal e
**verdadeiro para o outro**: havia uma segunda mensagem sem NENHUM disparo correspondente no log —
originada dentro da ferramenta externa (um passo extra no bot), não no orquestrador. Sem o
cruzamento, os dois casos ficariam no mesmo balaio e o de verdade seria descartado junto.

**Solução de teste:** para exercitar duplicidade de verdade, use destinatários distintos por
registro; se não der, trate o log como a única fonte de verdade e diga isso em voz alta no runbook.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12, 6 leads de teste apontando para o mesmo telefone.
