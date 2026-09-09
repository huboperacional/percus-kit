## REVOKE UPDATE numa filha bloqueia o RESTRICT check de DELETE no pai, mesmo sem linha nenhuma referenciando {#revoke-update-bloqueia-restrict-check-do-postgres}

tags: postgresql, rls, revoke, restrict, foreign key, for key share, privilegio, append-only, R23

**Sintoma.** Um `DELETE` numa tabela PAI falha com `permission denied for table <filha>` — não
com a mensagem normal de RESTRICT (`update or delete ... violates foreign key constraint`), e
não porque exista de fato uma linha referenciando. A mensagem nem cita a tabela que você está
tentando deletar; cita a FILHA, e diz permissão, não dado.

**Por que morde.** A checagem de uma FK `ON DELETE RESTRICT`/`NO ACTION` roda, internamente,
algo como `SELECT 1 FROM <filha> WHERE <fk_col> = $1 FOR KEY SHARE`. Cláusulas de lock de linha
(`FOR UPDATE`, `FOR NO KEY UPDATE`, `FOR SHARE`, `FOR KEY SHARE`) exigem privilégio **UPDATE** na
tabela, não SELECT — mesmo que a query pareça só leitura. Se a tabela filha teve
`REVOKE UPDATE FROM <role>` (padrão comum para impor append-only/imutabilidade, ex.: histórico de
auditoria, timeline fiscal), então **qualquer `DELETE` na tabela pai falha incondicionalmente**,
com filho ou sem.

**Caso real** (Empresa Milionária, 2026-09-08). `eventos_remarcacao` tem `REVOKE UPDATE, DELETE
FROM em_user` (imutabilidade de auditoria, ADR-0019 §5) e uma FK composta `RESTRICT` para
`etapas_os`. Um teste de gate contra Postgres real tentava, na limpeza do cenário,
`DELETE FROM etapas_os WHERE empresa_id = :e` — e falhava, mesmo com ZERO linhas em
`eventos_remarcacao` referenciando aquela etapa.

Isolando por `psql` direto, como o mesmo role da aplicação:

```sql
-- funciona
SELECT 1 FROM eventos_remarcacao;

-- ERROR: permission denied for table eventos_remarcacao
SELECT 1 FROM eventos_remarcacao FOR KEY SHARE;
```

Mesma tabela, mesmo role, zero linhas — a única diferença é a cláusula de lock. `em_user` tinha
`SELECT` (nunca revogado) mas não `UPDATE` (revogado de propósito). O erro é de **privilégio**,
não de referência.

🔑 **Fácil de confundir com "a etapa está referenciada" quando na verdade é "o role não pode nem
checar se está".** O sintoma não distingue os dois casos até você isolar por `psql` direto e
medir com zero linhas de propósito.

**Como resolver.** Antes de assumir que uma tabela filha append-only é "transparente" para quem
só mexe na tabela pai:

1. Confira com `rg`/`grep` se a aplicação alguma vez faz `DELETE`/hard-delete na tabela PAI. Se
   nunca faz (padrão comum: soft-lifecycle por coluna de status, nunca hard-delete), é achado
   **dormente** — registre e siga, sem consertar nada.
2. Se algum dia um `DELETE` real precisar acontecer na tabela pai, a saída **não** é devolver
   `UPDATE` para o role na tabela filha (isso quebraria o motivo do `REVOKE` original) — é rodar
   aquele `DELETE` específico por um role/conexão com privilégio elevado, isolado do caminho
   normal da aplicação.
3. Em teste que monta cenário descartável e bate nessa parede: não tente `DELETE` da cadeia —
   deixe-a órfã de propósito (documentado), mesmo padrão de deixar `empresas`/`grupos` fora da
   limpeza quando o RESTRICT em cadeia torna a limpeza impossível pelo role normal.
