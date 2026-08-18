## Mockup aprovado nunca gerado pelo algoritmo real de layout diverge da produção {#mockup-aprovado-sem-algoritmo-real-diverge}

`tags: mockup, artifact, previa aprovada, algoritmo de layout, BFS, baricentro, coordenada fixa, dado denso, divergencia em producao, aprovar a ideia nao o layout`

**Sintoma:** operador aprova uma prévia (Claude Artifact) com nós/raias organizados de um jeito
limpo; a implementação real usa um algoritmo de layout determinístico já existente (BFS+baricentro,
ou qualquer coisa que calcule posição a partir de dado real); em produção, com dado denso de
verdade, a ordem visual sai completamente diferente do que foi aprovado — parece regressão, mas o
código está "correto" (fez exatamente o que a spec pedia).

**Causa raiz:** o mockup foi posicionado À MÃO (coordenadas fixas, pensadas pra ilustrar o
CONCEITO) em vez de rodar o algoritmo real contra dado real. Funciona pra aprovar a IDEIA (cores,
interação, tipos de nó) mas nunca prova que o algoritmo de POSICIONAMENTO vai produzir aquilo — são
duas coisas diferentes sendo aprovadas junto sem querer.

**Solução:** ao construir a prévia de um redesenho que envolve um algoritmo de layout existente
(não só estilo/interação), rodar esse algoritmo de verdade contra uma amostra real de dado antes de
pedir aprovação — nem que seja um script standalone que chama a função de layout e dumpa
coordenadas, sem precisar do app inteiro rodando. Se isso não for viável a tempo, pelo menos avisar
explicitamente na hora da aprovação: "isto é só o CONCEITO visual, o posicionamento real vai vir do
algoritmo X, ainda não testado contra este mockup".

**Ref:** Paid Media Automation, cont.157 (2026-08-07), Fluxo de Páginas — raias de canal + tipo de
conversão. Ver `docs/adrs/0008-fluxo-de-paginas-permanece-literal-em-raias.md` e
`docs/STATUS.md` ADENDO 31/32.
