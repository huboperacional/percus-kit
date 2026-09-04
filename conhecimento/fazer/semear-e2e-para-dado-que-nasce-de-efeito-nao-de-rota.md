## Semear um teste E2E/R1 para dado que nasce de EFEITO, não de rota {#semear-e2e-para-dado-que-nasce-de-efeito-nao-de-rota}

`tags: E2E, R1, seed, semeadura, teste, efeito colateral, notificação, job agendado, SQL direto, TDD`

**Quando:** você precisa provar uma TELA de leitura (inbox, timeline, feed de eventos) contra
banco real, mas a linha que ela lê **não nasce de uma ação de usuário com rota própria** — é
efeito colateral de OUTRO fluxo (ex.: uma notificação criada quando A aprova algo de B) ou de um
job agendado sem endpoint HTTP (ex.: um cron que escala cobrança).

**Passos:**
1. **Resista a reimplementar o efeito/job dentro do teste.** Rodar o job de verdade no spec prova
   o JOB de novo (provavelmente já coberto pela suíte padrão) — não é isso que a TELA precisa que
   se prove.
2. **Pergunte o que a tela realmente lê**: quase sempre é uma tabela simples, filtrada por
   tenant/destinatário. Semeie ESSA linha diretamente — por SQL (via o mesmo canal de bootstrap
   que o harness já usa pra dados de setup, ex. `docker exec ... psql`) ou por chamada direta ao
   caso de uso em Python/backend, fora do fluxo HTTP.
3. **Um helper pequeno e reusável**, não um script solto por spec: parametrize por env var o que
   muda por sessão (nome do container, credencial), e faça a função levantar erro claro se a env
   var faltar — em vez de falhar tarde com um erro de conexão opaco.
4. **Prove a ESCRITA que o USUÁRIO controla** (aqui: marcar como lida), não a criação — o ciclo
   `semear (SQL) → F5 → [ação do usuário] → F5` ainda é o ciclo do critério de pronto, só que o
   "criar" vira "semear" porque o produto não oferece um "criar" pra essa entidade.
5. **Declare a ressalva na marca de rastreamento**, se o efeito tem VARIANTES não exercidas (ex.:
   dois tipos de notificação, você só semeou um) — subir a marca pro nível máximo baseado em
   testar só um caminho é o mesmo erro que "chamar não é exibir" já documentou.

**Armadilhas:** conectar como o role de aplicação (RLS ligada) pra semear direto tende a falhar
com "new row violates row-level security policy" — se a RLS já está provada em outro teste, semeie
como superuser só para ESTE propósito de apoio; não é onde você mede RLS de novo.

**Ref:** Empresa Milionária, sessão `empresa-milionaria-80` (2026-09-03/04) —
`tests/r1/notificacoes.spec.ts` + `tests/r1/helpers/sqlR1.ts` (commit `6637379`); notificação
nasce de `AprovarTitulo`/`RejeitarTitulo` ou do job `CobrarAprovadoresDePendencias`, nenhum dos
dois com rota de criação direta.
