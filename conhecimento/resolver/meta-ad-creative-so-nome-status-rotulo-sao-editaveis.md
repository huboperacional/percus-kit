## Meta Ad Creative: só nome, status e rótulo são editáveis — o resto exige recriar {#meta-ad-creative-so-nome-status-rotulo-sao-editaveis}

tags: meta-ads, api, criativo, url_tags, mutacao, imutabilidade

**Sintoma.** Você quer corrigir um campo do criativo de um anúncio já ativo — no
caso real, `url_tags` (a etiqueta de rastreio) estava vazia ou com macro errada
(`{{campaign.name}}` em vez de `{{campaign.id}}`). Um `POST /{creative_id}` com o
campo novo parece a via óbvia.

**Por que morde.** A Marketing API recusa: `(#100) Invalid parameter`,
`error_subcode: 1815573`, `error_user_msg`: *"Especifique o nome, status ou
rótulos de anúncio associados para atualizar o criativo."* Ou seja: **`AdCreative`
só aceita `PATCH` em `name`, `status` e `adlabels`** — `url_tags`,
`object_story_spec`, `asset_feed_spec` são imutáveis pós-criação, mesmo que o
anúncio ainda esteja `ACTIVE` e o criativo tenha acabado de ser criado minutos
atrás.

**O caminho que funciona:** recriar o criativo (`POST /act_<id>/adcreatives`) com
o `object_story_spec`/`asset_feed_spec` **copiados byte a byte** do original +
o campo que você queria mudar, e depois repontar o anúncio pro `creative_id`
novo (`POST /{ad_id}` com `creative={"creative_id":"<novo>"}`). O criativo velho
fica órfão na conta (não precisa apagar) — só não é mais referenciado.

⚠️ **Antes de recriar, confira se o criativo é COMPARTILHADO** por mais de um
anúncio (query pelos ads da conta, casar por `creative.id`). Se for, recriar e
repontar só o anúncio que você queria muda a atribuição dos OUTROS que ainda
apontam pro original — pode ser o resultado certo ou uma duplicação de
manutenção, dependendo do caso; decida antes, não depois.

🔗 Ver também [[degrees-of-freedom-standard-enhancements-descontinuado-criativo-novo]] —
acontece no MESMO fluxo de recriação e barra o `POST` se você copiar o
`degrees_of_freedom_spec` inteiro do original sem tirar essa chave.

**Caso real** (Paid Media Automation, D4U, 2026-09-10). Frente de anúncios
reusou criativo existente na conta (não criou um novo) — e o módulo do produto
só grava `url_tags` no caminho de CRIAÇÃO de criativo, nunca em reuso. Resultado:
anúncio ativo, gastando, sem etiqueta de rastreio nenhuma. Tentei `PATCH` direto,
recusado; recriei com o mesmo `asset_feed_spec` (texto, imagens, formulário de
lead idênticos) + `url_tags` nova, repontei o anúncio, relido da API — confirmado.
