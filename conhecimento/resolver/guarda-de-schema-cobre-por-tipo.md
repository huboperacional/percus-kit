## Guarda de schema que confere POR TIPO tem buraco no tipo que ninguém enumerou {#guarda-de-schema-cobre-por-tipo}

`tags: alembic, migration, modelo vs migration, schema drift, UniqueConstraint, CheckConstraint, foreign key, create_all, guarda offline, upgrade head --sql, duplicata silenciosa, constraint cross-row`

**Contexto:** um projeto que monta o schema da suíte pelo **MODELO** (`Base.metadata.create_all`) e o de produção pela **MIGRATION** precisa de guarda que compare os dois. A guarda existia e cobria **coluna, FK composta e `CHECK`** — três tipos, cada um com seu teste, todos offline via `alembic upgrade head --sql`.

Em 2026-08-21 uma feature acrescentou `UniqueConstraint("empresa_id", "nome")` a dois modelos. **A guarda passou verde.** Ela não cobria `UNIQUE` — e ninguém tinha notado a ausência, porque a lista de tipos cobertos nunca foi confrontada com a lista de tipos existentes.

**Causa raiz:** guarda escrita por **enumeração** cresce um teste por vez, à medida que cada tipo dá problema. O que ela prova é "os tipos que eu lembrei estão certos", nunca "o modelo e a migration são o mesmo schema". O buraco não é um bug — é a forma.

🔴 **E a divergência de `UNIQUE` é PIOR que a de coluna, ao contrário do que a intuição diz.** Coluna faltando quebra a rota em voz alta — foi um `503` medido em produção, achado em horas. **`UNIQUE` faltando não quebra nada: deixa gravar duplicata em silêncio.** Quando a recusa de duplicado nasce da constraint (o caminho correto, porque `SELECT`-antes-do-`INSERT` tem janela de corrida), a ausência da constraint em produção significa que **o 409 simplesmente nunca acontece**. Dois cadastros iguais convivem, o relatório fica ambíguo, e nenhum erro aparece em lugar nenhum.

**Correção:** a guarda nova confere **nome E colunas num trecho único** do DDL. Nome sozinho deixaria passar a troca de colunas, que transformaria "único por empresa" em "único global" — e recusaria o cadastro legítimo da empresa vizinha.

**Como provar que a guarda serve:** sabote a criação da constraint na migration e **veja o teste ficar vermelho nomeando as constraints ausentes**. Guarda que nunca ficou vermelha não prova nada — é a mesma armadilha do teste escrito depois do código.

⚠️ **Constraint cross-row não se resolve com `CHECK`.** `CHECK` só enxerga a própria linha; regra que soma várias linhas (invariante de soma zero, por exemplo) exige **trigger `DEFERRABLE INITIALLY DEFERRED`**, verificação no caso de uso, ou os dois. Declarar a regra sem declarar o mecanismo é deixá-la na disciplina de quem escreve o próximo código.

**Antes de fechar qualquer guarda de schema, pergunte:** *quais tipos de objeto existem no meu metadata, e quantos deles eu confiro?* A resposta honesta costuma ser menor que a lista.

**Ver também:** [[alembic-autogenerate-nao-ve-check-rls-revoke]].
