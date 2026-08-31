## Trocar UNIQUE simples por composta quebra todo `INSERT ... ON CONFLICT` que mirava a coluna antiga {#troca-de-unique-simples-pra-composta-quebra-on-conflict-existente}

tags: sqlalchemy, on_conflict_do_update, upsert, unique constraint, migration, alembic,
index_elements, postgresql, sqlite, refatoracao de schema, blast radius

**O padrão que engana:** uma tabela tem `UNIQUE (coluna_a)` e um upsert em algum lugar do
código faz `INSERT ... ON CONFLICT (coluna_a) DO UPDATE ...` — funciona há meses. Uma decisão
de design (correta, revisada, às vezes vinda de conselho de 3 provedores) muda a UNIQUE pra
composta, `(coluna_a, coluna_b)`, porque a granularidade certa do "único" mudou (ex.: "único
por contato" virou "único por contato E por linha/dispositivo/tenant"). O `ALTER`/`CREATE
TABLE` roda limpo — não há erro nenhum na migration.

**O buraco:** `index_elements=["coluna_a"]` no `on_conflict_do_update` (ou `ON CONFLICT
(coluna_a)` em SQL cru) não casa mais com NENHUMA constraint da tabela — a única que existe
agora é a composta, e Postgres/SQLite exigem que o alvo do `ON CONFLICT` seja EXATAMENTE uma
UNIQUE/PK existente, não um subconjunto dela. O erro só aparece no primeiro `INSERT` que
tentar essa via, com mensagem que não menciona a mudança de schema: `ON CONFLICT clause does
not match any PRIMARY KEY or UNIQUE constraint` (SQLite) / `there is no unique or exclusion
constraint matching the ON CONFLICT specification` (Postgres).

**Por que é fácil não achar isso ao revisar o modelo/migration:** quem muda a UNIQUE olha o
model file, a migration, e os testes de guarda de schema (RLS, FK composta, etc.) — nenhum
desses sabe que existe um upsert em OUTRO arquivo, muitas vezes num módulo de "serviço" ou
"helper" que não aparece na busca por "quem usa este modelo pra CRIAR uma linha", porque
`on_conflict_do_update` não é um `Model(...)` comum, é uma forma de INSERT that a maioria dos
greps por `NomeDoModelo(` não pega (é `insert(Model).values(...)`, sintaxe diferente).

**O alcance real, medido:** neste caso, a função afetada tinha ~150 CHAMADORES espalhados por
um módulo de 7.500 linhas (proibido de editar) e dezenas de arquivo de teste — mas a própria
função upsert estava num arquivo DIFERENTE, editável, e nenhum dos ~150 chamadores precisou
mudar, porque o parâmetro que faltava (o segundo membro da UNIQUE composta) não era deles: era
um valor constante/derivado de config que a própria função upsert podia calcular sozinha.

**Como se evita:**
1. Antes de trocar UNIQUE simples → composta (ou vice-versa), `grep -rn "ON CONFLICT\|on_conflict_do_update\|on_conflict_do_nothing" --include=*.py` no repo inteiro — não só onde o MODELO é importado.
2. Rode a suíte COMPLETA depois da migration, não só os testes do arquivo que mudou — o efeito aparece em qualquer teste que passe pelo caminho de upsert, que pode ser um módulo sem relação aparente com a tabela.
3. Se o novo membro da chave composta é um valor que TODO chamador teria o mesmo (ex.: um único device/tenant/config hoje), prefira calculá-lo DENTRO da função de upsert em vez de adicionar parâmetro novo — evita cirurgia em cada chamador.

**Ref:** Empresa Milionária, Fase D Task D0 (migration do canal WhatsApp), 2026-08-27. UNIQUE de
`whatsapp_sessoes.numero_whatsapp` virou `(numero_whatsapp, device_id)`
(`docs/2026-08-24-fase-d-isolamento-do-canal.md` §2.1 item 2); `app/modules/whatsapp/
session_service.py::upsertSession` fazia `on_conflict_do_update(index_elements=
["numero_whatsapp"])` e quebrou 219 testes na suíte completa — 1 causa raiz só. Corrigido
adicionando `device_id` ao `.values()` e ao `index_elements`, calculado dentro da própria
função (`deviceCompartilhado()`), sem tocar nos ~150 chamadores.
