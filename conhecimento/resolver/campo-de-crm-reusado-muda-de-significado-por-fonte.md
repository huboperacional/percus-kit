## Campo de CRM reusado muda de significado por fonte — ler sempre o mesmo produz erro nos DOIS sentidos {#campo-de-crm-reusado-muda-de-significado-por-fonte}

tags: hubspot, crm, atribuicao, hs_analytics_source_data_1, hs_analytics_source_data_2, cobertura inflada, campanha fantasma, paid_social, paid_search, censo, amostra, facebook lead ads

**Sintoma.** A cobertura de atribuição parece ótima (87,9%) mas **nenhuma** campanha identificada
casa com campanha real do cliente; e uma plataforma inteira (o Meta) some do relatório, sempre
agrupada sob um nome estranho — no caso, uma campanha chamada `"Facebook"`.

**Causa raiz.** O campo lido não tem significado fixo. O HubSpot **reusa**
`hs_analytics_source_data_1` e `_2` com semântica diferente por `hs_analytics_source`:

```
PAID_SEARCH      data_1 = NOME DA CAMPANHA        data_2 = palavra-chave
PAID_SOCIAL      data_1 = "Facebook" (a REDE)     data_2 = NOME DA CAMPANHA   <- invertido!
OFFLINE          data_1 = CRM_UI / INTEGRATION    data_2 = id interno
ORGANIC_SEARCH   data_1 = "Unknown keywords(SSL)" data_2 = GOOGLE / BING
DIRECT_TRAFFIC   data_1 = URL ou id de formulario data_2 = vazio
OTHER_CAMPAIGNS  data_1 = "origem / meio"         SOCIAL/REFERRAL/EMAIL: rede, dominio, hs_email
```

Ler `data_1` como "o nome da campanha" em toda fonte custa **dois defeitos em direções opostas ao
mesmo tempo**, e é por isso que ele sobrevive tanto:

1. **Falso negativo** — a plataforma cujo nome mora no outro campo desaparece. Todo lead de
   `PAID_SOCIAL` casava com `"Facebook"`, que não existe em conta nenhuma, logo **nunca virava
   gasto nem CAC**.
2. **Falso positivo** — as fontes que não têm campanha nenhuma passam a "ter uma". `CRM_UI`
   (método de criação do contato) virava nome de campanha, e a cobertura do cabeçalho inflava.

Os dois se **cancelam no número agregado**: a cobertura parecia alta justamente porque o lixo
compensava a perda.

**Como confirmar (barato, e é o passo que decide).** Amostre `data_1` **e** `data_2` por fonte e
olhe o CONTEÚDO, não a taxa de preenchimento. Preenchimento alto nos dois campos não diz nada — no
D4U os dois marcavam 88-99% em quase toda fonte.

**Correção.** Mapa explícito fonte → campo, e **fonte ausente do mapa NÃO cai no campo padrão**:

```python
_CAMPO_DA_CAMPANHA_POR_FONTE = {
    "PAID_SEARCH": "hs_analytics_source_data_1",
    "PAID_SOCIAL": "hs_analytics_source_data_2",
}
fonte = (contato.get("source") or "").upper()
campo = _CAMPO_DA_CAMPANHA_POR_FONTE.get(fonte)
nome  = (contato.get(campo) or "").strip() if campo else ""   # sem campo -> sem campanha
```

Cair no ramo neutro é a mesma direção de default de [[else-que-afirma-a-causa-mais-comum-mente-no-caso-raro]]: uma
fonte nova do provedor degrada para "não identificada" (recuperável) em vez de virar um nome de
campanha inventado (afirmação errada que ninguém revisa).

**⚠️ Espere o número PIORAR, e avise antes.** Medido em produção, mesma janela, dois códigos:
cobertura **87,9% → 13,6%**, com **200 dos 233 "identificados" sendo falsos**. `OFFLINE` foi de
93,8% para **0,0%**. O controle que prova que nada real foi engolido é a fonte que já estava certa:
`PAID_SEARCH` ficou **91,7% intacto**. Sem esse controle, a queda é indistinguível de uma regressão.

**O ganho real não aparece onde você olha primeiro.** Nos negócios GANHOS o fix não mudou nada
(0 casamentos antes e depois), porque negócio ganho vem de contato antigo. Ele aparece no nível de
**lead**: **1.049 de 1.524** contatos de `PAID_SOCIAL` passaram a casar com campanha real. Meça nos
dois níveis antes de concluir que o conserto não pagou.

**Corolário sobre censo × amostra.** A primeira medição usou amostra de 3.000 (teto de paginação) e
deu 47,5% de `PAID_SEARCH`; o censo deu **39,2%**. A busca do HubSpot devolve `total` com
`limit: 1`, então o número exato custa **uma** chamada por recorte — use isso antes de publicar
percentual.

**Armadilha vizinha.** Se parte dos leads vem de formulário nativo da plataforma (Facebook Lead
Ads), eles **não passam pelo site**: não há URL, não há query string, e campo oculto de formulário
não tem de onde ler UTM nem parâmetro próprio. Nenhuma tarefa de "revisar os campos ocultos do
formulário" alcança esse grupo — a saída é a integração nativa ou o webhook da plataforma.
