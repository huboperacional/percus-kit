## `papeis_empresa` tem RLS por usuário OU papel provado — `app.empresa_id` sozinho não basta {#papeis-empresa-tem-rls-por-usuario-ou-papel-provado-nao-so-empresa}

`tags: rls, postgres, papeis_empresa, set_config, seed, harness, adr-a10`

**Contexto:** Empresa Milionária, fixture de gate/seed contra Postgres real (janelas R20 de
03/09/2026 — gate da fatia 1 de produção e harness de screenshot da Task 11/12). Cenários que
inserem em `papeis_empresa` fora do fluxo HTTP normal (raw SQL de teste, ou uma sessão de
aplicação que só seta `app.empresa_id`) recebem `new row violates row-level security policy for
table "papeis_empresa"` mesmo com o `empresa_id` da linha batendo com o contexto.

**Por quê:** ao contrário da política padrão (`empresa_id = app.empresa_id`, que quase toda
tabela tenant-scoped usa), `papeis_empresa` tem policy PRÓPRIA (ADR A10):
`usuario_id = app.usuario_id OR (empresa_id = app.empresa_id AND app.papel_provado = 'true')`.
O primeiro ramo existe pro caso de bootstrap (login: "de qual empresa este usuário é" não pode
depender de já saber o `empresa_id`, ou vira circular); o segundo exige uma PROVA adicional
(`app.papel_provado`) que só `getPapelNaEmpresa` seta, e só depois de achar o papel do chamador —
então nenhum SELECT/INSERT solto fora desse caminho consegue satisfazer o segundo ramo sem
truque.

**O que resolve, ao seedar um `papeis_empresa` fora do fluxo normal:** setar
`SELECT set_config('app.usuario_id', '<id-do-usuario-da-linha>', false)` ANTES do INSERT — o
primeiro ramo ("o usuário concede o próprio papel", o caso de bootstrap) cobre exatamente esse
cenário. Isso vale tanto para a fixture de teste (`_cenario` em specs `-m postgres`) quanto para
qualquer sessão de aplicação real que precise gravar o PRIMEIRO papel de um usuário: ela também
precisa de `app.usuario_id`, não só `app.empresa_id` — e em produção isso já vem de
`aplicarContextoDoUsuario` em todo caminho autenticado (`app/core/rls.py`), então o gap só aparece
em conexão manual/fixture que não passou por lá.

**Ref:** sessão Empresa Milionária, 03/09/2026 — achado ao seedar OS de teste pra screenshot da
Task 11/12 da fatia 1 de produção; mesma família do achado documentado da sessão `-32 [07a044]`
sobre `pessoas`/`condicoes_pagamento_pj` (aquele exige só `app.empresa_id`; este exige também
`app.usuario_id`, achado NOVO e mais estreito).
