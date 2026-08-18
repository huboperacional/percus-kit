## Suíte verde e boot morto: a versão da lib na IMAGEM não é a da sua máquina {#skew-lib-imagem-vs-local}

`tags: skew de versao, imagem vs local, boot morto, suite verde, FastAPI, response_model, status_code 204, from __future__ import annotations, ForwardRef, docker, swarm, container removido, smoke docker run`

**Sintoma:** 818 testes passam local, o review aprova, e a task **morre no boot em produção**. O log
do serviço não ajuda porque o container falhou e o swarm já o removeu.

**Causa raiz:** skew de versão entre a imagem e o ambiente de dev. No caso real: FastAPI **0.115.6**
na imagem × **0.136.1** local. Uma rota `status_code=204` com handler anotado `-> None` (num módulo
com `from __future__ import annotations`, que transforma a anotação em `ForwardRef` → `NoneType`) é
lida pela 0.115 como *tem response_model* e o **import aborta**; a 0.136 normaliza `None` para "sem
modelo" e passa. Mesmo código, veredito oposto.

**Solução (imediata):** declarar explicitamente o que as duas versões entendem igual — ali,
`response_model=None` no decorator.

**Solução (da classe):** um passo de CI que instala o `requirements.txt` **da imagem** num venv e faz
só `python -c "import app.main"`. Isso pega a família inteira, não a instância.

**Armadilha da guarda:** o teste óbvio — inspecionar `route.response_model` no app montado — é
**teatro** no ambiente local, porque a lib nova normaliza e a asserção passa mesmo sem o fix (provado
por mutação). A guarda tem que ler o **fonte** (AST, não regex: um revisor listou 7 estilos de
declaração que regex perde e que quebram igual).

**O que salvou:** `fail-closed` no entrypoint (migração falha ⇒ não sobe) **pareado** com
`failure_action: rollback` no swarm — a task nova morreu, o pin anterior voltou sozinho e o tráfego
não caiu. Fail-closed sem rollback pareado seria crash-loop.

**Ref:** Paid Media Automation (2026-07-26), commit `b50a4e9`. Parente de
[#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md) e
[#build-dir-compartilhado-tag-nova](build-dir-compartilhado-tag-nova.md).
