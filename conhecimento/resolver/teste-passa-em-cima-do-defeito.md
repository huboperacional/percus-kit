## Teste que passa EM CIMA do defeito: o exemplo escolhido é o único em que o bug não aparece {#teste-passa-em-cima-do-defeito}

`tags: teste vacuo, teste decorativo, exemplo escolhido, fixture, mutacao, prova por mutacao, reverter o fix, suite verde mentirosa, regressao, red green, TDD, cobertura cega, nome do teste, review nao pega`

**Sintoma:** existe um teste que **nomeia exatamente** o comportamento em questão, ele está **verde**,
e o defeito está **vivo em produção**. Ninguém desconfia dele justamente porque o nome é bom.

**Causa raiz:** o teste escolheu o exemplo em que o **mecanismo do defeito não pode disparar**. O
assert está certo; o dado é que desvia da armadilha.

**Casos reais (tiatendo — três no MESMO dia, 2026-07-31).** O mais didático: um teste "provava" que,
ao trocar de endereço, a **rua nova** era preservada — e usava a **única rua fora da lista de
endereços salvos**. O defeito era exatamente *a rua salva casar antes de o número novo ser lido*; com
uma rua que não está na lista, ele **não tem como acontecer**. Em produção, *"hoje é na Rua Major
Capile, 500"* entregava no **2680**. Os outros dois tinham a mesma assinatura: fixture sempre com o
YAML preenchido (o fallback nunca via YAML vazio) e asserção sobre o caminho feliz de um guard cuja
falha morava no caminho não previsto.

**Detecção — só um método funciona: mutação.**
1. Reverta o fix (ou enfraqueça a linha) e rode **apenas** os testes que dizem proteger aquilo.
2. Se continuarem **verdes**, o teste é decoração — não protege nada e ainda **autoriza a regressão**,
   porque o próximo leitor confia no nome.
3. Faça isso **no momento em que escreve o fix**, não numa auditoria futura: é quando custa 30
   segundos.

**Por que review e conselho não pegam:** ambos leem o **nome** e o **assert**, que estão corretos. A
distância entre o exemplo e o mecanismo do defeito não está no diff — está no dado.

**Regra prática:** ao escrever teste que "prova" que X é preservado/escolhido/ignorado, escolha o
exemplo **em que o mecanismo do defeito está ativo** (a rua que ESTÁ na lista, o apartamento que
colide, o rótulo que é prefixo de outro, o YAML vazio). O exemplo fácil entra como **segundo** caso,
nunca como único.

**Ref:** tiatendo 2026-07-31, commits `4039f7a` (round 1 do review R11 achou o teste da rua) e
`c1ced5b` ("2 testes que passavam EM CIMA do defeito que diziam proteger"). Vizinhos, com recortes
diferentes: [#red-nunca-visto-embarca-fossil] (teste que nunca ficou vermelho),
[#mutacao-sobrevive-predicado-quase-certo] (mutação no **predicado**, não no exemplo),
[#fixture-uniforme-esconde-irregular] (fixture uniforme escondendo o caso irregular do lado da
produção), [#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra].
