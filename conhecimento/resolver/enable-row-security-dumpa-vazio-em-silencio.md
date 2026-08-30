## `pg_dump --enable-row-security` sob FORCE RLS não erra — dumpa VAZIO, e o backup "funciona" {#enable-row-security-dumpa-vazio-em-silencio}

`tags: postgres, pg_dump, backup, rls, force row level security, enable-row-security, bypassrls, dado perdido, R23`

**Sintoma:** o `pg_dump` com a credencial da aplicação falha sob `FORCE ROW LEVEL SECURITY`
("query would be affected by row-level security policy"), alguém acha a flag
`--enable-row-security` na documentação, o comando passa a **sair com exit 0** — e a rotina de
backup fica verde. Meses depois, o restore devolve um banco com schema perfeito e **zero linhas**
nas tabelas isoladas.

**Causa raiz:** `--enable-row-security` não desliga a política — ela faz o dump **obedecer** à
política. Uma sessão de `pg_dump` não tem o contexto de tenant (o GUC que a aplicação seta por
transação), então a política *fail-closed* nega todas as linhas — e negar linha não é erro:
o `COPY` devolve zero linhas com sucesso. Medido em produção real (Empresa Milionária,
2026-08-30): `em_user` sem a flag → erro; com a flag → exit 0 e 0 linhas de dado; role
superusuário → exit 0 e os dados todos. **O modo de falha com a flag é o pior dos três**, porque
é indistinguível de backup são até o dia do restore.

**Solução:**

1. **Backup lógico roda como role com `BYPASSRLS`** (ou o superusuário do container), nunca como
   a credencial da aplicação — a aplicação foi deliberadamente construída para não enxergar nada
   sem contexto, e o backup precisa de tudo.
2. **Full dump (schema + dados), não `--data-only`** — o data-only sob RLS ainda esbarra em
   avisos de ordenação, e o full é o que o restore de desastre quer de qualquer jeito.
3. **Guarda de conteúdo no backup:** o job confere que o dump tem mais que o boilerplate — um
   `grep -c` de linhas de `COPY` com dado, ou tamanho mínimo por tabela âncora. Exit 0 do
   `pg_dump` não prova que há dado dentro (este verbete é a prova).

**Custo se ignorar:** a perda só aparece no dia em que o backup é a única cópia — retenção
fiscal de 5 anos apostada num arquivo que sempre esteve vazio.

Relacionado: [[force-rls-quebra-o-pg-dump-do-proprio-dono]],
[[rls-sem-force-dono-ignora-politica]].
