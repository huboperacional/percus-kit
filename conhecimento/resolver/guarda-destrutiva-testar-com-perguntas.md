## Guarda contra ação destrutiva tem que ser testada com PERGUNTAS, não só com comandos {#guarda-destrutiva-testar-com-perguntas}

`tags: regex, detecção de intenção, nlp, guarda, remoção, falso positivo, revisão adversarial, assimetria`

**Sintoma:** a proteção contra "apagar sem o cliente pedir" passa em todos os testes e mesmo
assim apaga.

**Causa raiz:** os testes exercitavam **comandos** ("tira o X", "troca o X pelo Y"). Ninguém
testou **perguntas**. A regex de intenção de troca casava `melhor\s+[oa]` e `muda|mudar`, então
`"melhor a G ou a M?"` e `"muda alguma coisa se eu pedir sem cebola?"` — perguntas comuns, sem
intenção nenhuma de remover — **autorizavam a exclusão**. Pior: o cliente em dúvida entre
tamanhos é exatamente o turno em que o LLM mais erra o estado desejado. A guarda desligava
justamente quando era mais necessária.

**Solução:**
1. Teste a guarda com o corpus que ela vai encontrar de verdade: perguntas, comparações,
   dúvidas, bordões ("não, pera..."), negações ("nunca tira X"), e a palavra dentro de outra
   palavra ("Cola" dentro de "e**scola**" — case por `\b`, nunca por substring).
2. Autorize **por item**, não por mensagem: um "tira o X" legítimo não pode liberar um corte no
   Y que ninguém pediu.
3. Exija desambiguação quando o alvo é ambíguo: com dois tamanhos do MESMO prato no carrinho,
   nomear o prato não identifica a linha — peça o tamanho.
4. Escolha o lado para o qual a guarda falha, e escreva isso no código. Falhar **fechado**
   (perguntar sem precisar) custa um turno de conversa; falhar **aberto** (apagar) custa o
   dinheiro do cliente. Endureça só o lado aberto e **documente o custo aceito**, senão o
   próximo leitor "conserta" o que era deliberado.

**Ref:** tiatendo, `execution/engine/restaurantCartDiff.py` (2026-07-29), commits `51784a2`
→ `5571ba7`. Três rodadas de revisão, três furos, todos no desenho — nenhum no código gerado.
