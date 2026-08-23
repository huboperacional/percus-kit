## Semear estado com a chave "óbvia" cria uma SEGUNDA linha e o produto lê a dele {#semear-estado-com-a-chave-errada-cria-segunda-linha}

`tags: semear estado, smoke, chave de lookup, formato divergente entre tabelas, segunda linha, INCONCLUSIVO sem explicacao, log do container, jsonb_build_object, aspas duplas em sh -c`

**Sintoma.** Você semeia um estado por SQL para exercitar um fluxo que, em produção, só nasce de um
caminho caro (upload de arquivo, webhook de terceiro). O `INSERT` funciona, o `SELECT` de volta
mostra o estado certo com o contexto certo — e o produto responde **como se o estado não existisse**.
Nenhum erro em lugar nenhum.

**Causa raiz.** O formato de armazenamento **diverge entre tabelas do mesmo domínio**. No caso
medido: a tabela de usuários guarda o telefone como `+5500000…`, mas a tabela de sessões guarda os
**dígitos crus** (`5500000…`), que é o que o webhook entrega. Semeando com o `+`, o produto **criou
uma segunda linha** para o mesmo humano, leu a dele (`idle`) e ignorou a sua. As duas ficaram lado a
lado no banco.

**O que denunciou.** O log do serviço dizia `estado_antes: "idle"` enquanto o banco mostrava o estado
semeado. **Duas fontes discordando é o sinal.** A query de volta, sozinha, confirmava a *minha*
suposição (a linha existe!) e nunca a pergunta de produção (**qual** linha ele lê?).

**Solução.**
1. Ao semear, descubra a **chave de lookup real** lendo a função de leitura do produto — não a chave
   que "parece" a mesma. Quando der divergência, cheque duplicatas antes de tudo:
   `WHERE chave LIKE '%parte-estável%'`.
2. `SELECT` de volta prova que **gravou**, jamais que o produto vai **ler aquilo**. São perguntas
   diferentes.
3. Um caso que assertasse por **ausência** teria dado **PASS falso** aqui: "nada foi escrito" era
   verdade, e pelo motivo errado. Ver [[caso-ancora-da-ausencia-passa-por-merito-do-bug]].

**Footgun irmão, mesma família.** O helper que manda SQL por SSH costuma embalar a query em **aspas
duplas** dentro de `sh -c "... psql -c '...'"`. Um `json.dumps` no meio do SQL fecha a string do
shell e morre com `Unterminated quoted string`. Monte a estrutura **no destino** —
`jsonb_build_object(...)`, que só usa aspas simples — em vez de serializar na origem. O primo com
aspa simples está em [[aspa-simples-ssh-bash-c]].
