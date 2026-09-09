## O erro aparece num nível e a causa está em outro (CBO do Meta) {#erro-num-nivel-causa-em-outro-meta-cbo}

`tags: meta ads, graph api, cbo, abo, bid_strategy, orçamento, mensagem de erro, error_user_msg, subcode, depuração, api de anúncios`

**Sintoma:** criar campanha no Meta com `daily_budget` (isto é, CBO) funciona; criar o **conjunto**
dentro dela falha com `"Invalid parameter"`. Testei quatro variações do conjunto — com e sem
`bid_strategy`, com `destination_type`, com `promoted_object` — e **as quatro deram a mesma
mensagem**, porque nenhuma mexia no lugar certo.

**Causa:** a campanha foi criada **sem `bid_strategy`**. O Meta assume então uma estratégia que
exige limite de lance, e quem paga o pato é o conjunto:

```
code=100  subcode=1815857  message="Invalid parameter"
error_user_title="O valor do lance é necessário para a estratégia de lance fornecida"
error_user_msg="...você precisa fornecer o campo bid_amount..."
```

**Regra:** em **CBO, tudo que é de leilão mora na campanha** — `daily_budget` **e** `bid_strategy`.
O conjunto carrega só segmentação, otimização e cobrança. Em **ABO** é o inverso: orçamento e
estratégia no conjunto, e a campanha precisa declarar explicitamente

```
code=100  subcode=4834011
error_user_title="É necessário especificar True ou False no campo is_adset_budget_sharing_enabled"
```

ou seja, ABO **não é "só omitir o orçamento da campanha"**.

**A lição que vale além do Meta:** `message` veio como `"Invalid parameter"` nas duas situações —
inútil. O que resolveu foi ler **`error_user_title`, `error_user_msg`, `error_subcode` e
`blame_field_specs`**. Toda integração com a Graph API deve logar esses quatro campos; sem eles a
depuração vira adivinhação, e a tentação é começar a mexer no objeto onde o erro apareceu — que
aqui é justamente o objeto errado.

**Como aplicar:** ao depurar erro de API em estrutura hierárquica (campanha → conjunto → anúncio),
antes de variar o filho, **verifique o que o pai declarou**. Um campo faltando no pai vira erro
genérico no filho, e a mensagem não aponta para cima.
