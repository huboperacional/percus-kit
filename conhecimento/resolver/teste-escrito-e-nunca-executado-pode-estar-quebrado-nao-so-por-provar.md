## "Escrito e nunca executado" não é o mesmo que "escrito e funcionando" — o arquivo pode estar quebrado, não só por provar {#teste-escrito-e-nunca-executado-pode-estar-quebrado-nao-so-por-provar}

`tags: pytest, postgres, seed, fixture, NOT NULL, server_default, INSERT cru, janela R20, tracking, marca, R1, R2, R23`

**Sintoma:** um arquivo de teste é escrito fora de janela, commitado com a declaração honesta de *"escrito e
NUNCA executado"*, e o tracking registra a task como **escrita e sem prova**. Quando a janela finalmente roda,
não aparece nem verde nem vermelho de asserção: aparece **erro de seed**. O alvo do teste nunca chega a ser
exercitado.

Medido em 19/09/2026 (Empresa Milionária, janela R20 da M47): `tests/pj/test_backfill_retencoes_postgres.py`,
5 testes, **5 failed** em três tentativas seguidas, sempre `asyncpg.exceptions.NotNullViolationError`, nunca
uma asserção. O backfill que os 5 testes existiam para provar **não foi tocado uma única vez**.

**Causa:** o helper de seed usa `INSERT` **cru** e omite coluna `NOT NULL` sem default — e elas aparecem **uma
por rodada**, porque o Postgres para na primeira. Aqui foram, em sequência: `pessoas.papeis` (jsonb),
`titulos.intercompany` (boolean), `eventos_titulo.autor_id` (uuid, e este com FK `RESTRICT` para uma tabela que
o seed nem criava). Havia ainda uma quarta, `titulos.documento_fiscal_emitido`.

**A causa-raiz da causa**, que é o que generaliza: mediu-se para o **ORM** e escreveu-se **SQL cru**. A
varredura que originou o seed filtrava
`not c.nullable and c.default is None and c.server_default is None` — que responde *"o que o ORM exige"*. Num
`INSERT` cru, o `default` de Python **nunca roda**. A pergunta certa é
`not c.nullable and c.server_default is None`, e ela devolve três colunas a mais.

**Solução:**
- **Não conserte sob relógio.** Dentro de janela, cada rodada custa o ciclo inteiro e revela **uma** coluna.
  Acrescentar coluna é mecânico; montar cadeia de FK que falta é reescrever o seed, e código escrito sob
  relógio vira teste que não discrimina. Pare, restaure por `sha256`, e leve o conserto para fora da janela.
- **Meça a lista inteira de uma vez**, do banco real, em vez de caçar uma por rodada:
  ```sql
  SELECT table_name||'.'||column_name FROM information_schema.columns
   WHERE table_name IN (...) AND is_nullable='NO' AND column_default IS NULL
   ORDER BY table_name, ordinal_position;
  ```
- **Escreva o detector que roda local, sem banco:** ler os `INSERT INTO` do arquivo de teste e comparar com as
  colunas `NOT NULL sem server_default` de cada modelo. Com **controle positivo** — remova uma coluna de
  propósito e exija que o detector a acuse. ⚠️ E conserte o **instrumento** antes de ler o resultado: na
  primeira versão desse detector, a regex casou aspas do meio de uma instrução SQL partida em concatenação de
  strings Python e deu falso positivo; "olhar e ver que está lá" teria normalizado um detector quebrado.

**Consequência para o tracking (R2), que é o ponto:** a task não estava *"escrita e sem prova"*. Estava
**escrita e quebrada** — e as duas descrições levam a decisões diferentes. "Sem prova" sugere *falta rodar*;
"quebrada" diz *falta consertar antes de rodar*. Enquanto ninguém executa, as duas são indistinguíveis, e o
tracking honesto registra a mais otimista sem saber. **Declarar "escrito e nunca executado" é honesto sobre o
que se fez e silencioso sobre o que se sabe** — e o que se sabe é nada.

**Relacionado:** `prova-de-teste-precisa-provar-que-o-teste-existe-e-foi-coletado`,
`sabotagem-contra-arquivo-que-nao-coleta-nao-prova-nada`,
`teste-de-catalogo-mede-a-fixture-nao-a-migration`.
