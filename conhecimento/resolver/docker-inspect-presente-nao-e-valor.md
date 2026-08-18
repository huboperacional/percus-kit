## `docker service inspect | grep VAR` confirma que a CHAVE existe, não que o VALOR é não-vazio — integração ficou meses no-op silencioso {#docker-inspect-presente-nao-e-valor}

`tags: env var vazia, docker service inspect, PRESENT check enganoso, integracao nunca funcionou, secret vazio em producao, docker-compose interpolacao vazia, verificacao superficial de config`

**Sintoma:** primeira aceitação real de um fluxo (proposta de venda) que deveria criar um contato
num CRM externo (GoHighLevel) via API não gerou nada do lado do CRM — sem erro visível, sem
exceção, o app continuou funcionando normalmente (a integração é best-effort/no-op silencioso por
design). Um check anterior, feito em sessão passada, tinha "confirmado" as credenciais como
`PRESENT` via `docker service inspect ... | grep VAR`.

**Causa raiz:** o `.env` da VPS tinha as chaves (`GHL_PIT_TOKEN=`, `GHL_LOCATION_ID=`) mas com
**valor vazio** — nunca foram de fato preenchidas, só declaradas. `docker-compose.yml` interpolava
`${GHL_PIT_TOKEN:-}`, que aceita string vazia sem erro. O código de integração checava
`if (!token || !locationId) return { skipped: true }` — um guard correto, mas que faz a ausência de
config parecer indistinguível de "tudo certo, só não tem trabalho a fazer" nos logs. O check de
verificação usado antes (`docker service inspect --format '...Env...' | grep VAR | sed
's/=.*/=PRESENT/'`) tem um bug sutil: `sed 's/=.*/=PRESENT/'` casa `VAR=` (valor vazio) do mesmo
jeito que casa `VAR=algumacoisa` — `.*` aceita zero caracteres. O resultado impresso
(`GHL_PIT_TOKEN=PRESENT`) é **sempre verdadeiro que a chave existe**, nunca informa se tem valor.
Isso mascarou o problema por meses (nenhuma proposta aceita gerou contato no CRM desde que a
integração foi implementada).

**Solução:** pra confirmar que uma env var tem **valor**, não só existe como chave, use
`docker exec <container> env | grep VAR` (mostra `VAR=valorreal`, inclusive se vazio — `VAR=` sem
nada depois é visualmente óbvio) — ou, se for secret que não pode aparecer em texto, comparar
`length` (`docker exec <container> node -e "console.log(process.env.VAR?.length)"`). Nunca confiar
num `sed`/regex que substitui o valor por um marcador fixo tipo `PRESENT` sem primeiro checar se o
valor capturado tinha conteúdo — esse padrão de "check de presença" é enganoso por construção.

**Trade-off:** nenhum — o check com `docker exec ... env` é tão rápido quanto o `service inspect`,
só que correto. Vale substituir esse padrão em qualquer runbook/memória que ainda recomende
`service inspect` pra validar secrets.

**Ref:** ADS4PROS-Site, sessão 2026-08-05 (incidente GHL — proposta Tiffany Driving School aceita
sem gerar contato no CRM; ver `HANDOFF.md` §0-C).
