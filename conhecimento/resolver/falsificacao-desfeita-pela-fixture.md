## Falsificação feita POR FORA do que a fixture reconstrói não falsifica nada {#falsificacao-desfeita-pela-fixture}

tags: falsificacao nao pega, teste continua verde, fixture recria schema, drop constraint psql,
alembic upgrade na fixture, mutante revertido

**Sintoma:** para conferir que um teste realmente pega a regressão, você quebra o alvo **no
ambiente** — dropa a constraint no banco com `psql`, apaga o arquivo, muda a linha na tabela — e o
teste continua **verde**. A conclusão tentadora é "o teste não presta".

**Causa raiz:** alguma fixture **reconstrói** aquilo antes do teste rodar. No caso medido, a
fixture de schema tinha escopo de módulo e fazia `zerarSchema` + `alembic upgrade head` a cada
rodada — recriando exatamente a constraint que eu tinha acabado de dropar por fora.

**Solução:** ataque a **fonte** do estado, não o estado. Se o schema vem da migration, a
falsificação é remover a linha **da migration**; se o dado vem de um seed, é o seed que muda.
Antes de concluir que um teste não pega, pergunte **quem constrói aquilo que você quebrou** — e
confirme lendo a fixture, não a intuição.

**Parente:** esta é a terceira forma de "falsificação que fica verde" registrada no mesmo dia. As
outras duas são #falsificacao-verde-porque-outra-camada-barrou (outra camada absorveu o efeito) e
#gather-nao-produz-corrida (a concorrência nunca aconteceu). O padrão comum: **falsificação verde
é informação sobre o TESTE, e vale investigar até saber qual das três é.**

**Ref:** Empresa Milionária, Fase B Task 6, 2026-08-14.
