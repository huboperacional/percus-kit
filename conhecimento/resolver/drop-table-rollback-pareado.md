## Depois de um `DROP TABLE`, "voltar a tag" não é rollback {#drop-table-rollback-pareado}

`tags: rollback, drop table, migração, alembic, deploy, swarm, docker service update, container saudável, 500 no request, gate negativo, pg_dump`

**Sintoma:** você reverte a imagem para o pin anterior, o `docker service ls` mostra `1/1`, o
healthcheck passa — e o cliente vê 500 numa tela específica.

**Causa:** a imagem anterior lê a tabela que a migração dropou. Isso **não quebra no boot** (não é
erro de import, não é conexão) e **não quebra a suíte** (que usa banco fake). Só falha no request.

**O que fazer:**

1. Escreva o rollback **pareado** no `docker-compose.swarm.yml`, junto do pin — é o arquivo que quem
   reverte abre: `alembic downgrade <rev-anterior>` **ANTES** do `docker service update`.
2. `pg_dump -t <tabela>` **antes** de aplicar, e diga no docstring que o downgrade recria a
   **estrutura**, não as linhas. Prometer rollback completo é mentira silenciosa.
3. **Gate negativo na imagem**: `grep -r` provando que o nome da tabela **não está** no artefato.
   Verifique que ele **reprova a imagem anterior** — gate que passa em tudo não prova nada.
4. Ordem de deploy: **código primeiro** (que já não lê), migração depois.

Aplicado em 2026-07-29 (Paid Media, fatia 0028).
