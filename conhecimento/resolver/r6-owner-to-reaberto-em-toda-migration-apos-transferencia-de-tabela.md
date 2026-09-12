## R6 "migration sem OWNER TO" reabre em toda migration depois de uma transferência de owner em massa {#r6-owner-to-reaberto-em-toda-migration-apos-transferencia-de-tabela}

`tags: R6, OWNER TO, migration, alembic, banco isolado, ADR, mi_user, superuser fallback, review recorrente, rule table, AGENTS.md, CLAUDE.md`

**Contexto:** projeto que em algum momento transferiu TODAS as tabelas `public` pra um role de
aplicação (ex. `mi_user`) pra alembic conseguir `ALTER`/`ADD COLUMN` sem fallback de superuser
(padrão comum quando o superuser não fica exposto em produção). A regra R6 do canon Percus lista
"migration sem `OWNER TO mi_user`" como gatilho automático de review — correto para migrations que
**criam tabela nova** (o owner default de uma tabela nova é quem rodou o `CREATE TABLE`, que pode
não ser o role de app dependendo de como o pipeline de deploy roda). Mas `ADD COLUMN`/`CREATE
INDEX`/`ALTER COLUMN` numa tabela **já pertencente** ao role de app **não muda o owner** — Postgres
não reseta ownership nessas operações.

**O que aconteceu:** a mesma migration (já sem `ALTER OWNER`, com o argumento técnico correto
documentado em comentário inline) teve o MESMO achado de R11 levantado **4 vezes** ao longo de um
único ciclo de revisão de plano — cada vez reconhecendo que o argumento estava certo, cada vez
sugerindo adicionar o comando mesmo assim "por segurança"/"custo zero". Um comentário inline na
migration não é uma fonte de verdade que um revisor FUTURO (humano ou LLM) consulta antes de aplicar
a regra — ele lê a REGRA (a linha R6 da tabela em `AGENTS.md`/canon), não o histórico de decisões de
uma migration específica.

**Por que "adicionar o `ALTER OWNER` mesmo assim, é de graça" não resolve o problema real:** o
comando em si é inofensivo, mas não é isso que está quebrado. O que está quebrado é que a REGRA
(a linha R6 na tabela que o reviewer consulta) não tem uma exceção documentada — então toda migration
futura do mesmo tipo, revisada por qualquer pessoa/ferramenta que não tenha o contexto desta
conversa específica, vai reabrir a mesma pergunta. Adicionar o comando resolve UM caso; não resolve
a régua que continua marcando todo caso seguinte.

**Fix estrutural (não o comando, a regra):**
1. Escrever um ADR (`docs/adrs/NNNN-...md`) documentando a exceção: "migrations que só fazem `ADD
   COLUMN`/`CREATE INDEX`/`ALTER COLUMN` em tabela já transferida em `<data>` não precisam
   re-declarar `OWNER TO`" — com o motivo técnico e o escopo exato da exceção (não cobre `CREATE
   TABLE`, que continua precisando).
2. **Editar a própria linha da regra** na tabela que o reviewer consulta (`AGENTS.md` do projeto, ou
   onde quer que R6 esteja tabulada) apontando pro ADR. Sem este passo, o ADR fica "ilhado" — existe,
   mas ninguém que consulta a regra sabe que ele existe, e o ciclo reabre pela 5ª vez. Foi
   precisamente isso que uma rodada de review adicional (depois do ADR já escrito) apontou: o ADR
   sozinho não fecha o loop, só documentar a exceção onde a regra vive fecha.
3. Se o projeto tem uma fonte canônica cross-projeto (ex. um arquivo de regras compartilhado por
   múltiplos projetos) além da cópia local, decidir explicitamente se a exceção é local (só este
   projeto) ou deveria propagar pra lá também — não assumir silenciosamente nenhum dos dois. Editar
   um arquivo compartilhado entre projetos não deveria acontecer como efeito colateral de resolver
   um achado de review de UM projeto.

**Ref:** Família Milionária, ADR-0007
(`docs/adrs/0007-migrations-nao-redeclaram-owner-em-tabelas-ja-transferidas.md`) + `AGENTS.md`
linha R6 atualizada, fechando um achado reaberto nas rodadas 5, 6, 9 e 12 de uma mesma revisão de
plano (`2026-09-12-mesada-recorrente-fatia2a.md`).
