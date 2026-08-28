## Harness genérico de isolamento por id só prova o que a resposta REALMENTE expõe — endpoint agregado (soma/série) quebra o padrão copiado {#harness-de-listagem-generico-so-prova-o-que-a-resposta-expoe}

`tags: multi-tenant, isolamento, harness generico, teste de vazamento, agregado, dre, relatorio, endpoint de leitura, controle da listagem, falso positivo, asserção sempre falha, fastapi, sqlalchemy`

**Contexto:** projeto multi-tenant com um harness genérico de isolamento (dicionário
`(rota) → (recurso PRÓPRIO, recurso VIZINHO)`, um par de fixture por rota de listagem) que
ataca toda rota GET de coleção: chama pela empresa A, exige que o id do recurso PRÓPRIO apareça
no corpo (senão a lista vazia passaria em qualquer asserção de ausência) e que o id do VIZINHO
nunca apareça. Funciona bem para listagens simples (título, pessoa, categoria — cada linha
carrega o próprio id). Uma rota nova de relatório agregado (soma por categoria, série diária por
data) foi registrada nesse mesmo dicionário copiando o par de uma rota vizinha que já funcionava
("copiei o padrão que já tinha passado no aging").

**Causa raiz:** o par (próprio, vizinho) só prova alguma coisa se o id escolhido REALMENTE
aparece no corpo da resposta em algum caso. Um endpoint agregado (DRE por categoria, resultado
por centro de custo) some com o id da linha original (título) — a resposta só tem
`categoria_id`/`categoria_nome` + totais. Um agregado mais raso ainda (série diária de
movimento: `data`/`entradas`/`saidas`) não expõe id NENHUM. Nos dois casos, o par de UUID
copiado do "irmão mais próximo" nunca aparece no corpo — nem com isolamento correto, nem sem
ele. A asserção de presença ("o próprio tem que aparecer") **falha sempre**, e o motivo do
"falso vermelho" não é óbvio: parece que o endpoint está quebrado quando na verdade é o
harness testando a coisa errada.

**Diagnóstico:** antes de registrar uma rota nova no dicionário de par, pergunte "esse id
REALMENTE aparece no JSON de resposta, em algum cenário?" — não "essa rota lê a mesma tabela
que a rota vizinha lê". Duas rotas que leem `Titulo` podem ter contratos de resposta
completamente diferentes (uma lista título, outra soma por categoria).

**Fix, dois casos:**
1. **Agregado que expõe OUTRO id** (categoria, centro de custo): use o id que a resposta
   realmente devolve, não o id da tabela de origem. Se o cenário compartilhado não linka a
   linha de origem a esse id (ex.: `tituloA` sem `categoriaId`), dê a ela essa referência no
   cenário — reusando a fixture do outro id que já existe lá (`categoriaA`), sem criar
   fixture nova.
2. **Agregado que não expõe id nenhum** (série por data, soma pura): não force uma entrada no
   dicionário genérico. Crie uma segunda estrutura, ao lado da primeira, mapeando a rota para
   um teste DEDICADO — que prova isolamento por VALOR agregado (um recurso grande e
   reconhecível só na empresa vizinha não pode aparecer no total da empresa própria), não por
   id. O loop principal do harness aceita as duas estruturas; a exigência de "toda rota tem
   que estar registrada em algum lugar" continua um `assert` rígido — só o MECANISMO de prova
   muda por rota, nunca a obrigação de provar.

**Ref:** Empresa Milionária, backend de `/relatorio` (2026-08-27/28) — Tasks 4/6/8 do plano
`docs/superpowers/plans/2026-08-27-relatorio-pj-backend.md`. Achado ao vivo: uma sessão registrou
o par errado (`tituloA`/`tituloB`) pras 3 rotas restantes generalizando do que funcionou na
Task 2 (aging, que é listagem simples); a sessão que executou as tasks bateu no falso vermelho e
corrigiu pra `categoriaA`/`categoriaB` (DRE), `centroCustoA`/`centroCustoB` (centro de custo) e
`LISTAGENS_SEM_ID_NO_CORPO` com teste dedicado (fluxo de caixa, sem id nenhum).
