## Sabotagem que move a constante compartilhada não cria divergência — a que discrimina desfaz o acoplamento {#sabotagem-que-move-a-constante-compartilhada-nao-cria-divergencia}

`tags: sabotagem, constante, teto, DTO, divergência, verde por construção, prova, teste`

**Sintoma:** o defeito era "dois lugares repetem o mesmo número e um deles ficou para trás" (um teto de tamanho escrito
no DTO e outro na leitura). O conserto certo é fazer os dois lerem **a mesma constante**. Aí a sabotagem óbvia — "troque
o número" — fica **verde**, e parece que o teste não pega nada. Medido em 2026-09-17 (Empresa Milionária, Task 13 da
leitura de NFS-e, sabotagem Z4).

**Causa raiz:** depois do conserto, mover a constante move os **dois** lados juntos. Não existe divergência para o teste
enxergar: o produto continua coerente, só com outro número. A sabotagem está atacando o valor quando o defeito era a
**duplicação**.

**Solução:**

1. Sabote o **acoplamento**, não o valor: devolva um dos lados ao literal (o DTO volta a escrever `60` à mão) e mostre o
   teste vermelho. É isso que prova que o conserto é a fonte única, e não o número.
2. Vale para toda classe "dois lugares tinham de concordar": enum e CHECK, modelo e migration, mapa de código e mapa de
   frase. A pergunta é sempre "o que eu mudo para os dois DISCORDAREM?".
3. Quando a sabotagem óbvia ficar verde, declare no relatório em vez de trocar por outra que pareça boa: "verde por
   construção" é informação, e esconder isso vira confiança fabricada.
4. Vizinhos: `sabotagem-pode-ser-impossivel-porque-outra-guarda-absorve` e `sabotagem-prova-a-primeira-assercao-nao-o-teste`.
