## Um mock que FORÇA o LLM a sempre acertar não testa a ambiguidade — testa a resposta certa por decreto {#mock-que-forca-llm-a-acertar-esconde-classe-de-bug}

tags: llm, mock, teste, tdd, ambiguidade, falso-verde, non-determinism, produtor probabilístico, fixture, integração

**Sintoma:** um teste de integração cobre exatamente o cenário de produção que falhou ("cliente
aceita oferta ambígua de forma contextual, sem repetir o nome do item"), passa em CI, e mesmo assim
o MESMO cenário falha ao vivo em produção com o LLM real — de um jeito que o código de guarda
downstream (validação, veto, desempate) sequer chega a ser testado contra a falha real, porque ela
nunca aparece no teste.

**Causa raiz:** o mock do produtor probabilístico (`generateDesiredCart`/chamada de LLM) devolve um
valor FIXO e hardcoded que já contém a resposta CORRETA — nesse caso, `_cart(item_a, item_ofertado)`
sempre incluindo o item certo. O teste então prova corretamente que "SE o LLM propuser o item certo,
o resto do pipeline aplica certo" — mas a pergunta que o cenário de produção realmente faz é "o LLM,
dada a MESMA ambiguidade textual (ex. 'pode ser a 600 ml então', sem dizer QUAL das duas variantes
de 600ml), escolhe o item certo?" — e essa pergunta nunca é feita, porque a resposta já vem
decidida pelo autor do teste, não pelo LLM. A guarda de segurança (N30, no caso) roda contra uma
entrada sempre-correta e nunca vê o caso adversarial que ela existe pra pegar.

**Como detectar antes de production:** ao escrever/revisar um mock de produtor de IA/LLM pra um
teste de "aceite ambíguo"/"desambiguação contextual", pergunte explicitamente: **"este mock pode
devolver o item ERRADO?"** Se a resposta for não — se o mock só tem UM valor possível e ele é
sempre o correto — o teste não cobre a classe de bug que o cenário existe pra prevenir, só cobre o
pipeline DEPOIS de a ambiguidade já ter sido resolvida por fora. Um teste honesto desse cenário
precisa (a) parametrizar o mock pra devolver o item ERRADO também, provando que a guarda downstream
reage corretamente aos DOIS casos, ou (b) rodar contra o LLM real (custoso, não-determinístico, mas
é o único jeito de medir a taxa real de acerto numa ambiguidade genuína) via smoke discriminante em
staging/produção controlada antes de declarar `[5-T]`.

**Solução aplicada:** não dá pra "consertar" o mock pra ficar honesto sem redesenhar o teste — a
correção real é (1) reconhecer que o smoke real em produção controlada é a ÚNICA prova válida desse
tipo de cenário, nunca o teste mockado sozinho; (2) quando o smoke real expõe a falha, a raiz pode
estar em qualquer ponto do pipeline — nesse caso a raiz NÃO era a guarda de segurança em si (ela
bloqueou corretamente o palpite errado do LLM, comportamento seguro), mas a AUSÊNCIA de um
mecanismo que, tendo já resolvido corretamente a identidade do item por uma via independente e
verificada (ex. o item que estava sendo genuinamente ofertado, com referência textual confirmada),
substitua o palpite errado do LLM por esse item já conhecido em vez de simplesmente recusar a
mutação inteira.

**Ref:** tiatendo, sessão 2026-08-27/28 — P0 do Codex, `tests/restaurant/test_casosABC20260827.py::
test_casoA2_aceite_da_oferta_apos_turno_lateral_adiciona_o_item`. O mock fixa
`desired=_cart(CARNE_ASSADA_TM, COCA_ORIGINAL_600)` pro turno "pode ser a 600 ml então" — sempre
inclui o item Original 600ml certo. Smoke real em PROD (`0.330.0`, tenant `sabor-do-teste`) com o
MESMO texto e a mesma oferta viva: o LLM real (GPT-4o) propôs o irmão errado (Coca-Cola Zero 600ml)
em vez do Original ofertado. `_contraditorioDaVariante` (N30) bloqueou corretamente o palpite
errado — mas o item certo (já resolvido com sucesso por `offeredItemLastroId`, com
`_turnReferencesOfferedItem` confirmando referência genuína) nunca foi aplicado, e o cliente recebeu
"não encontrei" em vez do item que realmente pediu. Diagnóstico via `grupo-de-discussao/053` (Codex)
+ `docs/PLANO.md` (tiatendo) da mesma data.
