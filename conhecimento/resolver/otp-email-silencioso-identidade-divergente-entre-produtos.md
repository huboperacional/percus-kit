## OTP "não chega" pode ser identidade divergente entre produtos, não falha de envio {#otp-email-silencioso-identidade-divergente-entre-produtos}

`tags: otp, auth-service, identity, email drift, early-202, anti-enumeration, multi-produto, multi-tenant, identity_id, onboarding em lote, telefone como chave, diagnostico, silent drop`

**Contexto:** um usuário reporta "o código por email não chega" num produto Percus. `POST
/otp/request` sempre devolve `202` — por design, a resposta é IDÊNTICA exista conta ou não
(anti-enumeração: revelar "conta não existe" via status/latência é o oráculo clássico de account
enumeration). Isso significa que **o status HTTP não prova nada** — nem sucesso nem falha de envio.

**Causa raiz:** a identidade é COMPARTILHADA entre produtos (`auth.identities`, chave
`identity_id`), mas o email/telefone que o USUÁRIO digita é o do produto específico
(`<produto>.users.email`, escopado por org/produto). Quando alguém é convidado a uma organização
NOVA com um email diferente do que a identidade compartilhada já tinha registrado (ex.: reaproveitou
o telefone de um vínculo anterior, mas o email mudou), a identidade fica com o email ANTIGO. O
usuário digita o email NOVO (o certo, do produto atual) — e a resolução de conta no envio de OTP
busca por aquele email exato, não acha, e **descarta silenciosamente** (early-202: o 202 já foi
mandado ANTES da resolução de conta rodar, em background — não dá pra recusar depois sem quebrar a
paridade de timing que a anti-enumeração exige).

**Sinal que distingue isto de "SMTP quebrado" (que afetaria todo mundo):** o MESMO usuário, no MESMO
produto, recebendo OTP por OUTRO canal (WhatsApp, resolvido por telefone) funciona normalmente. Só o
canal cujo identificador diverge falha — e só pra aquela pessoa específica.

**Diagnóstico (a ordem que funciona, sempre contra o dado real, nunca só o HTTP status):**
1. Achar o `identity_id` da pessoa no produto (join local `users.identity_id`).
2. Comparar `<produto>.users.email` (ou `.phone`) com `auth.identities.email`/`.phone` NO
   auth-service, pelo MESMO `identity_id` — não por string de email (é exatamente o que diverge).
3. Reproduzir o `POST /otp/request` de verdade e, **em vez de olhar o status (sempre 202)**, checar
   as tabelas de efeito colateral logo depois (`otp.codes`, `message_audit`/log de entrega) — uma
   linha nova apareceu, ou não? Zero linhas novas = descartado em silêncio.
4. Procurar no log da aplicação a razão explícita do drop (algo como `"no_account"` /
   `"dropped_no_account"`) — geralmente existe, só não é visível no response.

**Fix:** `UPDATE identities SET email = <email correto> WHERE id = <identity_id>` — checando ANTES
que o email novo não está em uso por OUTRA identidade (constraint única). Efeito colateral real: o
email ANTIGO para de autenticar em QUALQUER produto que compartilhe essa identidade — avaliar se a
pessoa ainda usa o antigo em outro lugar antes de trocar (uma tabela de "papéis por produto" vazia
pra essa identidade é sinal — não prova — de raio de alcance baixo).

**Padrão sistêmico, não caso isolado:** se uma org nova foi criada por convite em LOTE reaproveitando
telefones/identidades conhecidas (ex.: pessoas vindas de uma agência/vínculo anterior), o mesmo
desalinhamento tende a afetar VÁRIOS membros da mesma leva, não só quem reportou primeiro — vale
varrer todo mundo da org nova pelo mesmo padrão (`produto.email != identidade.email` pro mesmo
`identity_id`) em vez de corrigir um por um conforme reclamam.

**Ref:** Plexco Tasks s163 — Fabiula (org nova, convite em lote reaproveitando telefone de um vínculo
anterior). Achado o mesmo padrão em mais 4 pessoas da mesma leva, nenhuma tinha reportado ainda.
