## Raspando email de contato: JSON-LD é onde mora, e o MX "válido" aceita registro A {#scrape-email-jsonld-mx}

`tags: scrape, scraping, email, contato, bs4, BeautifulSoup, get_text, script, json-ld, ld+json, schema.org, LocalBusiness, mx, email-validator, check_deliverability, dnspython, bounce, prospeccao`

**Sintoma:** (a) o scrape acha bem menos email do que o site realmente publica; (b) emails "validados" quicam mesmo assim.

**Causa-raiz (a):** `BeautifulSoup.get_text()` **exclui `<script>`** — comportamento correto dele, e por isso passa batido em review ("script não vaza pro get_text, tá certo"). Só que negócio local publica o email em **`<script type="application/ld+json">`** (`schema.org/LocalBusiness`), que é **onde o negócio declara os próprios dados** — a fonte mais confiável que existe. Um scan de `mailto:` + texto é **100% cego** a ela.

**Causa-raiz (b):** `email_validator.validate_email(addr, check_deliverability=True)` **não exige MX** — cai pro **registro A/AAAA** (RFC 5321 "implicit MX"). Em scrape isso vira **no-op**: o email vencedor é quase sempre `@` o domínio do próprio site, e você só chegou ali **porque acabou de baixar HTML daquele host** → o A **provadamente existe** → passa sempre. Site de template que imprime `info@ownsite.com` sem nunca configurar email tem A e não tem MX.

**Solução:**
1. Ler as 3 fontes em ordem de confiança: **`mailto:` → `ld+json` → texto**. No JSON-LD, **recursar** (schema.org aninha em `@graph`) e **podar subárvores de terceiros** por `@type` (`Person`, `Review`, `Rating`) e por chave (`author`, `review`, `publisher`) — senão você grava o email **do avaliador** como contato do lead, e pior: por ser fonte de alta confiança, ele aborta o crawl antes do mailbox real.
2. Exigir **MX real**: `dns.resolver.resolve(domain, "MX")` (dnspython já vem com email-validator; DNS é bloqueante → thread + cache por domínio).
3. **Ranquear e percorrer até um passar no MX** — checar só o melhor e desistir joga fora email bom (loja publica um role sem MX **e** o gmail que funciona).
4. **Nunca chutar** (`info@<domínio>` inventado) = bounce garantido.

**Gotchas:** filtro de lixo por **substring** derruba lead real (`info@sentrytinting.com` casa "sentry"; `businessname@` casa "name@") → casar **domínio com fronteira de ponto** e **local-part exato**. Bloquear um lixo faz o ranking **cair no próximo, que também pode ser lixo**. O rodapé credita a agência que fez o site e o `info@` dela **vence o mailbox da loja** no ranking role-first → sinal pra auditar: **domínio próprio (não-free) que não bate com o host do site**. Enumeração de blocklist **não fecha** — o backstop é **review humano** do relatório.

**Ref:** Scraper-prospeccao `services/api/app/integrations/email_harvest.py`, commit `7ea8e4f` (2026-07-15): JSON-LD sozinho rendeu **+22 emails (100→122)** em 310 leads. Memórias `reference_jsonld_is_where_business_email_lives`, `reference_email_validator_mx_aceita_registro_A`.
