## Conselho responde bem à pergunta errada quando o contexto omite uma restrição {#conselho-contexto-incompleto}

`tags: conselho, council, pre-mortem, prompt incompleto, restricao de fluxo, multi-turno, veredito, autoridade do operador, reversao documentada`

**Sintoma:** conselho 3-membros dá veredito coeso (2/3, 3/3), o agente implementa, e o operador aponta na hora um caminho melhor que o conselho nem considerou.

**Causa raiz:** o prompt do conselho descreveu o problema sem uma restrição decisiva. No caso: perguntei se o bot devia "avisar ou perguntar" quando um item some do pedido, informando que o resumo é ecoado no fim — mas **omiti que o checkout é multi-turno** (o bot ainda faz 1 a 4 perguntas antes de fechar). O argumento central deles ("o cliente quis encerrar, não incomode") desmonta na hora: vamos incomodar de qualquer jeito.

**Solução:**
1. Antes de submeter, listar as **restrições de FLUXO** — o que acontece antes e depois do ponto de decisão, quantos turnos, o que ainda é reversível. Decisão de UX conversacional depende disso mais que do conteúdo da mensagem.
2. Perguntar-se: **"o que ainda é possível fazer nesse instante?"** No caso, a restrição que decidia era "o rascunho ainda está ABERTO, dá pra incluir o item de verdade" — depois do fechamento, perguntar prometeria o que não se pode cumprir.
3. Veredito do conselho **não vira autoridade sobre o operador**, que tem contexto de negócio que nenhum provider tem (ali: item omitido = venda perdida + chamado de suporte).
4. Ao registrar a reversão, dizer QUE o conselho errou **e por quê o input estava incompleto** — senão a próxima sessão relê o veredito antigo e reverte de novo.

**Ref:** tiatendo D16 (`0.236.0`). O desenho final ficou melhor que as 3 opções submetidas: pergunta 1× com escape + o aviso passivo do conselho como rede.
