## Guarda no ponto da ESCRITA não protege fluxo de DOIS turnos {#guarda-de-escrita-nao-cobre-dois-turnos}

`tags: guarda de escrita, dois turnos, menu de desambiguacao, alvo resolvido antes, pergunta vira escrita, FR-1.1, veto que so nega, clarificacao, bot conversacional, estado pendente, teste passa vazio`

**Sintoma.** Existe uma regra que barra escrita a partir de pergunta/incerteza, ela tem teste, está
em produção — e mesmo assim uma pergunta produz escrita. O log da regra mostra que ela **nem rodou**
para a frase problemática.

**Causa.** Entre a frase do usuário e a escrita existe um **menu de desambiguação** que resolve o
alvo ANTES da guarda. O turno 1 (a pergunta) só produz o menu; o turno 2 é `"1"` — assertivo, com
alvo já resolvido — e é só nele que a guarda roda. A pergunta vira escrita em dois turnos, e o
turno que carregava a INTENÇÃO não é o turno que ESCREVE.

Medido em 2026-08-15 num bot financeiro: *"será que eu já paguei o spotify?"* com duas recorrências
homônimas virava *"Qual você pagou? Encontrei 2"*, e o `"1"` seguinte dava a baixa.

**Como procurar.** Para cada caminho de escrita, pergunte: *existe menu/clarificação que resolve o
alvo antes da guarda?* Se existe, a guarda tem de ser consultada **na entrada do menu** também.

**Correção sem afrouxar.** Um veto isolado que **só nega, nunca autoriza**, chamado antes de emitir o
menu, e que registra a recusa na MESMA observabilidade das outras — senão o alarme nasce cego
justamente para esse caminho. Devolva o mesmo desfecho que a frase teria no caminho não-ambíguo, em
vez de inventar copy nova.

**Armadilha do teste.** O teste do 2º turno passa VAZIO se o estado pendente não foi gravado (ex.:
o gravador desiste em silêncio quando não há linha de sessão). Garanta o pré-requisito e confirme
que o 1º turno realmente abriu o estado.

Ver também: [teste que passa em cima do defeito](teste-passa-em-cima-do-defeito.md).
