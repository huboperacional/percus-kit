## Avançar cursor pelo "maior valor visto" numa página truncada sem ordenação explícita perde dado em silêncio {#avancar-cursor-por-maior-valor-visto-sem-ordenacao-explicita-perde-dado-em-silencio}

`tags: paginacao, cursor incremental, hubspot, api externa, ordenacao, watermark, alta marca, recursao, bisseção temporal, erro de ausencia, perda silenciosa`

**Sintoma:** um job de sincronização incremental fica preso pra sempre repetindo a mesma janela
(nunca avança o cursor) porque a leitura de uma sub-janela veio PARCIAL (estourou um teto de
paginação da API). A correção óbvia — "avança o cursor até o maior valor do campo de corte que foi
efetivamente visto nesta leitura parcial" — parece segura, mas **não é**, se a API não garante
ordenação pelo campo do filtro.

**Causa:** a maioria das APIs REST de busca pagina, por padrão, por uma ordem NÃO relacionada ao
filtro que você aplicou (ex.: a API de Search do HubSpot pagina por ORDEM DE CRIAÇÃO quando nenhum
`sorts` é pedido, mesmo filtrando por `lastmodifieddate`). Se uma janela tem mais resultados do que
o teto de paginação, o subconjunto retornado é arbitrário em relação ao campo do filtro — o "maior
valor visto" nesse subconjunto pode ser MENOR que o valor real de algum registro que ficou de fora
da página, só que criado antes dele. Avançar o cursor pra esse "maior visto" pula esse registro
PRA SEMPRE, silenciosamente — troca um bug inofensivo (trabalho repetido) por um pior (perda de
dado muda).

**Solução, em duas partes:**
1. **Pedir ordenação explícita pelo MESMO campo do filtro** (`sorts: [{propertyName: <campo>,
   direction: ASCENDING}]` no caso do HubSpot) — só assim o ponto de corte de uma página truncada
   vira uma fronteira confiável ("tudo com valor ≤ X já foi visto"). Verificar isso contra a API
   REAL antes de confiar (request com e sem `sorts`, comparar ordem e ids devolvidos) — não supor
   pela doc sozinha.
2. Numa recursão por bisseção temporal (janela grande demais → divide ao meio, processa cada
   metade), o cursor seguro NÃO é "o maior valor visto em toda a árvore" — é a **alta marca da
   folha incompleta mais ANTIGA** (mais à esquerda no tempo). Uma metade mais recente e
   COMPLETA nunca pode "cobrir" pra uma metade mais antiga e incompleta: se a esquerda ficou
   parcial, a marca da árvore inteira é a marca da esquerda, ponto — o que a direita achou depois é
   irrelevante pro corte de segurança. Provar essa invariante por indução (esquerda completa →
   marca vem da direita; esquerda parcial → marca é só da esquerda) e testar em pelo menos 3 níveis
   de profundidade antes de confiar.

**Ref:** Paid Media Automation, 2026-09-05 (convergência do bootstrap de contatos do HubSpot,
`fix/hubspot-convergencia-e-resolver-moeda`, 2 rodadas de revisão adversarial até fechar a
invariante certa).
