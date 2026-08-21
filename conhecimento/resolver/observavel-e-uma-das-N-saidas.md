## O observável escolhido é UMA das N saídas do caminho que você quer barrar {#observavel-e-uma-das-N-saidas}

`tags: teste vacuo, observavel, assercao por string, fala, TDD, red green, call site, guarda, spy, teste passa em cima do defeito, suite verde mentirosa, mutacao`

**Sintoma:** você escreve o teste ANTES do código (TDD honesto), com o exemplo CERTO — o dado que
dispara o mecanismo do defeito — e mesmo assim ele nasce **VERDE**. O passo 2 do loop de TDD manda
parar: *"ou o comportamento já existe, ou o teste não testa nada"*. Nenhum dos dois é verdade aqui,
e é isso que torna o caso confuso.

**Causa raiz:** o exemplo está certo; o **observável** está errado. Você quer barrar a entrada em um
**caminho** (fechamento, escalação, handoff, checkout, retry) e assertou sobre **uma das saídas**
dele. O caminho tem várias, escolhidas por estado interno, e o turno saiu por outra. O teste não
mede o caminho — mede uma folha do caminho.

**É irmão de [#teste-passa-em-cima-do-defeito], com o eixo trocado.** Lá o *exemplo* desvia do
mecanismo. Aqui o exemplo acerta e a *lente* é estreita demais. As duas produzem verde mentiroso; a
detecção é diferente, e por isso o verbete é separado.

**Caso real (tiatendo, 2026-08-21, frente N27 — o cliente cola o próprio resumo de carrinho).** Três
testes de call site — *"o texto colado NÃO vai ao checkout"* — nasceram verdes. O predicado era
`"retirada" in fala and "entrega" in fala`, porque a fala medida em produção tinha sido *"Vai ser
retirada ou entrega?"*. No harness, com outro estado de carrinho, o **mesmo** fluxo de fechamento
respondeu *"Antes de fechar, como você se chama? 🙂"* — o turno **entrou** no fechamento, que era
exatamente o que o teste existia para impedir, e passou. O conserto foi trocar a lente por um
observável **estrutural**: um spy sobre `_awaitConfirm`, a função de ENTRADA do caminho. Depois
disso os três ficaram vermelhos, e o código os fez passar.

**Detecção — três perguntas, nesta ordem:**
1. **O teste nasceu verde no TDD?** Se o exemplo dispara o mecanismo e ainda assim está verde,
   suspeite do observável antes de suspeitar do exemplo.
2. **Imprima a saída real.** Um teste temporário que faz `assert False, f"{saida!r}"` responde em 30
   segundos o que meia hora de leitura não responde. Foi assim que a fala do "como você se chama"
   apareceu.
3. **Pergunte: quantas saídas tem esse caminho?** Se a resposta é "não sei", a asserção por string
   está errada por construção.

**Regra prática:** para "não entrou no caminho X", asserte sobre a **ENTRADA** de X, não sobre o que
X fala.
- ✅ spy/mock na função de entrada (`_awaitConfirm`, `escalate`, `beginCheckout`) — `chamada == 0`
- ✅ o efeito estrutural que só X produz (pendência armada, status gravado, evento emitido)
- ❌ substring da fala — a fala é a folha, e folha muda com estado, idioma, A/B e humanizador

E quando a fala **for** o requisito (RF que diz *"não pode citar o texto do cliente"*), asserte a
fala **além** do observável estrutural, nunca no lugar dele.

**Por que review e conselho não pegam:** o nome do teste, o exemplo e o assert estão todos coerentes
entre si. A distância mora entre a *lente* e o *caminho*, e nenhum dos dois aparece no diff — o
caminho está em outro arquivo, e suas outras saídas em outro ramo.

**Ref:** tiatendo 2026-08-21, frente N27 `[3-H]`
(`tests/restaurant/test_n27CallSite20260821.py`, classe `_SpyClose`; spec
`docs/superpowers/specs/2026-08-21-n27-readback-colado-design.md` §4a). Vizinhos:
[#teste-passa-em-cima-do-defeito] (o EXEMPLO desvia do mecanismo),
[#mutacao-sobrevive-predicado-quase-certo] (a mutação mira o predicado),
[#teste-que-imita-o-produtor-nao-amarra-nada] (o teste reimplementa em vez de consumir),
[#alvo-de-mutacao-pode-nascer-podre] (o alvo não casa e o verde é falso).
