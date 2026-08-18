## Backfill manual via CLI (`--account-id`) grava dado real mas não atualiza a tabela de saúde da coleta {#cli-backfill-nao-atualiza-collection-log}

`tags: worker, collector, backfill, collection_log, saúde da coleta, CLI, cron, observabilidade`

**Contexto:** operador pediu backfill urgente de métricas Meta Ads pra um cliente (D4U), 6 contas,
217 dias, via `docker exec <worker> python collector.py --account-id <id> --date <data>` em loop
(caminho manual, não o cron agendado).

**Sintoma:** o backfill rodou limpo (zero erro, dado real gravado em `metrics_daily`/`ads`/etc.,
confirmável por query direta), mas a tela de Saúde da Coleta continuou mostrando as mesmas contas
como "Atrasada" com a MESMA data antiga, mesmo depois do F5.

**Causa raiz:** `worker/collector.py` tem duas funções que fazem coisas parecidas mas não a mesma
coisa. `collect_all()` (o caminho do cron) chama `_log_collection(acc["id"], date, "SUCCESS"/"FAILED")`
pra cada conta — é isso que grava em `collection_log`, a tabela que a tela de saúde lê. O caminho CLI
(`--account-id`) chama `collect_with_retry()` DIRETO, pulando esse logging por inteiro. Os dois
caminhos escrevem a MESMA métrica em `metrics_daily`, mas só um escreve o "aconteceu" em
`collection_log`.

**Solução:** depois de qualquer backfill manual via `--account-id`, gravar `collection_log` à parte,
via SQL direto (idempotente, `ON CONFLICT (ad_account_id, date) DO UPDATE`):
```sql
INSERT INTO public.collection_log (ad_account_id, date, status, finished_at)
SELECT aid::uuid, d::date, 'SUCCESS', now()
FROM unnest(ARRAY['<uuid-1>','<uuid-2>']::text[]) aid
CROSS JOIN generate_series('<inicio>'::date, '<fim>'::date, '1 day') d
ON CONFLICT (ad_account_id, date) DO UPDATE SET status='SUCCESS', error_message=NULL, finished_at=now();
```
`ad_account_id` aqui é o `id` INTERNO (UUID) de `client_ad_accounts`, não o `account_id` da
plataforma (Meta/Google) — os dois são campos diferentes na mesma tabela, fácil de confundir.
Correção estrutural (não feita, registrada como dívida): `collect_with_retry` podia sempre chamar
`_log_collection` também, unificando os dois caminhos.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156) — backfill D4U (6 contas Meta,
01/01→05/08/2026), `client_ad_accounts.client_id = 77d723a1-...` (nome interno do cliente ainda
"Gustavo", `account_name` de cada conta já rebrandeado pra "D4U" — outra pegadinha de busca por nome).
