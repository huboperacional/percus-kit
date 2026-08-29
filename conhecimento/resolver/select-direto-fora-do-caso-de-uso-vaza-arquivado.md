## SELECT direto fora do caso de uso de listagem repete o filtro de arquivado, ou vaza {#select-direto-fora-do-caso-de-uso-vaza-arquivado}

`tags: FR-037, listagem, filtro, caso de uso, ADR-0003, situacao, arquivado, vazamento, review cross-provider, R23`

**Sintoma:** uma consulta nova que lê a mesma tabela que já tem um caso de uso de listagem
estabelecido (ex.: `ListarTitulos`) devolve linha com situação `arquivado`/`rejeitado`, mesmo o
produto tendo uma regra explícita de que essas situações "somem" de toda listagem, busca,
relatório e soma (FR-037 neste projeto). O teste da consulta NOVA passa, porque quem escreveu o
teste testou o caso feliz e esqueceu de plantar um título arquivado.

**Causa raiz:** o filtro `situacao NOT IN (arquivadas)` mora dentro do caso de uso de listagem
estabelecido (`ListarTitulos.executar`, por ADR-0003 — regra de negócio não mora no handler nem
se copia por consumidor). Uma consulta nova que faz `select(Titulo).where(...)` DIRETO, sem
passar por esse caso de uso — porque a pergunta é ligeiramente diferente ("os 5 mais recentes",
"agrupado por grupo de parcelamento") e reusar o caso de uso pareceria forçado — reimplementa o
`where` do zero, e é fácil esquecer justamente a condição que não aparece no caminho feliz.

**Medido no Empresa Milionária (2026-08-27, Task D6):** `query_handler_pj.py` tem 15 funções de
consulta; 9 delas reusam `ListarTitulos` (herdam o filtro de graça) e 6 fazem SELECT direto
porque a agregação não cabe no caso de uso de listagem (agrupar por dia, por categoria, os N mais
recentes). De uma sessão IRMÃ que leu o código antes do commit: `_queryUltimos` (os 5 títulos
mais recentes, `ORDER BY criado_em DESC LIMIT 5`) era a ÚNICA das 6 sem o filtro de arquivado —
um título arquivado aparecia na resposta do WhatsApp como se fosse ativo.

**A prova que fecha o achado, não só o conserta:** escrever o teste, reverter o `import`/filtro
de propósito, rodar RED (a asserção de exclusão falha e mostra o título arquivado no texto da
resposta), só então reaplicar o filtro e rodar GREEN. Sem o RED, "escrevi o teste e ele passa" não
distingue "o filtro funciona" de "o teste não exercita o caminho que falha".

**Como generalizar:** ao adicionar uma consulta nova sobre uma tabela que já tem regra de
"situação que não deve aparecer" (arquivado, soft-deleted, cancelado), perguntar explicitamente
"esta consulta reusa o caso de uso de listagem, ou repete o `where`?" — e se repete, o filtro de
exclusão é o primeiro candidato a faltar, porque é a condição que só aparece quando alguém planta
dado na situação errada no teste.

Achado relacionado: [[guarda-herdada-pode-exigir-o-defeito]].
