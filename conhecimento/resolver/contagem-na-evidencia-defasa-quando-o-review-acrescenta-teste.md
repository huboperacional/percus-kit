## Contagem escrita na evidência defasa quando o review acrescenta teste depois {#contagem-na-evidencia-defasa-quando-o-review-acrescenta-teste}

`tags: evidência, RESULTADO.md, contagem de testes, review, R11, cross-provider, tracking, afirmação não medida`

**Sintoma:** a evidência da task e o registro no plano dizem "N testes no arquivo novo". O número casa com a conta do
plano e com a execução do momento em que o executor fechou a task. Depois, o review acha coisas, nascem testes novos, e
ninguém volta na contagem. O commit sai afirmando um número que o arquivo desmente. Medido em 2026-09-17 (Empresa
Milionária, Task 12 da leitura de NFS-e): evidência dizia 23, plano dizia 24, o arquivo tinha **26** — os três que
faltavam eram os que os próprios achados do review criaram. Quem pegou foi o revisor cross-provider, porque ele **rodou**
`pytest --collect-only` em vez de ler o diff.

**Causa raiz:** a evidência é escrita no fim da execução, e o ciclo continua depois dela (review, conserto, teste novo).
Toda contagem escrita antes do último passo é uma afirmação sobre o futuro.

**Solução:**

1. A contagem entra na evidência **depois** da última rodada de review, não antes. Se já estava escrita, quem commita
   remede e corrige — em todas as fontes, evidência **e** plano.
2. No relatório, diga de que momento é o número ("N quando o executor fechou; M no commit"), em vez de trocar o número e
   apagar o histórico.
3. Peça ao revisor cross-provider que **execute** as contagens que a evidência afirma. Ler o diff não pega defasagem.
4. Vizinhos: `declaracao-no-tempo-do-medido-vira-ja-conferido` e `prosa-do-review-r11-nao-passa-pelo-fact-check`.
