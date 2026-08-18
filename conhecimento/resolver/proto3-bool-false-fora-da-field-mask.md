## Google Ads API: setar bool para `False` não entra na field_mask automática — mutate dá sucesso e o campo não muda {#proto3-bool-false-fora-da-field-mask}

tags: google ads api, field_mask, protobuf_helpers, proto3, bool false, mutate silencioso, update_mask, network_settings

**Sintoma.** Você monta um update de campanha, seta um booleano para `False`, gera a máscara com
`protobuf_helpers.field_mask(None, obj._pb)`, chama o mutate — **retorna 200, sem erro** — e ao
reler pela API **o campo continua `True`**.

**Causa raiz.** Em proto3, `False` é o valor default do tipo e **não é serializado**. O helper
`field_mask(None, ...)` monta a máscara a partir dos campos presentes na serialização, então o
campo simplesmente **não entra na máscara** e o servidor não recebe ordem de mudar nada.

O engano é que a chamada é **parcialmente bem-sucedida**: no mesmo mutate, um enum com valor
não-default (ex.: `geo_target_type_setting.positive_geo_target_type = PRESENCE`) **é aplicado**
enquanto os bool **não são**. Você vê "sucesso", confere um campo, e conclui que tudo passou.

**Solução.** Máscara explícita sempre que o alvo for `False`, `0` ou `""`:

```python
camp.network_settings.target_google_search   = True    # preservar o que nao muda
camp.network_settings.target_search_network  = False
camp.network_settings.target_content_network = False
op.update_mask.paths.extend([
    "network_settings.target_google_search",
    "network_settings.target_search_network",
    "network_settings.target_content_network",
])
```

Cite na máscara também os irmãos da **mesma mensagem** que você quer preservar — mexer num
sub-campo de uma mensagem sem declarar os outros é pedir surpresa.

**E releia pela API depois do mutate.** O retorno de sucesso não prova aplicação; só a leitura
prova. Mesma família de `#gate-must-be-seen-failing`.

**Ref:** Paid Media Automation, Imobiliária UNI (customer 5977410135), 2026-08-10 — desligando
Rede de Display e Parceiros de Pesquisa. Descoberto só porque a conferência pós-mutate estava no
mesmo script.
