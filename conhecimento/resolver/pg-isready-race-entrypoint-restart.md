## Loop de "esperar Postgres ficar pronto" pode declarar sucesso durante o servidor TEMPORÁRIO do entrypoint oficial, e falhar segundos depois no restart {#pg-isready-race-entrypoint-restart}

`tags: postgres, pg_isready, docker entrypoint, initdb, restart, race condition, ephemeral postgres, no response, wait for ready, docker-entrypoint.sh`

**Contexto:** script de Postgres efêmero pra TDD (`scratchpad/dbTestsEphemeral.sh`, tiatendo),
usado por múltiplos subagents concorrentes na mesma sessão 2026-08-03.

**Sintoma:** `docker run` do Postgres reportado como `Up`, mas o script de espera desiste com
"no response" mesmo com retry de até 120s — e uma inspeção manual 10-20s depois mostra o mesmo
container perfeitamente saudável e aceitando conexões. Reproduzido ao vivo duas vezes na mesma
sessão (por dois subagents diferentes, independentemente).

**Causa raiz:** o `docker-entrypoint.sh` oficial da imagem Postgres, quando o volume de dados
nasce vazio, faz: (1) sobe um servidor TEMPORÁRIO (via unix socket) só pra rodar `initdb`/scripts
de init (ex. `CREATE DATABASE`), (2) **derruba esse servidor temporário**, (3) só então sobe o
servidor DEFINITIVO (TCP 0.0.0.0:5432). Um loop de espera que testa `pg_isready` e **quebra no
primeiro sucesso** pode pegar esse sucesso durante a fase (1) — aí a checagem seguinte (ou a
tentativa de conexão real da aplicação) cai exatamente na janela entre (2) e (3), onde NADA está
escutando, e reporta falha mesmo com o banco "logo ali" saudável segundos depois.

**Solução:** não trate o primeiro `pg_isready` bem-sucedido como definitivo — ele pode ser o
servidor temporário do próprio init. Depois do loop principal, adicione um **segundo loop de
confirmação curto** (ex. mais 10-15 tentativas de 1s) antes de declarar falha real; só desista se
a checagem falhar consistentemente por essa segunda janela também. Alternativa mais robusta:
aguardar uma marca no log do container (`docker logs | grep "database system is ready to accept
connections"` contada 2×, já que a mensagem aparece uma vez pro temporário e uma vez pro
definitivo) em vez de só `pg_isready`.

**Ref:** sessão tiatendo 2026-08-03, `scratchpad/dbTestsEphemeral.sh` — fix aplicado ao script
(retry de confirmação de 15s após o loop principal de 120s). Tema irmão (setup de Postgres
efêmero em geral, não esta race específica): `#pg-efemero-testes-destrutivos`.
