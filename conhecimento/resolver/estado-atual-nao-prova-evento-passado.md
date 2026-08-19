## Estado atual não é evidência de evento passado — quando o artefato pode ter sido limpo, pergunte ao LOG {#estado-atual-nao-prova-evento-passado}

`tags: verificacao, estado vs evento, artefato apagado, trilha de atividade, activity log, GHL, opportunity, teste limpo, falso negativo, evidencia, inventario`

**Sintoma:** você conserta algo, o operador testa e diz "funcionou, eu vi", e **toda consulta que você
faz devolve zero**. Por contato, por coleção, pela conta inteira: nada. A leitura natural — e errada —
é "o conserto não pegou" ou "o operador se confundiu".

**Causa raiz: você está perguntando o que EXISTE AGORA, e a pergunta era o que ACONTECEU.** Entre o
evento e a sua consulta cabe uma limpeza — muitas vezes feita pelo próprio operador, justamente porque
era um teste. O artefato nasce, cumpre o papel de prova, e é apagado por higiene. A consulta de estado
chega depois e não encontra nada, sem conseguir distinguir "nunca existiu" de "existiu e foi removido".

**O caso (AutoWorx / GoHighLevel, 2026-08-19):** o gatilho `Form Submitted` foi acrescentado a um
workflow às 21:00:35. Submissão às 21:03:34. Consultas de oportunidade — filtrando por contato, por
pipeline e pela location inteira — devolveram **0**, e o relatório saiu dizendo que faltava provar.
A trilha de **atividade da conversa** contava outra coisa:

| horário | entrada |
|---|---|
| 21:03:34 | `TYPE_FORM_SUBMISSION` — formulário enviado |
| 21:04:57 | `TYPE_ACTIVITY_OPPORTUNITY` — **Opportunity created** |
| 21:06:14 | `TYPE_ACTIVITY_OPPORTUNITY` — **Opportunity deleted** |

O conserto funcionou em **83 segundos**. O card foi apagado **77 s depois de nascer**. Os dois lados
estavam certos, e só o log reconciliava.

**Solução:**
1. **Antes de concluir "não funcionou", pergunte se o artefato pode ter sido removido** — e a resposta
   é quase sempre sim quando o teste foi feito por uma pessoa que limpa o que suja.
2. **Procure a trilha de EVENTOS, não o inventário.** Em CRM/SaaS quase sempre existe: activity log,
   audit trail, timeline do registro, histórico de conversa. Em sistema próprio, é o log da aplicação.
3. **Prefira o evento à contagem, inclusive quando dá certo.** "O total subiu de 27 para 28" é bom;
   "existe uma entrada `created` às 21:04:57" é melhor — sobrevive à limpeza e carrega o horário, que é
   o que permite casar causa e efeito (o gatilho entrou às 21:00:35: o `created` às 21:04:57 prova a
   ordem; a contagem, sozinha, não prova nada sobre ordem).
4. **Quando pedir um teste a alguém, peça também que NÃO limpe até você conferir** — ou avise que vai
   ler o log, para que a limpeza não custe a prova.

**Consequência que vale além do caso:** o mesmo erro aparece em toda verificação pós-fato — arquivo
temporário que o processo apagou, container que já morreu, mensagem que o destinatário deletou, branch
que foi removida depois do merge. **Ausência no estado é compatível com sucesso no evento.** Só o log
separa "não aconteceu" de "aconteceu e passou".

**De carona, um falso negativo de API na mesma investigação:** `date=desc` no
`/opportunities/search` do GoHighLevel **zera o resultado** em vez de ordenar — parâmetro não
suportado que não devolve erro, devolve lista vazia. Parâmetro inventado que "não dá erro" é pior que
parâmetro rejeitado: some com o dado e parece resposta. Ao ver uma coleção vazia inesperada, **repita a
consulta sem os parâmetros opcionais** antes de acreditar nela.

**Relacionado:** [#health-check-versao-vence-autoupdate] (leitura com prazo de validade) ·
[#ausencia-por-design-vs-falha] (ausência que é decisão, não defeito).

**Ref:** Scraper-prospeccao / AutoWorx NJ, 2026-08-19. Contato `FMm20txVgg1Gm90XYWJd`, conversa
`SF1zQix0w9Sg2LlyM3V9`. R23.
