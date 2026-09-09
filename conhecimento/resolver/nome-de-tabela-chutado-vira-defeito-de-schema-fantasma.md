## Nome de tabela/coluna CHUTADO vira "schema ausente" fantasma {#nome-de-tabela-chutado-vira-defeito-de-schema-fantasma}

`tags: schema, migration, tabela, coluna, information_schema, to_regclass, defeito fantasma, diagnostico, plural`

**Sintoma:** você audita se uma feature está pronta, consulta o banco pelo nome que **parece** o
certo, recebe `UndefinedTableError` ou `AUSENTE`, e conclui **"falta migration / o schema não foi
aplicado"**. É um **defeito fantasma**: a tabela existe, com outro nome.

Caso medido, duas vezes na mesma hora:

| eu consultei | nome real | como o erro apareceu |
|---|---|---|
| `pix_receipts_used` | **`pix_receipt_used`** (singular) | `UndefinedTableError` → "a tabela não existe em PROD" |
| `orders.payment_proof_url` | **`orders.payment_proof_media_url`** | `information_schema` devolveu 0 → "coluna AUSENTE" |

Nos dois casos eu estava a um passo de abrir finding de schema numa frente que estava **completa**.

🔑 **Por que engana tão bem:** a resposta do banco é categórica ("não existe") e parece prova
objetiva. Mas o que ela prova é que **o nome que você mandou** não existe — não que a coisa não
exista. É a mesma família de
[[buscar-a-ancora-com-o-sigilo-nao-acha-o-cabecalho-sem-sigilo]]: a checagem mede o lado errado e
o resultado negativo passa por evidência.

**Como resolver — leia o DDL, não a sua memória:**
```bash
# 1. quem CRIA a coisa (a fonte da verdade sobre o nome)
grep -rln "<termo>" execution/database/migrations/
grep -rn "CREATE TABLE\|ADD COLUMN" execution/database/migrations/0NN_*.sql

# 2. ou pergunte ao CONSUMIDOR: o modelo tem o nome literal no SQL
grep -n "FROM \|INSERT INTO \|UPDATE " execution/plugins/**/models/<X>Model.py
```
Só então consulte o banco. E prefira a pergunta que **lista** em vez da que confirma:
```sql
SELECT table_name, column_name FROM information_schema.columns
 WHERE table_name = 'orders' AND column_name LIKE '%proof%';
SELECT to_regclass('pix_receipt_used');   -- NULL = não existe (não levanta exceção)
```
Listar por padrão (`LIKE '%proof%'`) devolve o nome verdadeiro **e** revela o seu erro de digitação
na mesma consulta.

⚠️ **`to_regclass` > `SELECT FROM`** para testar existência: devolve `NULL` em vez de derrubar a
transação com `UndefinedTableError`, então uma sonda que checa várias tabelas não morre na primeira.

⚠️ **Singular × plural é o erro mais provável** em base que mistura convenções (`orders` plural,
`pix_receipt_used` singular). Não normalize mentalmente — copie o nome do DDL.

**Não faça:** concluir "falta migration" a partir de UMA consulta que você mesmo escreveu; nem
registrar o achado antes de ter aberto o arquivo de migration. Auditoria que não abre o DDL produz
o mesmo tipo de fantasma que review que não abre o código.

**Ref:** tiatendo, 2026-09-05 — diagnóstico do item V1 #16 (comprovante Pix por IA). Duas suspeitas
de schema ausente, ambas erro de nome meu; o schema estava aplicado (migrations `070` e `083`).
