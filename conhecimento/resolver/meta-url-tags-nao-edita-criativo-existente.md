## A Meta não deixa editar `url_tags` de um criativo existente: etiquetar anúncio no ar custa a publicação {#meta-url-tags-nao-edita-criativo-existente}

`tags: meta ads, marketing api, url_tags, utm, pm_, criativo, imutavel, engajamento, R23`

**Sintoma:** `POST /v22.0/<creative_id>` com `{ "url_tags": "..." }` devolve **HTTP 400 "Invalid
parameter"**, sem `error_user_msg`. Medido em 18/09/2026 em 12 criativos de uma conta (`act_…0781`):
12 de 12 recusados, nenhum alterado — o campo é imutável depois de criado.

**O que funciona:** criar um criativo NOVO (mesmo `object_story_spec` + `url_tags`) e reapontar o
anúncio com `POST /<ad_id> {creative:{creative_id}}`.

**O custo que ninguém avisa, e que decide se vale a pena:** criativo novo é **publicação nova** —
curtidas, comentários e compartilhamentos do anúncio voltam a zero, e o aprendizado reinicia. Meça
ANTES de propor: `GET /<ad_id>/insights?fields=impressions,actions&date_preset=maximum`. Num caso
real eram 22.843 impressões e 4.126 engajamentos, e o operador escolheu deixar os anúncios em paz.

**Três saídas, em ordem de custo:**
1. anúncio ainda **sem entrega** (0 impressão) → trocar o criativo é de graça, faça;
2. anúncio **com entrega** e a etiqueta é indispensável → criativo novo com `object_story_id` do post
   existente + `url_tags`: mantém a publicação e o engajamento, mas perde as variações de título/texto
   do `asset_feed_spec`;
3. anúncio com entrega e a etiqueta pode esperar → não mexa; coloque a etiqueta nos próximos.

**Duas armadilhas ao recriar o criativo (as duas dão 400 genérico):**
- copiar o `object_story_spec` **lido** manda `image_url` **e** `image_hash` juntos, e a criação
  recusa o par — monte `video_data`/`link_data` campo a campo;
- `degrees_of_freedom_spec.creative_features_spec.standard_enhancements` foi descontinuado na
  CRIAÇÃO (a leitura ainda devolve): copiá-lo dá *"o recurso de inclusão do campo de aprimoramentos
  padrão foi descontinuado; defina recursos individuais"*.

**Onde a etiqueta não serve pra nada:** anúncio de **formulário instantâneo** (destino `fb.me`). O
clique não vai a um site, então `url_tags` não viaja; a atribuição desses leads vem dos campos
nativos do Lead Ads. Contar esses anúncios como "sem UTM" infla o problema — num inventário real
eram ~76 de ~90.
