## CHECK bicondicional ACEITA a linha proibida quando o discriminante é NULL (UNKNOWN passa) {#check-bicondicional-unknown}

`tags: postgres, check constraint, three-valued logic, UNKNOWN, NULL, IS DISTINCT FROM, pg_constraint, conrelid, conname, idempotente, migration, mutation testing, invariante estrutural, schema`

**Contexto:** constraint escrita para tornar um invariante impossível de violar ("contagem existe SE E SOMENTE SE o estado é 'medido'"), porque a regra em código dependia de alguém lembrar de checá-la.

```sql
CHECK ( (state = 'medido'  AND count IS NOT NULL)
     OR (state <> 'medido' AND count IS NULL) )
```

**Causa raiz:** com `state = NULL` os dois ramos avaliam **UNKNOWN**, e `UNKNOWN OR UNKNOWN = UNKNOWN` — e **CHECK só rejeita quando o resultado é FALSE**. A linha proibida entra. A "totalidade" do bicondicional estava delegada ao `NOT NULL` da coluna, que vive em OUTRO statement — e num `CREATE TABLE IF NOT EXISTS`, justamente o que pode ser pulado numa reaplicação.

⚠️ **`IS DISTINCT FROM` NÃO resolve:** `state IS DISTINCT FROM 'medido'` com NULL dá `UNKNOWN OR FALSE = UNKNOWN`, também aceito.

**Fix:** tornar o CHECK auto-suficiente — `CHECK (state IS NOT NULL AND ( ...os dois ramos... ))`. Custo zero, e a barreira deixa de depender de cláusula alheia.

**Segundo furo na mesma migration — a guarda de idempotência:**

```sql
IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_x') THEN ALTER TABLE ...
```

`conname` é único por **TABELA**, não por banco. Com dois schemas no mesmo banco (ex.: `tracking` + `public`, `search_path` cobrindo os dois), a guarda casa a constraint da OUTRA cópia, **pula o ADD e a migration reporta sucesso com a tabela sem o CHECK**. Fix: `AND conrelid = 'tabela'::regclass`.

**Como os dois foram achados (é isto que replicar):** nenhum apareceu em leitura nem em review de prosa. Apareceram em **mutation testing** — remover cada conjunto do CHECK e rodar a suíte. 5 de 8 mutações passavam VERDES. A prova final foi executar o DDL contra um `postgres:17` efêmero e ver o banco **recusar** as 7 linhas ilegais; depois remover o CHECK e ver 5 testes ficarem vermelhos. Guarda que ninguém viu reprovar não é guarda. Ver [Postgres efêmero para testes destrutivos](pg-efemero-testes-destrutivos.md).

**Bônus da mesma frente — teste-espelho satisfeito pelo DOCSTRING:** testes que afirmam sobre o TEXTO do arquivo (`assert "coluna" in SRC`) são satisfeitos pelo cabeçalho de documentação, que costuma listar exatamente as mesmas colunas/constraints. Remover uma coluna do `CREATE TABLE` passava VERDE. Quanto melhor o docstring, mais cego o teste. Fix: recortar o alvo antes de afirmar (`SRC.split("CREATE TABLE ...")[1].split(chr(34)*3)[0]`) e prender o TIPO junto do nome.

**Ref:** Paid Media Automation, `crm_signal_state` (2026-07-29).
