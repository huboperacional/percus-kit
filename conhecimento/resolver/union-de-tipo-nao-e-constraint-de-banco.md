## Union de tipo no código não é constraint do banco — e o best-effort torna a violação muda {#union-de-tipo-nao-e-constraint-de-banco}

`tags: CHECK constraint, 23514, union de tipo, TypeScript, Prisma, audit_log, enum, best-effort, log engolido, mock esconde fronteira, migration antes do codigo, gate de fonte`

**Contexto:** ligar auditoria em rotas que escreviam sem deixar rastro. O tipo do campo era uma
**union de literais** no código (`type EntityType = "client" | "staff" | …`). Estendê-la compilou,
passou no type-check e passou em **17 testes novos**. Em produção, as **4 mutações responderam
`200`** e a tabela de auditoria continuou com **ZERO** linha — com **651** linhas de outras origens,
provando que a tabela funcionava.

**Causa raiz:** o banco tinha a **própria lista fechada**, que o schema do ORM **não declara**:

```sql
CHECK (entity_type = ANY (ARRAY['client','staff','ad_account', … ,'consent']))
```

Todo INSERT violava `23514`. E o helper de auditoria era **best-effort por desenho** (`try/catch`
que só faz `console.error`), então a violação virou uma linha de log que ninguém lia.

**Três fronteiras invisíveis, e o defeito precisava das três:**
1. **union de tipo ≠ constraint de banco** — o schema do ORM não modela `CHECK`, então nem o
   type-check nem o gerador de migration têm como acusar;
2. **helper best-effort transforma erro em silêncio** — a rota respondeu sucesso;
3. **o teste mockava o módulo de auditoria** — o mock escondeu exatamente a fronteira que quebrou.
   Verde local não prova travessia de fronteira.

**Conserto:** migration que **ALARGA** o `CHECK` (só alarga ⇒ nenhuma linha existente pode violar um
superconjunto estrito ⇒ não há gate de pré-condição, e a aplicação não pode falhar por dado).

⚠️ **A migration é pré-requisito do código, não o contrário.** Invertida — que foi o que aconteceu —
nada quebra, e é pior: cada escrita responde `200` sem rastro, que é exatamente a ausência que a
tarefa existia para fechar.

**Gate que ficou** (visto reprovando com o defeito reintroduzido): compara a union do código com o
`CHECK` da migration mais recente que o redefine, **nos dois sentidos**. Dois detalhes que o fazem
valer: (a) tira comentário SQL antes de varrer — o DOWN de toda migration desta classe repete a
lista **antiga**, e sem isso o gate compararia contra o estado revogado; (b) ordena as migrations
**numericamente**, porque com ordenação lexicográfica uma `100_` viria antes da `99_`.

**O que fazer antes de estender qualquer união de literais que vira coluna:**

```sql
SELECT conname, pg_get_constraintdef(oid)
  FROM pg_constraint
 WHERE conrelid = '<tabela>'::regclass AND contype = 'c';
```

**Sintoma que denuncia a classe:** operação responde sucesso e o efeito não aparece no banco. Antes
de procurar no código da rota, procure `ERROR:` no log do processo — helper best-effort esconde a
causa exata a um `grep` de distância.
