## Deploy com migrations de ordens opostas no mesmo release {#deploy-com-migrations-de-ordens-opostas}

tags: deploy, alembic, migration, swarm, ordem

Quando um release traz **duas migrations cujas ordens seguras são opostas**, `alembic upgrade head`
aplica as duas de uma vez e viola uma delas. É preciso parar no meio.

Caso real (Plexco Tasks, 2026-09-07):

- **107** adiciona colunas que o **código novo escreve**. Tem de vir **ANTES** do rollout — senão
  todo `INSERT` quebra com "column does not exist".
- **108** remove prefixos do roteamento, e a **guarda que os substitui vive no código novo**. Tem de
  vir **DEPOIS** — antes abriria uma janela em que as mensagens caem no caminho errado e viram
  escrita indevida.

Sequência correta, em três passos:

```
alembic upgrade 107_<rev>     # só até a primeira
docker service update --image <nova>   # código vivo
alembic upgrade head          # aplica a segunda
```

Dois obstáculos que aparecem aqui e não em deploy normal:

1. **A migration só existe dentro da imagem nova.** Não dá para rodá-la a partir do container em
   execução (que tem o código velho). Construa a imagem, rode a migration num container **one-off**
   dela (`docker run --rm --network <rede> -e DATABASE_URL=... <imagem> alembic upgrade <rev>`) e só
   então faça o `service update`.
2. **Least-privilege: o usuário da app não é dono das tabelas.** `alembic` com a `DATABASE_URL` da
   aplicação falha com `InsufficientPrivilegeError: must be owner of table`. A credencial de
   migration é separada — no Plexco, `DATABASE_URL_MIGRATOR` no `.env` da VPS. A DDL é transacional,
   então a falha reverte sozinha e a versão não avança: não há dano, só um passo perdido.

**Escreva a ordem invertida na docstring da própria migration**, não só no commit — quem aplica lê o
arquivo, não o histórico. E diga por que a inversão é segura (no caso: o código novo é
retrocompatível, a guarda não dispara enquanto o dado velho existir).

Ver também [ordem-migration-antes-do-service-update](#ordem-migration-antes-do-service-update) para
o caso normal, de uma migration só.
