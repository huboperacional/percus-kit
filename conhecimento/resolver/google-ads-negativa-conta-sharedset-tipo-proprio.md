## Negativa de palavra-chave em NÍVEL DE CONTA no Google Ads: erro diz "shared set does not exist" e a lista existe {#google-ads-negativa-conta-sharedset-tipo-proprio}

tags: google ads, negative keyword, account level, shared set, customer negative criterion, NEGATIVE_KEYWORD_SHARED_SET_DOES_NOT_EXIST, sharedsettype, api

**Sintoma.** Você cria um `SharedSet` de negativas, popula com `SharedCriterion`, e ao anexar na
conta via `CustomerNegativeCriterionService` toma:

```
criterion_error: NEGATIVE_KEYWORD_SHARED_SET_DOES_NOT_EXIST
"Cannot create a negative keyword list criterion with a shared set that does not exist."
```

A lista **está lá** — dá pra consultar por GAQL, tem os termos dentro, o `resource_name` é válido.

**Causa raiz.** O enum `SharedSetTypeEnum` tem **dois** tipos de lista de negativa, e eles não são
intercambiáveis:

| Tipo | Para quê |
|---|---|
| `NEGATIVE_KEYWORDS` | lista compartilhada **de campanha** (anexa via `CampaignSharedSet`) |
| `ACCOUNT_LEVEL_NEGATIVE_KEYWORDS` | lista **de conta** (anexa via `CustomerNegativeCriterion`) |

Criar com o tipo errado **não falha**, e popular com `SharedCriterion` **também não falha**. Só o
terceiro passo quebra — e a mensagem culpa a existência da lista em vez do tipo dela, porque o
serviço de conta só enxerga listas do tipo de conta.

**Solução.**

```python
op.create.type_ = client.enums.SharedSetTypeEnum.ACCOUNT_LEVEL_NEGATIVE_KEYWORDS
...
cnc_op.create.negative_keyword_list.shared_set = shared_set_rn   # mensagem, NÃO string
```

`negative_keyword_list` é um `NegativeKeywordListInfo` — atribuir a string direto dá
`TypeError: expected NegativeKeywordListInfo got str`. Tem que ir no campo `.shared_set`.

**Verificação — o contador da lista MENTE.** Em `shared_set`, os campos `member_count` e
`reference_count` voltam **0** mesmo com a lista populada e anexada e funcionando. Não use eles
como prova. Prove por dois caminhos:

```sql
-- 1. a lista está anexada?  deve aparecer type = NEGATIVE_KEYWORD_LIST
SELECT customer_negative_criterion.id, customer_negative_criterion.type,
       customer_negative_criterion.negative_keyword_list.shared_set
FROM customer_negative_criterion

-- 2. os termos estão dentro?  conte as linhas
SELECT shared_criterion.keyword.text, shared_criterion.keyword.match_type
FROM shared_criterion WHERE shared_set.type = 'ACCOUNT_LEVEL_NEGATIVE_KEYWORDS'
```

**Ref:** Paid Media Automation, Imobiliária UNI (customer 5977410135), 2026-08-10 — lista
"NEG CONTA - Concorrentes", 32 termos. Perdi um ciclo criando e apagando lista com o tipo errado.
Procedimento de montar a lista sem fogo amigo: [negativas-sem-fogo-amigo](../fazer/negativas-sem-fogo-amigo.md).
