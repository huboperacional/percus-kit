## "Concluída" decidida pelo TEXTO do status apodrece em silêncio quando o produto deixa renomear {#status-por-texto-apodrece}

`tags: status, texto do status, ILIKE cancel, IN done completed, renomear situacao, completed_at, cancelled_at, predicado centralizado, progresso, metrica divergente`

**Sintoma:** métricas e telas erram só para *algumas* organizações — as que renomearam a situação
terminal. Barra de progresso da tarefa-mãe em 0% com tudo pronto; aviso de prazo cobrando tarefa já
entregue; contagem de "concluídas" divergindo entre dois gráficos da mesma tela.

**Causa raiz:** o código compara `status` com uma lista fixa (`IN ('done','completed','concluido')`) ou por
substring (`ILIKE '%cancel%'`). Funciona no seed padrão e quebra no minuto em que alguém chama a
situação de "Entregue" ou "ABORTADO". A heurística de substring erra nos **dois** sentidos: deixa
passar o que devia excluir ("ABORTADO" não casa "cancel") **e** exclui o que devia passar
("Cancelamento aprovado" é um desfecho concluído).

**Correção:** um marcador booleano/timestamp, nunca o texto. No caso: `completed_at` + `cancelled_at`,
com predicados centralizados num módulo só (`is_done`, `is_terminal`, `is_open`) em duas formas —
expressão ORM e fragmento SQL cru — para que query hand-rolled e ORM não divirjam.

**O que torna isto caro:** não é um call-site, são vários, e eles **não aparecem juntos no grep óbvio**
(um usa `IN`, outro `ILIKE`, outro nem filtra). Num único épico apareceram **5**, e o mais grave
(progresso da tarefa-mãe) já estava documentado como armadilha conhecida no projeto — o call-site
simplesmente nunca tinha sido migrado. Documentar não fecha; **grep dirigido antes de tocar em
qualquer contagem** fecha:

```
grep -rn "status.in_(\|status NOT IN\|ilike(\"%cancel\|'done', 'completed'" backend/app/
```

**Achado por teste, não por leitura.** O 5º bug apareceu porque um teste escrito para *outra* coisa
(progresso da mãe após PATCH via API) falhou com `Decimal('0.00') == 100`. Teste de integração que
exercita o efeito colateral real encontra o que a revisão de diff não vê.

**Ref:** Plexco Tasks s141 (2026-07-18/19), épico WS-C F3 `/ext` escrita.
