## Consumer novo "não consegue enviar OTP": audience nunca foi registrada no auth-service {#audience-nao-registrada-otp-falha}

`tags: otp, audience, invalid_audience, 422, audience not registered, onboarding consumer, novo produto, assert_audience_known, whatsapp nao envia, toast generico, versao do cliente, falso alarme, otp_require_existing_account, anti-relay-abuse, docker secret, database_url, run/secrets, ssh key sem passphrase`

**Sintoma:** um consumer (produto/LP/app) reporta "OTP não envia" — no browser aparece um toast
genérico tipo *"Não foi possível enviar o código. Tente novamente."* A tentação é achar que o cliente
está numa versão desatualizada do contrato, ou que é WhatsApp/GOWA caído.

**Causa raiz real (neste caso e provavelmente em qualquer consumer NOVO):** `POST /otp/request`
devolve **422 `error_code=invalid_audience` / "Audience not registered"** — a dependency
`assert_audience_known` (E1 strict) rejeita qualquer `audience` que não exista na tabela
`auth.audiences`. Um consumer pode ter o código 100% correto (payload certo, endpoint certo) e ainda
assim falhar porque **ninguém inseriu a linha da audience dele em produção** — geralmente porque o
`docker-compose.yml`/env do consumer já tinha o nome da audience (`AUTH_SERVICE_AUDIENCE=xxx-site`)
mas o onboarding do lado auth-service (registrar no banco) nunca aconteceu.

**Como confirmar rápido (sem adivinhar):** reproduza a chamada exata do consumer com `curl` direto
no endpoint público (`POST /otp/request` com o mesmo `channel`/`destination`/`audience`). Se vier
`422 invalid_audience`, achou — não precisa investigar GOWA, CORS, nem pedir log pro outro time.
Antes de pedir qualquer coisa a um consumer, cheque também se a chamada dele é **server-to-server**
(Next.js API route, etc.) — se for, CORS não pode ser a causa, mesmo que outro incidente de CORS
esteja rolando ao mesmo tempo.

**A parte que MAIS importa — não registre com o default:** `otp_require_existing_account` no schema
`Audience` é `true` por padrão (fail-secure, anti-relay-abuse, ligado ao incidente
`otp_abuse_incident_2026-06-09`). Se você registrar a audience nova SEM pensar nesse campo, o `422`
some — mas se o consumer não tiver um caminho de **provisionamento de identidade**
(`/internal/identities`), todo envio passa a ser **descartado em silêncio**
(`log.warning("otp.request.no_account", outcome="dropped_no_account")`) porque nenhuma conta
pré-existe pra aquele destino. Você troca um erro visível por um "sucesso" fake (o cliente recebe
`202` e nunca chega WhatsApp nenhum) — pior que o bug original, porque agora nem aparece erro.
**Antes de decidir o valor:** `grep -ri "internal/identities" <repo-do-consumer>` — se não achar nada,
é um gate aberto por design (ex.: LP com verificação de WhatsApp, sem sistema de conta) e
`otp_require_existing_account=false` é o valor certo. Se achar chamada de provisionamento, deixe
`true` (ou omita — é o default).

**Como aplicar em produção quando SSH/porta de DB não cooperam:** a porta pública do Postgres
(`161.97.129.138:5432`) pode não ser alcançável de uma sessão de dev, e a chave SSH "oficial" pode
estar com passphrase trancada. Nesse caso: (1) teste chaves alternativas mais antigas
(`~/.ssh/fm-ci-deploy`, `~/.ssh/id_rsa`) — `ssh-keygen -y -P "" -f <chave>` confirma sem passphrase
sem tocar no servidor, e elas costumam continuar válidas mesmo após uma rotação de credenciais nova;
(2) uma vez dentro da VPS, **não existe `DATABASE_URL` como env var solta no container** — em prod
o Pydantic Settings usa `secrets_dir="/run/secrets"`, então o valor real está no arquivo
`/run/secrets/database_url` **dentro do container** (leia esse arquivo, não `os.environ`); (3)
`docker cp` um script Python pro container e rode com `docker exec <cid> python /caminho/script.py`
— o container já tem `asyncpg` instalado, não precisa psql. O cache de audiences (TTL padrão 60s,
por-processo, sem invalidação cross-réplica quando você insere direto no banco em vez de usar o
`PUT /admin/audiences/{id}`) pode levar até 1 minuto pra pegar a linha nova — teste com `curl` de novo
antes de declarar sucesso, mas na prática às vezes já pega na primeira tentativa seguinte.

**Armadilha à parte (custou caro nesta sessão):** `export $(grep PADRAO .env | xargs)` quando o
`grep` não acha nada vira `export` **sozinho** — e `export` sem argumento **lista TODAS as env vars**
do shell, vazando qualquer API key que esteja no ambiente (não só as do `.env` do projeto) direto no
output/transcript. Sempre confira que a substituição de comando não ficou vazia antes de rodar
`export $(...)`, ou monte a variável com `grep ... | cut -d= -f2-` isolado, nunca em linha com
`export`.

**Ref:** auth-service → `ads4pros-site` (repo `ADS4PROS-Site`, LP `/lp1`/`/lp2`), 2026-07-31.
`docs/cross-product/2026-07-31-auth-para-ads4pros-otp-nao-envia-pedido-do-log-de-erro.md`. Schema:
`services/api/app/models/audience.py` (`otp_require_existing_account`); gate:
`services/api/app/modules/audiences/dependencies.py` (`assert_audience_known`); drop silencioso:
`services/api/app/modules/otp/router.py` (`outcome="dropped_no_account"`). Irmão: incidente de abuso
que criou o campo, `otp_abuse_incident_2026-06-09`.
