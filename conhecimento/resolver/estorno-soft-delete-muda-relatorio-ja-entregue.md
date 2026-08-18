## Estorno por soft-delete faz o relatório do mês passado mudar depois de entregue — use contra-lançamento {#estorno-soft-delete-muda-relatorio-ja-entregue}

tags: estorno, soft delete, deleted_at, cancelado_em, contra-lancamento, contra-baixa, retificacao, fechamento contabil, auditoria, retencao fiscal, imutabilidade, WHERE IS NULL esquecido, relatorio diverge, ledger

**Contexto:** você precisa desfazer um lançamento — pagamento aplicado errado, item cancelado,
comissão estornada. O reflexo é marcar a linha: `estornada_em`, `cancelado_em`, `deleted_at`,
e excluir da soma com `WHERE estornada_em IS NULL`. Nunca apaga nada, então parece seguro.

**Causa raiz:** marcar a linha **altera o passado**. O fato de março some da soma de março.
Se alguém já exportou, imprimiu ou entregou o relatório daquele mês, regerar agora devolve
número diferente — e as duas versões são "corretas" segundo o sistema. Em contexto fiscal ou
contábil isso é o defeito, não um detalhe: o que foi entregue tem que continuar sendo o que
foi entregue.

O segundo problema é operacional: a regra passa a morar numa cláusula `WHERE` que **toda**
consulta futura tem que lembrar — relatório novo, dashboard, consulta manual no banco, export
para o contador. Quem esquecer lê o dobro, e nada acusa.

**Solução — contra-lançamento:** o estorno é uma **linha nova** de sinal contrário, apontando
para a original (`estorna_id`). A original **nunca é tocada**. Somas passam a ser de todas as
linhas, sem cláusula de exclusão:

```sql
-- março: a linha original, intocada para sempre
INSERT INTO baixas (titulo_id, movimento_id, valor) VALUES ('T', 'M', 300);
-- agosto: a correção é um fato de agosto
INSERT INTO baixas (titulo_id, movimento_id, valor, estorna_id) VALUES ('T', 'M', -300, <id>);
```

O relatório de março continua igual ao entregue; o de agosto mostra a retificação. É como
contador faz na vida real.

**Decorrências que você vai encontrar (e nenhuma é opcional):**

- **Os CHECK de sinal viram condicionais ao tipo de linha:** `(estorna_id IS NULL AND valor > 0)
  OR (estorna_id IS NOT NULL AND valor < 0)`. Sem isso, uma contra-linha positiva soma em vez
  de desfazer.
- **UNIQUE(pai_a, pai_b) não sobrevive.** É a pegadinha: parece que um índice único parcial
  `WHERE estorna_id IS NULL` resolve, e **não resolve** — depois do estorno, reaplicar cria uma
  SEGUNDA linha original com o mesmo par, e as duas casam o predicado. A unicidade tem que sair
  do banco e virar pergunta no caso de uso.
- **A pergunta certa é "existe original que ninguém estornou", não "a soma é positiva".** Pela
  soma, uma contra-linha adulterada com magnitude maior que a original zera o par e libera
  lançamento novo. Existência não depende de magnitude:

```sql
SELECT 1 FROM baixas o
 WHERE o.titulo_id=:t AND o.movimento_id=:m AND o.estorna_id IS NULL
   AND NOT EXISTS (SELECT 1 FROM baixas c
                    WHERE c.estorna_id = o.id AND c.empresa_id = o.empresa_id)
```
  (o filtro de tenant na subquery não é decoração: sem ele, uma contra-linha de outro tenant dá
  a original por estornada.)
- **UNIQUE(estorna_id)** — estornar duas vezes devolveria o saldo em dobro.
- **Estado derivado, nunca guardado.** "Voltar para a situação anterior" tenta gravar o estado
  antigo na linha; derive do saldo resultante. O gravado envelhece na primeira coisa que mexer.

**Não confunda estornar o VÍNCULO com estornar o DINHEIRO.** Desfazer a aplicação de um
pagamento a uma fatura não move caixa — o dinheiro saiu do banco do mesmo jeito e o extrato
continua correto. Devolução real é um lançamento novo, com a data em que o dinheiro voltou.
Trocar os dois cria dinheiro que nunca existiu.

**Quando decidir:** antes do baseline da migration. Depois, virar soft-delete em
contra-lançamento é migration com backfill em tabela sob retenção.

**Ref:** Empresa Milionária, Fase A Task 11, 2026-08-12 (ADR-0007). O conselho recomendou
contra-lançamento por manutenibilidade; o argumento que decidiu foi o do relatório já entregue,
que veio da spec. A pegadinha do índice parcial foi encontrada implementando — o próprio
conselho a tinha recomendado como se funcionasse.
