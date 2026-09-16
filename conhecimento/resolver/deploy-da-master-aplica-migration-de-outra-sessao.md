## Deploy a partir da master aplica a migration de OUTRA sessão quando o entrypoint roda `alembic upgrade head` {#deploy-da-master-aplica-migration-de-outra-sessao}

`tags: deploy, alembic, entrypoint, migration, sessoes concorrentes, worktree compartilhado, rollback pareado, R23`

**Sintoma:** você vai subir uma correção pequena sua e builda a imagem a partir da `master`. A
imagem sobe e o entrypoint (`alembic upgrade head`, fail-closed) aplica em produção uma migration
que outra sessão commitou horas antes — trabalho em andamento, que ninguém decidiu levar ao ar.

**Medido** (Paid Media Automation, 2026-09-16): a sessão do relatório mensal commitou a
`0051_relatorio_mensal` na `master`; a sessão do DRE disparou build+deploy do tracking a partir do
HEAD. Percebido com o build em andamento; o script na VPS foi morto antes do
`docker service update` — nada aplicado. O script tinha trocado `vm.overcommit_memory` para 1
durante o build e ficou assim: restaurar para 2 à mão.

**Consequência se passar:** a migration aditiva é inofensiva para a imagem nova, mas o **rollback
fica pareado** — imagem anterior não conhece a revisão, o entrypoint recusa subir; é preciso
`alembic downgrade <revisão anterior>` ANTES de trocar a tag.

**Como evitar:**
1. Antes de buildar da `master`, rode `git log <sha no ar>..HEAD -- <pasta de migrations>`. Se
   aparecer migration que não é sua, não deploye da `master`.
2. Suba por uma branch de deploy: `git branch deploy/x <sha no ar>` + `cherry-pick` só dos seus
   commits, e buildar desse SHA.
3. Ponha trava no script de build: `ls alembic/versions | grep -q '^0051' && exit 1`.
4. Avise a sessão dona e registre no STATUS que o próximo deploy da `master` aplica a migration.

**Relacionado:** commitar com `git commit -o -- <paths>` quando outra sessão tem arquivos staged no
mesmo índice; hook que lê o arquivo de mensagem roda ANTES do comando — escreva `-F` num passo
separado, senão o commit sai só com o que foi acrescentado depois.
