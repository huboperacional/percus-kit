## Lista destrutiva datada pelo campo de AUDITORIA em vez do de negócio {#lista-data-auditoria-vs-negocio}

`tags: listagem, desambiguacao, data errada, criado_em, created_at, parcelamento, exclusao, perda de dado, campo de auditoria`

**Contexto:** o bot lista N itens pro usuário escolher um número (pra excluir/corrigir) e todas
as linhas aparecem com a MESMA data, ficando indistinguíveis — mas no banco as datas estão
corretas e diferentes.

**Causa raiz:** o formatador exibe o campo de **auditoria** (`criado_em`/`created_at`) em vez do
campo de **negócio** (`data_prevista`/vencimento). Registros criados na mesma transação (parcelas
de um parcelamento, importação em lote) têm `criado_em` idêntico. O bug é **invisível** no caso
comum — item criado no mesmo dia a que se refere — e só aparece com data futura, retroativa ou
lote. Procure a classe, não o caso: costuma haver o mesmo trecho copiado em 2-3 telas.

**Solução:** exibir sempre o campo de negócio. Trate como severidade alta, não cosmético: se a
data é o único campo que distingue as linhas e o fluxo pede um número pra **apagar**, o usuário
escolhe às cegas dentro de uma ação destrutiva. Teste de regressão: crie 2+ registros na MESMA
transação com datas de negócio diferentes e afirme que ambas aparecem na saída.

**Ref:** Família Milionária `312cfd1` (3 sítios em `whatsapp/service.py`; parcelamento 5x saía
com as 5 parcelas na mesma data).
