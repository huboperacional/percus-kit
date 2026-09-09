## Merge tag de unsubscribe do GHL é `{{email.unsubscribe_link}}`, não `{{unsubscribe_link}}` {#ghl-unsubscribe-merge-tag-tem-prefixo-email}

`tags: GoHighLevel, GHL, unsubscribe, merge tag, email, Broadcast, campanha nativa, CAN-SPAM, ADR-0006`

**Contexto:** Scraper-prospeccao, sessão 2026-09-03/04, email de campanha Epic Driving School
(60k+ contatos via GHL). ADR-0006 deste projeto (2026-07-16) já provava que a API de conversas do
GHL (`POST /conversations/messages`) deixa o link de unsubscribe vazio, e mandava usar a
campanha/broadcast nativa em vez disso. Ao escrever o HTML de campanha, o merge tag usado foi
`{{unsubscribe_link}}` — nome citado literalmente no texto do próprio ADR-0006.

**Causa raiz:** o texto do ADR-0006 descreve o comportamento observado **na API de conversas**,
que usa uma convenção de nome de merge tag diferente da do editor de campanha/Broadcast nativo. Só
foi possível confirmar o nome certo quando o operador colou o HTML que o **builder de email
nativo do GHL gera por padrão** (export de um template real da conta) — nele, o link de
unsubscribe usa `{{email.unsubscribe_link}}`, com o prefixo `email.`. O mesmo template também
mostrou `{{email.view_in_browser_url}}` (link "ver no navegador") com o mesmo padrão de prefixo.

**Sinal de alerta pra generalizar:** merge tags do GHL não têm um namespace único — o mesmo
conceito (unsubscribe, view-in-browser) pode ter nomes diferentes dependendo do **caminho de
envio** (API de conversas vs. Broadcast/Campaign nativo) ou da versão do builder. Nunca herdar o
nome de um merge tag de uma fonte que documenta um caminho diferente do que será usado de verdade
— pedir (ou exportar) um template real do canal exato de disparo antes de commitar o nome final.

**Solução:** usar `{{email.unsubscribe_link}}` (com prefixo `email.`) em HTML colado num bloco
"Custom HTML" de Broadcast/Campaign nativo do GHL. Ainda assim, **testar de verdade antes do
disparo em massa**: broadcast de teste pro próprio email, abrir o link de unsubscribe recebido e
confirmar que resolve pra uma URL real (não vazio) — o merge tag certo reduz o risco, não elimina
a necessidade do teste.

**Ref:** `data/leads-inbound/2026-09-03-epic-driving-school-email/` (Scraper-prospeccao),
`docs/adrs/0006-email-compliant-so-via-campanha-nativa-ghl.md`.
