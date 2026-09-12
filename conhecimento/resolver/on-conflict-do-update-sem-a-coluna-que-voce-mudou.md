## `ON CONFLICT DO UPDATE` sem a coluna que você acabou de mudar: o seed parece aplicado e o valor antigo sobrevive {#on-conflict-do-update-sem-a-coluna-que-voce-mudou}

`tags: postgres, upsert, on conflict, seed, idempotencia, falha silenciosa, harness de teste, R23`

**Sintoma:** você edita um seed idempotente para trocar o valor de uma coluna, roda o seed, ele
responde `INSERT 0 1` sem erro nenhum — e o comportamento não muda. Reler o arquivo confirma que a
troca está lá. O banco continua com o valor velho.

**Causa:** `INSERT ... ON CONFLICT (id) DO UPDATE SET` atualiza **só as colunas listadas no `SET`**.
Num banco onde a linha **já existe** — que é o caso normal de um seed idempotente rodado pela
segunda vez — o `VALUES` inteiro é descartado e só o `SET` vale. A coluna que você mudou no `VALUES`
nunca é escrita.

```sql
-- o seed dizia 'basico'; você trocou para 'financeiro_mais' aqui...
INSERT INTO subscriptions (id, familia_id, grupo_id, plano, status, proxima_cobranca)
VALUES ('...e5', '...e1', '...e3', 'financeiro_mais', 'active', '2099-12-31')
ON CONFLICT (id) DO UPDATE SET
  grupo_id = EXCLUDED.grupo_id,
  status   = EXCLUDED.status,      -- ...mas `plano` NÃO está aqui
  proxima_cobranca = EXCLUDED.proxima_cobranca;
```

Resultado: container novo pega `financeiro_mais`; container reaproveitado (o caso comum) fica em
`basico` para sempre. O conserto é uma linha: `plano = EXCLUDED.plano`.

**Por que engana tanto:** as três coisas que se costuma conferir dizem "aplicado" —
(1) o arquivo tem o valor novo, (2) o psql não reclama, (3) o `INSERT 0 1` parece escrita. Nenhuma
delas olha a linha. E o efeito colateral aparece longe: no caso medido, uma cota de plano ficou em
1 CNPJ e um spec de R1 falhou por pré-condição, a três camadas de distância do seed.

**Como aplicar:** ao editar o `VALUES` de um upsert, **releia o `DO UPDATE SET` na mesma edição** e
pergunte se a coluna que você tocou está lá. Depois confira **no banco**, não no arquivo:

```bash
psql -tAc "SELECT plano FROM subscriptions WHERE id = '...e5';"
```

Um `SELECT` de uma linha é mais barato que a sessão inteira que se perde diagnosticando o sintoma
remoto. Prima de [[o-seed-que-so-roda-uma-vez-por-container]] — as duas classes moram no mesmo
arquivo de seed e as duas passam caladas.

Achado em 2026-09-12, projeto Empresa Milionária, ao trocar o plano do grupo sintético do harness
de R1 (`tests/r1/seed-bootstrap.sql`) de `basico` para `financeiro_mais`.
