## Histórico de alterações das plataformas de anúncio não é completo: Editor some no Google e o registro manual chega depois {#historico-de-plataforma-de-anuncios-nao-e-completo}

`tags: google ads, change_event, change_status, google ads editor, meta, activities, mutation_request, timeline, casamento, R23`

**Sintoma:** uma timeline montada do histórico de alterações diz "nada mudou" numa conta que foi
claramente alterada; ou o casamento entre a mudança da plataforma e o registro interno de mutações
dá zero.

**Medido** (Paid Media Automation, 2026-09-16/17, prod só leitura):
- **Google `change_event` não registra mudanças feitas pelo Google Ads Editor** (documentado pelo
  Google). 5 contas tinham `change_event` vazio e `change_status` com 1–283 itens alterados em lotes
  no mesmo microssegundo; 80 campanhas criadas de uma vez na D4U EUA também não apareciam.
  `change_status` diz o item e o instante, mas **sem autor, sem campo, sem valor antigo, só a última
  mudança por item**, e exige filtro de data e `LIMIT` (`CHANGE_DATE_RANGE_INFINITE`,
  `LIMIT_NOT_SPECIFIED`). Saída adotada: comparar o estado atual com uma foto guardada do item.
  O `resourceName` da linha do `change_status` não é o item — o item vem em `campaign`/`adGroup`/`campaignBudget`.
- **Meta `activities`:** texto de status vem no idioma do token (use os códigos de `extra_data.run_status`);
  não há e-mail do autor, só `actor_name`; orçamento vem aninhado em centavos; conjunto é
  `create_ad_set`/`update_ad_set_*`.
- **Registro interno de mutação feito por script grava `executed_at = now()` NO REGISTRO**, de 80 s
  a 2 h depois da mudança real; o feito pela tela grava `executed_at` antes da chamada à API. Janela
  única "até N min depois" casa zero. E os nomes reais de ação (`UPDATE_STATUS`,
  `CREATE_CAMPAIGN_STACK`, `CREATE_ADSET`, `UPDATE_CAMPAIGN`) não eram os que o plano supôs.

**Como evitar:** antes de desenhar a fonte, colete uma amostra real de 30 dias e rode o gate
"alguma mudança humana aparece só na fonte resumida?"; antes de casar com um registro interno,
meça a distância temporal real por tipo de proponente e liste as ações que existem no banco.
