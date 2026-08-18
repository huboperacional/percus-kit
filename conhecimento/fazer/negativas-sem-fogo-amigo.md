## Negativar concorrentes em conta de mídia paga sem fogo amigo {#negativas-sem-fogo-amigo}

`tags: negativas concorrentes google ads palavra-chave conta campanha fogo amigo catalogo`

tags: lista de negativas, negativar concorrente, nível de conta, ampla de 2 palavras, marca ambígua, cruzar com catálogo do cliente, tráfego que deixou de acontecer, erro silencioso

**Quando.** Antes de subir qualquer lista de palavras negativas — em especial em **nível de conta**,
que vale pra todas as campanhas, inclusive as que ainda não existem. Erro aqui é silencioso: você
não vê o tráfego que deixou de acontecer.

### 1. Levante o catálogo real do cliente ANTES de escrever a lista

Nome de concorrente colide com nome de bairro, empreendimento, linha de produto. O cliente é a
fonte da verdade, não a sua intuição. No Paid Media dá pra extrair do próprio rastreamento:

```sql
SELECT DISTINCT regexp_replace(split_part(event_source_url,'?',1),
       '^https?://[^/]+/imovel/','') AS slug
FROM tracking.event_log
WHERE tenant_id = :t AND event_source_url LIKE '%/imovel/%'
  AND created_at >= now() - interval '60 days';
```

Sem tracking, sirva-se do sitemap ou de `landing_page_view` na API do Google Ads.

### 2. Rode uma guarda automática, não uma revisão de olho

Monte a lista de termos-núcleo do negócio e **aborte o script** se algum negativo de uma palavra
cair nela. De-olho não escala e falha justo quando a lista é longa:

```python
PROIBIDO = {"apartamento","terreno","condominio","casa","comercial","venda", ...}  # + bairros
viol = [t for t in TERMOS if PROIBIDO & set(t.lower().split())]
if viol: sys.exit(f"ABORTADO — colide com catálogo do cliente: {viol}")
```

### 3. Marca ambígua entra QUALIFICADA, em ampla de 2 palavras

Negativa **ampla exige TODOS os termos presentes**, em qualquer ordem. Isso é a ferramenta:

| Concorrente | ❌ errado | ✅ certo | Por quê |
|---|---|---|---|
| Imobiliária América | `américa` | `imobiliária américa` | bairro "Jardim América" tem imóvel anunciado |
| Imobiliária Terra | `terra` | `imobiliária terra` | genérico demais |
| Casa Dourada | `casa dourada` | `dourada` | contém "casa"; a palavra rara sozinha já isola |

A regra do meio-termo: **prefira a palavra RARA sozinha** a um par que carregue termo-núcleo.
`dourada` pega os mesmos resultados que `casa dourada` e não encosta em "casa".

### 4. Duas grafias, com e sem acento

Negativa **não casa variação** — nem plural, nem acento, nem erro de digitação. `imobiliaria` e
`imobiliária` são dois critérios. Vale pro par inteiro.

### 5. Confira o inverso: o que a lista ANTIGA já está bloqueando

Auditar o que existe costuma render mais que adicionar. Cruze as negativas atuais com o catálogo —
na UNI achei `[FRASE] central` matando "jardim central" e `[AMPLA] america` matando "jardim américa",
ambos com imóvel anunciado. E **não migre listas herdadas sem ler**: a campanha pausada da UNI
tinha 645 negativas que pareciam patrimônio e continham `apartamento`, `terreno`, `condominio`,
`casa` — aplicá-las teria desligado a conta.

**Ref:** Paid Media Automation, Imobiliária UNI, 2026-08-10. Mecânica de API:
[google-ads-negativa-conta-sharedset-tipo-proprio](../resolver/google-ads-negativa-conta-sharedset-tipo-proprio.md).
