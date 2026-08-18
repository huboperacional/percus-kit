## Postgres reclama de "column X does not exist" onde X é um VALOR seu (aspas comidas pelo ssh) {#ssh-heredoc-come-aspas}

`tags: ssh, heredoc, aspas simples, single quote, shell quoting, postgres, UndefinedColumnError, column does not exist, asyncpg, psycopg, parametro, erro que parece de schema`

**Origem:** tiatendo, 2026-07-31 — ~20 min perdidos com um erro que não parecia de aspas.

`ssh host 'python - <<"EOF" ... EOF'` — o corpo vai dentro de uma string **single-quoted** do shell
local. Toda aspa simples do Python/SQL é **comida**, e `status='active'` chega ao servidor como
`status=active`. O Postgres então reclama:

    UndefinedColumnError: column "active" does not exist

que não aponta pra aspas em lugar nenhum — parece erro de schema.

- **A regra:** dentro de `ssh '...'`, nunca use literal de string com aspa simples. Passe valores como
  **parâmetros** (`$1`, `$2` no asyncpg / `%s` no psycopg) ou use aspas duplas no Python.
- **Sintoma-assinatura:** o banco reclama de uma **coluna com o nome do seu valor**. Se o "nome da
  coluna" do erro é um dado seu, são as aspas.
