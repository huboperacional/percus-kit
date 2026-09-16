## `utm_campaign` escrito à mão no template é copiado junto com a campanha — case pelo ID do clique, não pelo nome {#utm-campaign-de-template-copiado-atribui-a-campanha-errada}

`tags: atribuicao, utm_campaign, gad_campaignid, hsa_cam, google ads, tracking template, campanha renomeada, sem conta, crm, R23`

**Sintoma:** no relatório de vendas, leads, reuniões e negócios de campanhas que EXISTEM caem em
"sem conta de anúncio", ou aparecem na conta errada. A primeira hipótese é "a campanha foi
renomeada e o nome antigo ficou no lead".

**Causa real medida** (Paid Media Automation, D4U, 2026-09-16): nenhuma renomeação — o
`change_event` do Google tinha 124 mudanças de campanha em 30 dias e **zero** de nome. O
`utm_campaign` vinha **digitado à mão no tracking template de cada campanha**
(`utm_campaign=[Área: EUA]…Trabalhar`). Duplicar a campanha copia o template, e a cópia
"[Área: Brasil]…Trabalhar" seguiu mandando o nome da original. Resultado: **556 de 777** leads
Paid Search atribuídos à campanha errada (muitas vezes em outra conta) e 199 em "sem conta".

**O dado certo já chegava:** 99,5% das visitas com `gclid` traziam `gad_campaignid` (posto pelo
próprio Google, não passa por template) e `hsa_cam` (template do HubSpot, `{campaignid}`).

**Correção:**
1. Ao resolver o clique contra as sessões, devolva o **ID** da landing — ordem Google:
   `gad_campaignid` > `hsa_cam` > `pm_campaign`; Meta: `hsa_cam` > `pm_campaign` — e só use
   `utm_campaign` quando nenhum ID veio. Case por `platform_campaign_id`.
2. Leia `hsa_*` da `first_url` também quando a URL é do SITE e declara `hsa_net`; guarde a rede.
   `hsa_cam` de rede Google cede ao gclid casado; o do Lead Ads da Meta (host facebook.com) não.
3. Campanha que nunca gastou não está na tabela de campanhas se a coleta só grava quem tem
   métrica — carregue as pausadas, senão o ID casa com nada.
4. Qualquer aviso derivado do nome ("campanhas que não existem em conta nenhuma") tem de ir pelo
   ID também: no D4U caiu de 92 nomes para 8 IDs realmente ausentes.

**Como distinguir rápido:** compare, nas sessões, `utm_campaign` com o nome atual da campanha dona
do `gad_campaignid`. Bateu em só 14% (3.837 de 27.358) → template copiado, não renomeação.
Histórico de nomes não resolveria nada.

**Armadilha:** o sync de contatos do CRM é incremental e a URL crua não é persistida — contatos
antigos só ganham os `hsa_*` quando forem modificados ou re-sincronizados.
