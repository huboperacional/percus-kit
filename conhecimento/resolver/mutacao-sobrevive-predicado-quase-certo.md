## A mutação sobreviveu: o código está certo e a prova de que precisa estar não existe {#mutacao-sobrevive-predicado-quase-certo}

tags: mutation testing, mutacao sobrevive, predicado quase certo, cobertura cega, OPEN_CONDITION,
enfraquecer predicado, prova por mutacao, dado que nao distingue, TDD

**Sintoma.** Você escreve o teste antes do fix (vermelho), aplica o fix (verde), e por hábito roda a
prova por mutação. Mas em vez de só **apagar** a linha de produção, você a troca pelo **"quase
certo"** — um predicado mais fraco que resolve o mesmo caso. E a suíte **continua verde**.

**Caso real (Plexco Tasks, s157, RF-9).** O `GET /levas/{id}` passou a excluir tarefa terminal pelo
predicado canônico `OPEN_CONDITION` (`completed_at IS NULL AND cancelled_at IS NULL`). Dois testes
novos, escritos antes do fix, tinham falhado pelo motivo certo. Trocando `OPEN_CONDITION` por
`completed_at IS NULL` sozinho: **11 passed**. A mutação não morreu.

**Por quê.** O caminho que os testes exercitavam (`mark_terminal(cancelled=True)`) carimba **os
dois** marcadores. Então, para aqueles dados, os dois predicados são indistinguíveis. O código
escolhido estava certo — e o teste não sabia disso.

**Por que isso importa mais do que parece.** Um teste que não distingue o predicado correto do
"quase certo" **autoriza a simplificação errada no futuro**. A próxima pessoa olha
`completed_at IS NULL AND cancelled_at IS NULL`, acha redundante, simplifica, roda a suíte, vê verde
e commita. O defeito volta em dado legado ou em qualquer caminho que carimbe só um marcador.

**Como resolver.** Não basta apagar a linha: **enfraqueça** o predicado e veja se algo morre. Se
nada morrer, o buraco não é o código — é a cobertura. Feche com um teste que **semeie diretamente o
estado que só o predicado forte distingue**, mesmo que nenhum caminho de produção o gere hoje:

```python
meia_cancelada.cancelled_at = datetime.now(timezone.utc)
meia_cancelada.completed_at = None   # estado que o modelo PERMITE
```

Documente **no próprio teste** por que aquele estado importa (colunas nullable e independentes, +
a docstring do predicado canônico que diz checar as duas), senão alguém o apaga como "impossível".

**Regra prática.** Onde houver predicado canônico com mais de uma condição, a bateria de mutação
tem que incluir **cada condição removida isoladamente** — não só o predicado inteiro apagado.
Predicado composto com teste que só exercita o caso "ambos verdadeiros" é teste vácuo numa dimensão.

**Relacionado:** [#404-por-design-esconde-tenancy] (erro que parece feature) ·
[#guarda-fonte-strip-string] (guarda que some com o que procura).
