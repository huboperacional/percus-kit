## HubSpot para de devolver `calculationSpecification` em `/crm/v3/properties/deals` — a propriedade continua existindo, só a metadata que a liga ao stage sumiu {#hubspot-para-de-devolver-calculationspecification-propriedade-continua-existindo}

`tags: hubspot, api externa, calculationSpecification, propriedade calculada, hs_v2_date_entered, mudanca de api do terceiro, diagnostico errado, causa raiz, R23`

**Sintoma:** um recurso que depende de "descobrir qual propriedade calculada do HubSpot corresponde
a um `(pipelineId, stageId)`" — via `GET /crm/v3/properties/deals`, casando por
`calculationSpecification.pipelineStageId` — passa a devolver "não encontrado" pra TODOS os pares
conhecidos, mesmo pipelines/estágios que nunca mudaram. A tentação é concluir "alguém reorganizou o
pipeline no portal" e ir procurar reorganização que não existe.

**Como descartar a hipótese errada antes de gastar tempo:** liste os pipelines/estágios de verdade
(`GET /crm/v3/pipelines/{objeto}`) e confira se os ids/labels dos pares que "sumiram" ainda batem.
Se baterem — mesmos ids, mesmos rótulos —, a causa não é reorganização de portal.

**Causa raiz medida (D4U, 2026-09-01):** o HubSpot parou de devolver `calculationSpecification` em
**qualquer** propriedade do portal (0 de 555 propriedades de `deals`, incluindo as ~57
`hs_v2_date_entered_*` que continuam existindo com os MESMOS nomes de sempre). É mudança do lado
deles no shape da resposta de `/crm/v3/properties/deals` — a propriedade calculada em si nunca
deixou de existir, só a metadata que a ligava ao stage sumiu do endpoint de *listagem*.

**Diagnóstico, em 2 chamadas:**
```python
props = await client.get("/crm/v3/properties/deals")  # ou objeto equivalente
resultados = props.json()["results"]
com_spec = [p for p in resultados if p.get("calculationSpecification")]
print(len(com_spec), "de", len(resultados))  # se 0, é a API inteira, não seu portal
nomes = {p["name"] for p in resultados}
print(f"hs_v2_date_entered_{stage_id_alvo}" in nomes)  # confirma que o nome ainda existe
```

**Fix seguro:** fallback por NOME CONSTRUÍDO (`hs_v2_date_entered_<stageId>`), mas só quando o
`stageId` é **numérico** — quando é textual, o HubSpot historicamente muda o nome pra um sufixo
imprevisível (mangling documentado em outro achado da mesma frente, RF-9.2), então concatenar às
cegas reintroduziria esse bug antigo. E só aceite o nome construído se ele **existir de verdade** na
resposta desta mesma chamada — nunca assuma, sempre confira contra o dado real.

**Achado colateral que vale generalizar:** um fix que finalmente faz um degrau "indisponível há
muito tempo" voltar a produzir dado real pode expor, na hora, um SEGUNDO bug latente em código
downstream que nunca tinha sido exercitado com esse dado presente (aqui: uma estrutura sintética
criada quando "só existe reunião, nunca houve venda" tinha uma chave estrutural faltando —
`KeyError` no primeiro lead real que caiu nesse balde). Rode smoke em produção depois de CADA fix
numa cadeia, não só depois do "fix principal" — o segundo bug só aparece com o primeiro corrigido.

Irmãos: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]]
