## Escolher escopo pela OFERTA e reportar como se fosse demanda {#oferta-nao-e-demanda}

tags: oferta vs demanda, volume de busca, keyword planner, estoque, catalogo, feed, area descoberta, regiao sem cobertura, recorte geografico, bairro, escolha de escopo, campanha, google ads, midia paga, CPC, justificativa invertida

**Sintoma.** Uma proposta de estrutura de anúncios (grupo, campanha, recorte geográfico) é
justificada por um número que não é de procura: volume de estoque do cliente, quantidade de itens
no feed, ou "esta área está descoberta pela campanha que já roda". A proposta passa em todas as
checagens de forma e mesmo assim escolhe errado.

**Como reconhecer.** Pergunte de que lado da equação veio o número que sustenta a escolha. Se veio
do que o cliente TEM (estoque, catálogo, cobertura de outra campanha), é OFERTA. Demanda só aparece
medindo busca.

**Why.** Área descoberta costuma estar descoberta **porque não tem demanda** — o vazio é
consequência, não oportunidade. E estoque grande num bairro não implica que alguém pesquise por ele.
Medido em 2026-08-13, duas vezes no mesmo dia: 5 bairros escolhidos por estoque, e um deles com
**zero** busca no Keyword Planner apesar de 13 imóveis; e um recorte geográfico proposto por estar
descoberto que valia **4,1% da demanda** vizinha com clique **2× mais caro**.

**How to apply.** Antes de propor, rode `KeywordPlanIdeaService.generate_keyword_ideas` com o geo
real e ordene por `avg_monthly_searches`, lendo junto `high_top_of_page_bid_micros` — volume baixo
com clique caro é o pior par possível. **Demanda escolhe, estoque desempata**, e demanda sem estoque
vira clique em listagem vazia. Traga a tabela junto da recomendação.

**Corolário de processo.** Foi a segunda passada adversarial (subagente cego, §8 da skill
`auditoria-de-conta`) que pegou os dois casos — e no mesmo dia ela também acusou uma magnitude
**errada** ("27× menos" que medido virou 57% retido). Trate o revisor como levantador de hipótese:
o que ele aponta se mede, não se aceita nem se descarta.
