## Agrupar ANTES de resolver não basta quando a resolução INFERE a identidade do nó {#resolucao-que-infere-identidade-exige-reagrupar}

tags: árvore, agrupamento, resolução, identidade, group_nested, finalize_nested_tree, lead ads, hsa_ad, hsa_grp, conjunto inferido, re-agrupamento, pureza, paid media

**Sintoma:** uma árvore/relatório agrupa registros por uma chave derivada do próprio registro
(função pura, sem I/O) e depois uma etapa de "finalização" resolve cada balde contra o banco. Um
requisito novo faz a resolução **descobrir** a identidade de um nível que o registro não trazia —
ex.: o anúncio (`hsa_ad`) casa e revela QUAL conjunto é o da linha (RF-6.1 do Lead Ads). Se a
finalização só "renomear" o balde pré-agrupado, dois registros que caíram no MESMO balde de
ausência (`("none", "(sem conjunto)")`) mas cujos anúncios inferem conjuntos DIFERENTES viram um
nó só com rótulo de um deles — número certo no total, atribuição errada no nível, sem erro nenhum.

**Causa raiz:** o agrupamento puro só pode usar o que está NO registro; a identidade inferida só
existe depois da resolução. Chave de agrupamento ≠ identidade final quando a resolução pode
mudá-la. Renomear o nó preserva a PARTIÇÃO antiga com rótulos novos — e a partição é que está
errada.

**Correção que funcionou (Paid Media, Task 7 do Marco B de Lead Ads, 2026-08-30):** a finalização
faz um **re-agrupamento pós-resolução**: para cada folha `(chave_conjunto, chave_anúncio, registros)`
ela calcula uma **identidade resolvida** hashable — `("pm", valor)` para texto do tracker,
`("res", uuid)` para conjunto casado ou inferido limpo, `("res_div", uuid, id_divergente)` para
inferido com `hsa_grp` que não casou (a divergência NÃO se dilui na fusão), `("nc", valor)` para id
não casado, `("none",)` para ausência — e monta os nós agrupando por ESSA identidade. Baldes
distintos convergem no mesmo nó quando resolvem igual, e o mesmo balde se divide quando resolve
diferente. O invariante "soma dos filhos == total do pai" continua valendo por construção (nenhum
registro muda de campanha, só de nó interno).

**Como reconhecer que você está neste caso:** a etapa de resolução tem um ramo em que ela devolve
algo que mudaria a chave de agrupamento se fosse conhecido antes ("o X daquele Y vira o X da
linha"). Se existir esse ramo, renomear não basta — re-agrupe.
