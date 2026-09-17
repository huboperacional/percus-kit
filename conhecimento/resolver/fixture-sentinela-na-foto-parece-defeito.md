## Fixture sentinela é certa para a asserção e errada para a foto — na foto de aprovação ela parece defeito {#fixture-sentinela-na-foto-parece-defeito}

`tags: fixture, sentinela, screenshot, evidencia, aprovacao visual, e2e mockado, total, soma, playwright, R1, R23`

**Sintoma:** o spec mockado da tela prova direito que o rodapé mostra o total **do servidor** — o
fixture traz um total SENTINELA que não é a soma das linhas, e o teste afirma a ausência da soma. O
mesmo teste tira a foto que o operador vai usar para aprovar a tela. Na foto, a coluna não fecha: as
linhas somam 7.626,60 e o rodapé diz 9.131,55. Quem aprova vê um defeito de soma que não existe, e
pode reprovar a tela por ele.

**Reprodução real** (Empresa Milionária, tela do Orçado, 2026-09-13): o review cross-provider apontou
a foto como "fixture confirmando fixture" e aceitou a marca honesta; o problema real que sobrou era a
foto contradizendo as próprias linhas.

**Por que as duas coisas não cabem no mesmo teste:** o sentinela só discrimina se for inconsistente —
num fixture consistente, uma tela que somasse as linhas sozinha passaria sem nunca ler o campo do
servidor. E a foto só serve se for consistente. Os requisitos são opostos.

**Conserto:**

1. Mantenha o sentinela no teste que **afirma** (é ele que prova "lê o servidor").
2. Tire a foto num **teste à parte**, com o mesmo fixture de linhas e totais que **fecham** — e afirme
   o total consistente antes de fotografar, senão a foto pode sair da tela errada.
3. Ao lado da foto, um `RESULTADO.md` dizendo o que ela é (dados mockados, não prova de banco).

**Prova de que o sentinela ainda discrimina:** sabote a tela para somar no cliente e veja o teste
cair exatamente no valor sentinela (no caso real: esperado 9.131,55, recebido 12.362,80 — as folhas
somadas junto com a linha de grupo).

**Relacionados:** [[o-screenshot-pega-o-que-a-guarda-nao-ve]], [[fixture-que-mente-faz-a-mutacao-mentir-junto]].
