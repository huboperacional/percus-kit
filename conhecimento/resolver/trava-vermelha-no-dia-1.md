## Trava que nasceria VERMELHA é trava desligada {#trava-vermelha-no-dia-1}

`tags: gate vermelho no dia 1, trava desligada, inventario fechado, lista que so encolhe, varredura AST, migracao incremental, pre-mortem, CI quebrado, shrink-only, contradicao na spec`

**Sintoma (previsto em pre-mortem, antes de custar caro).** Uma spec propõe varredura que falha para
qualquer ocorrência do padrão antigo. Como o padrão antigo existe em N lugares, a varredura nasce
vermelha, o CI vive quebrado, e em pouco tempo alguém a desliga — ou passa a evitar o caminho novo
para não lidar com ela. A dívida volta pela porta do próprio gate.

**Correção — e NÃO é "warning por duas semanas"** (prazo apodrece e ninguém volta):

1. a varredura nasce com **inventário fechado** das ocorrências atuais (lista explícita);
2. falha só para ocorrência **nova e não registrada**;
3. um teste irmão exige que a lista **só ENCOLHA** — cada migração apaga uma linha, e registrar
   exceção nova é proibido: a única saída verde para um caso novo é migrar.

Assim a trava fica verde o tempo todo sem nunca deixar de travar o que importa. Cuidado com a
redação: dizer "quebra até ser registrado" num parágrafo e "a lista só encolhe" no seguinte é
contradição — um implementador futuro adiciona a exceção e mata o invariante sem perceber.
