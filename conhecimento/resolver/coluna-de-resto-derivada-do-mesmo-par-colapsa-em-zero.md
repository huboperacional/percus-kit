## Coluna que mede "o que falta" vira zero por álgebra se as duas derivadas saírem do mesmo par de medidas {#coluna-de-resto-derivada-do-mesmo-par-colapsa-em-zero}

`tags: relatorio, decomposicao, invariante, spec, conselho, algebra, R23`

**Sintoma:** uma tabela com N colunas onde a última promete mostrar "o resto", "o não
classificado", "o gap", "o não explicado" — e ela é sempre `0`, em todo cenário, sem que nada
esteja quebrado.

**Caso real (2026-09-02, DRE do Paid Media).** A seção de saídas ia ganhar quatro colunas:
identificado · não identificado · **não coletado** · total. A spec chegou a escrever um invariante
explícito dizendo que o total tinha de ser **medido, nunca somado**, justamente para a terceira
coluna não nascer zero por construção. Três parágrafos abaixo, as fórmulas eram:

```
naoIdentificado = total − identificado
naoColetado     = total − identificado − naoIdentificado
```

Substituindo a primeira na segunda: `naoColetado ≡ 0` **sempre**. O invariante foi violado pela
álgebra, não por descuido de implementação — e passou por **duas rodadas de conselho** antes de
alguém ver.

**Causa:** duas derivadas tiradas do **mesmo par** de medidas não carregam informação nova — a
segunda é a primeira reescrita. Uma coluna "quanto falta explicar" só pode ser diferente de zero se
existir uma medida que **não participou** da primeira subtração.

**Correção — conte as medidas INDEPENDENTES, não as colunas.** Para N buckets exibidos você precisa
de N−1 medidas independentes, e cada derivada tem de sair de um **par diferente**:

| Medida | Independente de |
|---|---|
| `identificado` | atribuição (quem casou no CRM) |
| `coletado` | o que a nossa coleta tem |
| `totalConta` | o que a plataforma cobrou |

```
naoIdentificado = coletado   − identificado     ← par 1
naoColetado     = totalConta − coletado         ← par 2
```

**Teste de 10 segundos, antes de aceitar qualquer desenho desses:** substitua as fórmulas umas nas
outras. Se alguma coluna some, ela é enfeite. Vale para "outros", "resto", "não classificado",
"gap", "não explicado", "diferença" — qualquer coluna cujo propósito seja denunciar uma divergência.

⚠️ **Quem pegou foi a perna do conselho que vinha falhando.** Duas rodadas com 2 de 3 pernas
passaram por cima. Ver [[401-identico-nao-e-env-stale-pode-ser-chave-morta]] para o contorno que
recupera a perna faltante — e não trate `2 de 3` como consenso quando o artefato é uma spec, que é
justamente o momento em que o defeito custa barato.
