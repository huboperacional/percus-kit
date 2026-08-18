## API e SPA no MESMO host: com a API morta o proxy cai no catch-all e devolve HTML com 200 {#spa-catchall-mascara-api-morta}

tags: Traefik, proxy reverso, SPA, catch-all, priority, roteamento, healthcheck, 200 com HTML, API morta, falso positivo, smoke test

Host único servindo API e SPA: no Traefik, router da API com `priority=100` casando `PathPrefix(/api) || Path(/health) || ...`, e router do frontend com `priority=1` casando só `Host(x)` — catch-all, como toda SPA precisa.

Medido: **quando a task da API está fora do ar, o proxy derruba o router dela** (sem endpoint saudável não há rota) **e a requisição cai no catch-all**. O `/health` passou a devolver **o HTML da SPA com HTTP 200**. Qualquer healthcheck que olhe só o status code **aprova uma API morta**.

**Solução:** exclua os paths da API da regra do catch-all — não confie só na prioridade, que resolve o caso normal e não o caso de falha:
`Host(``x``) && !PathPrefix(``/api``) && !Path(``/health``) && !Path(``/openapi.json``) && !PathPrefix(``/docs``)`
API fora do ar passa a dar **404 honesto**. Aplique no label vivo **e** no arquivo versionado — só no vivo, o próximo deploy desfaz.

**Prove derrubando de verdade:** escale a API a zero e exija `/health` = **404** com `grep -c 'id="root"'` no corpo = **0** (o HTML não pode vazar), enquanto `/` segue servindo a SPA; depois restaure. Verde sozinho não prova nada aqui, porque **o verde é exatamente o que o bug produzia**.

**Complemento, não substituto:** healthcheck de deploy deve assertar o **JSON** (`"status":"ok"` + versão esperada), nunca só `HTTP 200`. E note que 502 seria melhor notícia que isto: 502 grita; HTML-com-200 **mente em voz baixa**.

**Vizinhos, e a diferença entre eles:**
[#gate-marcador-antes-de-validar](gate-marcador-antes-de-validar.md) — lá o gate se autoaprova; aqui é a **topologia de roteamento** que fabrica um 200 falso, sem ninguém ter errado no código.

**Ref:** Micro Investors / tenant tiatendo, 2026-08-16 — provado nos dois sentidos com a API escalada a 0 e restaurada.
