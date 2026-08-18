## NULL explícito do ORM sobrepõe o `DEFAULT` da coluna: a data nasce vazia com o banco certo {#null-explicito-do-orm-vence-default}

tags: ORM, SQLAlchemy, default, server_default, created_at, updated_at, timestamp nulo, NULL, INSERT, coluna com DEFAULT, mapeamento

Todo registro criado pela API nascia com `created_at`/`updated_at` **nulos**, apesar de as colunas terem `DEFAULT now()` no Postgres — conferido: as 29 colunas do escopo tinham o default. O banco estava certo; quem mentia era o mapeamento.

Quando a coluna é mapeada no SQLAlchemy **sem `default=` e sem `server_default=`**, o ORM trata `None` como valor legítimo e emite `INSERT ... created_at = NULL`. E **NULL explícito vence o DEFAULT da coluna** — o banco só preenche quando a coluna é **omitida** do INSERT, que é justamente o que `server_default=` sinaliza ao ORM.

**Solução:** `default=<callable>` (ou `server_default=`) em toda coluna de data mapeada. Para `updated_at` **não basta**: `DEFAULT now()` só vale no INSERT, então sem `onupdate=` o campo nasce preenchido e **congela** — "atualizado em" igual a "criado em" não chama atenção de ninguém. Confira se existe trigger de `updated_at` no schema antes de assumir que o banco cobre (num caso real: zero triggers).

**O erro de método que custou mais que o bug:** a mesma classe já tinha sido achada dois dias antes num `[5-T]`, e o fix foi aplicado **só nos models onde o sintoma apareceu**. A classe seguiu viva em 21 arquivos. Achou bug estrutural num model? **Varra a classe, não conserte o model.**

**Gate que cobre o futuro:** em vez de um teste por model, parametrize sobre `Base.registry.mappers` — cobre os de hoje e os que nascerem amanhã. Dois detalhes fazem ele valer: importe todos os módulos de models (`pkgutil.iter_modules`), porque o registry só conhece o que foi importado; e **guarde contra vacuidade** (`assert len(mappers) >= N`), senão um import quebrado faz o gate passar sem asserção nenhuma. Foi o gate — não o autor — que achou as 4 colunas sem `onupdate`.

**Medir antes de correr:** `count(*) FILTER (WHERE created_at IS NULL)` por tabela separa "bomba com pino puxado" de "explosão em curso". No caso real deu **0** — o dado existente viera de um ETL que trazia as datas, e o bug só valeria dali pra frente.

**Vizinhos, e a diferença entre eles:**
[#fixture-mais-benigno-que-a-realidade](fixture-mais-benigno-que-a-realidade.md) — lá o teste não alcança o defeito; aqui nenhum teste mockado alcançaria, porque `default=` só é aplicado no **flush** e a suíte usa sessão mockada que nunca dá flush. Só `[5-T]` em prod pega.

**Ref:** Micro Investors, 2026-08-16 — 42 colunas em 21 models; provado em prod com CREATE → ler do banco → PATCH (`created_at` preservado, `updated_at` avançado) → DELETE.
