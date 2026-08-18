## Revision id de migration Alembic estoura `alembic_version.version_num VARCHAR(32)` — health check standalone pega ANTES do cutover {#alembic-revision-id-varchar32}

`tags: alembic, migration, revision id, varchar32, StringDataRightTruncation, health check standalone, crash-loop, entrypoint fatal, deploy gate`

**Sintoma:** container novo sobe, roda `alembic upgrade head` no entrypoint, e morre com
`sqlalchemy.exc.DataError: (psycopg2.errors.StringDataRightTruncation) value too long for type
character varying(32)` no `UPDATE alembic_version SET version_num='<revision>' WHERE ...`. O
container nunca fica `healthy`, então nunca chega perto de receber tráfego real — mas SÓ porque
havia um health check standalone rodando ANTES do `docker service update` do cutover. Sem esse
passo, o `docker service update` teria trocado o serviço em produção pra uma imagem que crash-loopa
no boot.

**Causa raiz:** o Alembic cria `alembic_version.version_num` como `VARCHAR(32)` por padrão (não é
configurável sem migração própria da tabela). Um nome de arquivo de migration descritivo demais
(`0036_event_log_google_ads_dispatches.py`, `revision = "0036_event_log_google_ads_dispatches"`,
36 caracteres) estoura o teto — e nada no `alembic revision`/`alembic upgrade` local avisa disso
antes de bater no banco real, porque testes contra Postgres efêmero recém-criado (sem histórico de
migrations anteriores) não necessariamente exercitam o `UPDATE` final se o teste só confere o shape
da tabela, não o fluxo completo do alembic runner.

**Solução:** manter todo `revision`/nome de arquivo de migration ≤32 caracteres — ex.:
`0036_gads_dispatches_col` (24 chars) em vez do nome descritivo completo. Se já commitou com um
nome longo e ele NUNCA chegou a aplicar de verdade em nenhum ambiente (confirmável: erro apareceu
na primeira tentativa, banco de dados single-environment, sem staging separado), é seguro renomear
o arquivo + a string `revision` livremente — o Alembic usa o CONTEÚDO do arquivo pra montar a cadeia
(`down_revision`), não o nome do arquivo; renomear não quebra nada desde que a string antiga nunca
tenha sido persistida em `alembic_version` de verdade. Confirme isso lendo o log do container que
falhou: se o erro veio do `UPDATE ... SET version_num=...` (não do `INSERT`/estado inicial), o
Postgres é transacional em DDL — a migration inteira (incluindo o `ALTER TABLE` que rodou antes)
sofreu ROLLBACK junto com o `UPDATE` que falhou, sem deixar rastro.

**Por que isso não quebrou em sessões anteriores deste mesmo projeto:** todas as migrations
anteriores (`0001` a `0035`) por acaso ficaram ≤32 chars — o teto nunca foi testado até uma
migration com nome mais longo aparecer. Não é uma regra nova do projeto, é um limite estrutural do
Alembic que sempre esteve lá, invisível até bater nele.

**Trade-off:** nenhum — o nome curto ainda é descritivo o suficiente (o docstring da migration no
topo do arquivo carrega o contexto completo; o nome do arquivo só precisa ser único e legível o
bastante pra `alembic history` fazer sentido).

**Ref:** Paid Media Automation, sessão 2026-08-05/06 (Google Ads multi-conta, Fatia 5 — migration
`0036`, pego pelo health check standalone rodado com a `DATABASE_URL` de produção ANTES do
`docker service update` de cutover; ver commits `a21ab757`/`5641cae9`).
