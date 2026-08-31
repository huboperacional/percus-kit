## Parâmetro de anúncio gravado pelo CRM não pertence ao canal que você acha — case o HOST por sufixo, nunca por "contém" {#parametro-de-anuncio-do-crm-nao-e-do-canal-que-voce-acha}

`tags: atribuicao, hubspot, hsa_cam, lead ads, meta, google ads, utm, query string, host, sufixo, dominio, precedencia, falso positivo, R11, R23`

**Sintoma:** você descobre um parâmetro de campanha numa URL guardada pelo CRM (`hsa_cam`,
`hsa_grp`, `hsa_ad`, `hsa_acc` no HubSpot) numa população específica — por exemplo, só nos contatos
que vieram de **Meta Lead Ads** — e monta uma chave de atribuição nova em cima dele. Tudo mede 100%
naquela população. Semanas depois, a atribuição de **outro canal** (Google) muda sozinha: negócios
que casavam por click id passam a casar pela chave nova, apontando campanha errada.

**Causa raiz:** o prefixo é do **CRM**, não do canal. `hsa_*` são os parâmetros de *ads tracking* do
HubSpot, e a integração os cola em links de **qualquer** rede — Google Ads inclusive (`hsa_net=
adwords`). A sua medição só viu Meta porque você filtrou pela população do Lead Ads antes de olhar.
Quem lê a query string sem olhar o **host** captura os dois casos e não percebe.

**Como resolver:**

1. **O discriminador é o HOST, não o parâmetro.** No Lead Ads a URL está *dentro* do Facebook
   (`www.facebook.com/<page>/publishing_tools/?section=LEAD_ADS_FORMS&hsa_...`); num anúncio de
   Google a mesma família de parâmetros aparece no **domínio do cliente**.
2. **Case o host por SUFIXO DE RÓTULO, nunca por `in`/`contains`:**

   ```python
   host = netloc.split(":")[0].lower().rstrip(".")
   return host == "facebook.com" or host.endswith(".facebook.com")
   ```

   `"facebook.com" in netloc` aceita `facebook.com.exemplo-falso.net`. E fixar `www.` é a armadilha
   oposta: a Meta já trocou o host antes (`www.` → `m.` → `business.`), e a chave sumiria em
   silêncio na próxima troca.
3. **Escreva o teste do canal VIZINHO, não só o do seu.** O teste que importa não é "URL do Lead Ads
   extrai os quatro ids" — é *"URL do domínio do cliente com `hsa_cam` E `gclid` continua casando
   por click id"*. Sem ele, alguém "simplifica" o guard de host meses depois e quebra a atribuição
   do outro canal sem nenhum teste vermelho.
4. **Veja o teste reprovando** com o guard de host removido. Se ele passar dos dois jeitos, ele não
   está prendendo o host — está prendendo outra coisa.

**Por que não é só higiene:** a chave nova costuma entrar em posição ALTA da ordem de precedência
(identificador ganha de texto). Uma captura larga demais não degrada a atribuição — ela a
**sequestra**, e o número continua parecendo bom.

Achado em 2026-08-30 (Paid Media Automation, frente de atribuição de Meta Lead Ads). O código já
estava correto por acaso — o guard de host existia; o que faltava era o teste que o prende. Foi um
review cross-provider que levantou o risco, e ele era um **falso-positivo sobre o código com um
núcleo verdadeiro adjacente**: ver [[falso-positivo-do-conselho-pode-ter-nucleo-verdadeiro-ao-lado]].
