## Migração de UI+API pra novo domínio: cookie dinâmico por Host não basta, a base da API também {#migracao-dominio-cookie-e-api-dinamicos}

`tags: dominio migracao cookie host api base-url dinamico frontend cors`

tags: migração domínio, cutover, cookie domain, cross-site, SameSite lax, registrable domain, const API, coexistência, dual-host, huboperacional, ads4pros, 302 vs 301

**Contexto:** migrar uma UI static (`gestao.ads4pros.com`) + sua API (`api.ads4pros.com`) pra outro domínio registrável (`*.huboperacional.com.br`), mantendo o domínio antigo vivo durante a transição (coexistência + rollback barato). O cookie foi feito dinâmico por Host, mas no host NOVO o login "entrava" e os dados davam 401.

**Causa raiz:** cookie dinâmico por Host resolve só METADE. O front tinha `const API` **hardcoded** pro domínio antigo. Como o MESMO bundle serve os dois hosts, o host novo chamava a API antiga **cross-site** (registrable domain diferente) → com `SameSite=lax` o cookie não vai em fetch/XHR cross-site → 401. E hardcodar (`sed`) pro domínio novo quebraria o host ANTIGO pelo mesmo motivo, invertido.

**Solução:** a base da API no front também tem que ser **dinâmica por Host** (espelho do cookie): `const API = location.hostname.endsWith('novo.com') ? 'https://api.novo.com' : 'https://api.antigo.com'`. Cada host chama a API do seu próprio domínio registrável → cookie same-site → os dois convivem. **Regra geral: num cutover de domínio, cookie-domain E api-base precisam ser dinâmicos por Host, juntos.** Além disso: expor a MESMA API também no domínio novo (Host extra no Traefik, não segundo deploy); cutover final com **302, não 301** (301 é cacheado permanente pelo browser → "remover o redirect" não pega quem já cacheou; 302 mantém rollback real).

**Ref:** migração Painel Gestão 2026-07-14; `docs/superpowers/specs/2026-07-14-migracao-gestao-huboperacional-design.md` §5 (furo-1, achado na review do Painel que o conselho tinha perdido).
