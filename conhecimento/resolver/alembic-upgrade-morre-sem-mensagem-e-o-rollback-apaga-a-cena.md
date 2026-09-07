## `alembic upgrade` morre com exit 1 e ZERO mensagem, e o rollback apaga a cena do crime {#alembic-upgrade-morre-sem-mensagem-e-o-rollback-apaga-a-cena}

`tags: alembic, migration, upgrade head, encoding, cp1252, PYTHONIOENCODING, windows, exit 1 sem traceback, transactional DDL, rollback, information_schema, pg_stat_activity, medir progresso, verde falso, medicao cega`

**Contexto:** `alembic upgrade head` contra Postgres real, no Windows, numa base vazia com
dezenas de migrations. O comando roda por minutos, aplica dezenas de revisões — e **morre com
`exit 1` e nenhuma mensagem de erro**. Sem traceback, sem linha de exceção, sem nada. O log
simplesmente para depois da última revisão aplicada.

**Causa raiz:** não é DDL. É o **logging do próprio Alembic** ao imprimir a mensagem da migration
seguinte num console `cp1252` (o default do Windows quando o stdout é redirecionado). Basta um
caractere fora do codepage no docstring da revisão. Duas coisas conspiram para esconder isso:

1. **O Alembic loga a mensagem da revisão ANTES de aplicá-la.** Então a última linha do log aponta
   para a revisão **anterior** à culpada — quem for diagnosticar abre o arquivo errado.
2. **`Will assume transactional DDL`:** o upgrade inteiro é UMA transação. O erro faz **rollback
   total**, o banco volta a zero tabelas e `alembic_version` some. A cena do crime fica
   **idêntica a "nunca rodou"**, e some junto a pista de onde parou.

Sintoma diagnóstico: o log vem com mojibake (`liquida??o`) e, em alguns pontos, com escapes
literais (`→`) — o logger às vezes **escapa** e às vezes **estoura**, e é justamente essa
inconsistência que faz a hipótese "é encoding" parecer refutada quando se olha só um trecho.

**Conserto:** `PYTHONIOENCODING=utf-8` (e `PYTHONUTF8=1`) antes do comando. Medido em 2026-09-07:
a mesma base que morria na 29ª de 59 passou a fechar **59/59, 68 tabelas**, sem mais nenhuma
mudança.

**⚠️ E o erro de MEDIÇÃO que vem junto, que custa mais que o defeito:** não use
`information_schema` de **outra conexão** para medir progresso de migration. DDL dentro de
transação aberta é **invisível de fora**, então `0 tabelas` significa *"não commitou ainda"*,
nunca *"não andou"* — e ler isso como "travou" leva a matar um processo que estava trabalhando.
Os instrumentos certos são dois:

- **o log** do próprio comando (mas lembre que ele está sempre uma revisão à frente do aplicado);
- **`pg_stat_activity`**, com `now() - state_change` e `wait_event_type`, para separar **LENTO** de
  **TRAVADO**: `wait_event_type = Client` com 0,2s parado é o **banco esperando a rede**, ou seja,
  está andando — o custo é o round-trip, não um deadlock.

**Vale além do Alembic:** qualquer processo longo cujo progresso só é visível de dentro da própria
transação. Medir de fora responde a pergunta errada com a cara de resposta certa.

Relacionado: [[get-content-sem-encoding-mojibake-51]], [[ps51-ascii-hooks]],
[[controle-positivo-que-nao-atravessa-o-ponto-fragil]].
