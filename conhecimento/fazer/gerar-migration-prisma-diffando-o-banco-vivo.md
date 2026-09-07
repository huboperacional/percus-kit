## Gerar migration do Prisma diffando o banco vivo, sem shadow database {#gerar-migration-prisma-diffando-o-banco-vivo}

`tags: prisma, migration, migrate diff, shadow database, postgres, docker, swarm, sql gerado, prisma 7`

**Origem:** CL_Liliflow, 2026-09-07. Máquina de dev sem Docker e Postgres de produção só alcançável
de dentro da VPS — `prisma migrate dev` não era opção.

**Quando usar.** Você mudou `schema.prisma` e precisa do `migration.sql` correspondente, mas não tem
banco local nem shadow database. Escrever o SQL à mão funciona para uma coluna e erra em silêncio
quando são três tabelas com FK e enum.

**Procedimento.** Compare o **banco real** com o schema alvo. O banco já está no estado da última
migration, então o diff é exatamente a migration que falta:

```sh
docker run --rm --network <rede> \
  -v /caminho/prisma:/newprisma -w /app \
  -e DATABASE_URL="$DBURL" \
  <imagem-do-app> \
  npx prisma migrate diff \
    --from-config-datasource \
    --to-schema /newprisma/schema.prisma \
    --script -o /newprisma/_diff.sql
```

Depois é só prefixar um cabeçalho explicando o **porquê** e salvar como
`prisma/migrations/<timestamp>_<nome>/migration.sql`.

**Detalhes que custam tempo:**

- **Prisma 7 renomeou as flags.** Não existe mais `--to-schema-datamodel` nem `--shadow-database-url`.
  São `--from-schema` / `--to-schema` / `--from-migrations` / `--from-config-datasource`.
- **Não monte volume por cima do workdir.** `-v /opt/app:/src -w /src` esconde o `node_modules` da
  imagem, o `npx` tenta baixar o Prisma da internet e falha com
  `Cannot read properties of null (reading 'edgesOut')`. Monte em caminho separado e aponte as flags.
- **`--from-migrations` exige shadow database; `--from-config-datasource` não.** É essa a razão de
  preferir o segundo.
- **Só serve enquanto o banco está em dia com as migrations.** Se houver migration local ainda não
  aplicada, o diff traz junto o que ela já cobre. Nesse caso aplique primeiro, depois diffe.
- **Ler o `DATABASE_URL` sem imprimi-lo:** com secret do Swarm, extraia dentro do próprio container
  e mantenha em variável de shell:
  ```sh
  DBURL=$(docker exec $WEBC sh -c "grep '^DATABASE_URL=' /run/secrets/<secret> | cut -d= -f2-")
  ```

**Cuidado com `CREATE INDEX` no SQL gerado.** `prisma migrate deploy` roda cada migration dentro de
uma transação, então `CONCURRENTLY` **não** é usável ali. Em tabela com escrita ativa e volume, o
índice comum segura um `SHARE lock` durante todo o build. Em tabela vazia é instantâneo — verifique
antes (`SELECT count(*)`) e **registre no cabeçalho da migration** qual era o caso, para quem
reaplicar num banco cheio saber que precisa construir o índice fora da transação.

**Ref:** `CL_Liliflow/app/prisma/migrations/20260907213500_add_contact_conversation_message/`.
