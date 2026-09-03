## Poder novo em componente compartilhado vaza para TODO host — inclusive o que uma decisão proíbe {#poder-novo-em-componente-compartilhado-vaza-para-todo-host}

`tags: componente compartilhado, reuso, autorizacao implicita, ADR violada em silencio, regressao invisivel no diff, host nao aparece no diff, guard no host, read-only, prova por comparacao, board vazio nao prova nada, capability, pre-mortem acertou`

**Sintoma:** você dá uma capacidade nova a um componente (arrastar, editar, excluir) atendendo a um
pedido para UMA tela. Nenhum teste fica vermelho, nenhum review aponta, o diff está limpo — e outra
tela, governada por uma decisão que proíbe exatamente aquilo, passa a permitir. A violação não tem
sintoma até alguém tentar.

**Causa raiz:** um componente reusado é uma **superfície de autorização implícita**. A capacidade
chega a todos os hosts de uma vez. Os hosts que não deviam recebê-la são **invisíveis no diff** —
justamente porque não mudaram. O revisor lê o arquivo que mudou; o host afetado está noutro arquivo,
intacto.

**Ocorrência (Plexco Tasks, 2026-09-03):** o Quadro de "Minhas tarefas" virou mutável por decisão do
operador (ADR-0016). O board da **Frente** reusa o mesmo componente e virou mutável junto — violando
o ADR-0015 ("a view agregada da Frente é somente-leitura"), que continuava valendo e não fora
discutido.

**Como evitar:**

1. Antes de dar poder novo a um componente usado em mais de um lugar, `grep` pelos **hosts** e decida
   host a host. A pergunta não é "quem quebra?" — é **"quem passa a poder o que não podia?"**.
2. O default do componente é o **menor** poder. Quem quer mais pede explicitamente por prop. O
   inverso (default poderoso, restrição opcional) faz do esquecimento a falha.
3. **O guard tem que ficar no HOST, não só no componente.** O teste do componente prova que o prop
   funciona; o teste da página prova que aquele host **continua pedindo** a restrição. É o segundo
   que pega a regressão do dia em que o componente ganhar o próximo poder.

**Como PROVAR que não vazou — e o erro que quase passou:** contar elementos arrastáveis num board
**vazio** não prova nada: zero cards produz zero draggables em qualquer modo. A primeira medição
feita foi essa, e era inconclusiva sem parecer. A prova é **comparação lado a lado, com dado nos
dois**:

| Tela | cards | arrastáveis |
|---|---|---|
| Frente (deve ser read-only) | 5 | **0** |
| Minhas tarefas (deve ser mutável) | 4 | **4** |

Mesmo componente, dado presente nos dois, resultados opostos.

**O que pegou, e vale replicar:** o pre-mortem do conselho apontou por consenso (2 de 2 membros) o
risco "split do read-only propagado pela metade", e a decisão escrita (ADR) tinha um **critério de
verificação explícito** — "a outra tela continua sem drag; esta é uma regressão que este ADR
proíbe". O critério foi escrito **antes** de codar. Sem ele, a leva teria sido dada por pronta.

Ver também: [Assert sobre um contêiner maior que o alvo passa vazio](assert-sobre-conteiner-maior-que-o-alvo-passa-vazio.md).
