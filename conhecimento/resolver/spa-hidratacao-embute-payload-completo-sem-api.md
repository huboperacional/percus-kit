## Locator de SPA moderna costuma embutir o dataset INTEIRO no HTML de hidratação, sem precisar de API {#spa-hidratacao-embute-payload-completo-sem-api}

`tags: scraping, spa, next.js, nuxt, sveltekit, __NEXT_DATA__, __NUXT_DATA__, hidratacao, ssr, locator de unidades, engenharia reversa de api, waf, bloqueio de ip, json embutido, devalue, object literal js`

**Contexto:** coleta de ~1.000 leads de clínicas odontológicas (rede-a-rede) a partir dos sites das
próprias franquias. A primeira suposição, em toda rede nova, era "preciso achar a API por trás do
formulário de busca" — e em pelo menos 3 casos essa suposição era desnecessária: o site já entregava
tudo no primeiro request, sem nenhuma chamada adicional.

**O padrão, medido em 3 stacks diferentes no mesmo dia (2026-08-25):**
- **Next.js** (`Oral Unic`): `<script id="__NEXT_DATA__">` — JSON estrito, `json.loads` direto.
  Caminho: `props.pageProps.<chave>`.
- **SvelteKit** (`Odonto Excellence`): payload dentro de um `<script>` de hidratação chamando
  `__sveltekit_<hash>.resolve(1, () => [...])` — **não é JSON estrito** (chaves sem aspas, tipo
  `filial:"..."`), mas dá pra extrair com bracket-matching (contar `[`/`]` a partir da chave) e um
  regex simples `([{,])([a-zA-Z_]\w*):` → `\1"\2":` antes do `json.loads`. Foi a MAIOR fonte isolada
  da coleta: 851 unidades (Brasil + 4 países) numa página só, com endereço+CEP+RT+CRO+telefone —
  melhor schema que qualquer outra rede raspada.
- **Nuxt 3** (`Sorrifácil`): `<script id="__NUXT_DATA__">` existe, mas usa o formato `devalue`
  (array com tags tipo `["ShallowReactive", N]` e referências por índice) — **não** é um object
  literal simples, precisa de um parser de verdade (não vale a pena reimplementar pra 1 rede; foi
  deprioritizado).

**Por que vale checar isto ANTES de caçar o endpoint AJAX:** o caminho "engenharia reversa da API"
(achar o bundle JS, achar a URL base, achar os headers certos) custou 30-60 min por rede quando a
API existia de verdade (`Sorridents`, `Orthopride`, `Coife`). O caminho "grep por `__NEXT_DATA__` /
`__NUXT_DATA__` / `resolve(1, () => [`" custa 2 minutos e, quando acha, elimina TODO o problema de
paginação, rate-limit e bloqueio por IP — é 1 request só, sem WAF pra provocar.

**Como checar rápido:** `curl` a página de listagem, depois `grep -o -E "__NEXT_DATA__|__NUXT_DATA__|__sveltekit|application/json" arquivo.html`. Se achar, o dataset provavelmente já está ali; se não achar
nada e a página vier vazia/pequena, aí sim vale procurar API separada (ver
[[cnpj-cep-desempate-por-marca]] pra o que fazer depois de coletado).

**Armadilha gêmea, medida no mesmo dia:** um site (`OdontoCompany`) tem WAF que bloqueia por padrão de
tráfego — mesmo devagar (1 req/5s) o bloqueio reapareceu mais rápido a cada tentativa, sinal de score
acumulativo, não de rate simples. Não insista martelando: aceite o que já veio, espere o bloqueio
abrir sozinho (abriu 2x no mesmo dia, sem intervenção), e trate `403`/`erro_rede` como **não-terminal**
no harvester (retry na próxima rodada), nunca como resultado definitivo — senão a idempotência do
harvester marca a URL como "já tentada" para sempre sem nunca ter sido lida de verdade.
