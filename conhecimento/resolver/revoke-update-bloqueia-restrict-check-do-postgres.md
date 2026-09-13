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
   `UPDATE` para o role na tabela filha (isso quebraria o motivo do `REVOKE` original).
   ~~É rodar aquele `DELETE` específico por um role/conexão com privilégio elevado, isolado do
   caminho normal da aplicação.~~ 🔴 **Este conselho estava ERRADO — ver §Superusuário abaixo.**

### 🔴 Superusuário NÃO escapa — o check roda como o DONO da tabela

**Medido em 2026-09-13** (Empresa Milionária, sessão `-3e`), e corrige o item 2 acima, que
recomendava "privilégio elevado" como saída. Não é saída: **não funciona**.

A parede reapareceu noutro par de tabelas (`usuarios` ← `eventos_titulo`, append-only por FR-034)
num teste cuja limpeza rodava por `psql -U postgres` — superusuário. Falhou igual:

```
ERROR:  permission denied for table eventos_titulo
CONTEXT:  SQL statement "SELECT 1 FROM ONLY "public"."eventos_titulo" x
           WHERE $1 OPERATOR(pg_catalog.=) "autor_id" FOR KEY SHARE OF x"
```

A conexão **era** superusuária, medido na hora e não suposto:

```sql
SELECT current_user, (SELECT usesuper FROM pg_user WHERE usename = current_user);
-- postgres | t
```

**Por quê.** O gatilho de integridade referencial não roda com o privilégio de quem emitiu o
`DELETE`; ele roda com o privilégio do **dono da tabela** envolvida na constraint. Se o dono é o
role da aplicação e foi ele quem perdeu `UPDATE` pelo `REVOKE`, o check falha **para todo mundo**,
superusuário inclusive. Elevar o privilégio da sessão não toca no privilégio do dono.

🔑 **A inferência que isto derruba, e ela é sedutora:** *"superusuário ignora ACL, logo se deu
permission denied a conexão não era superusuária"*. A primeira metade é verdadeira para DML
direto e falsa para o check de RI — e um projeto passou dias com um achado aberto perseguindo
"então quem está conectado?" em vez de olhar o dono da tabela. Se aparecer `permission denied`
num `DELETE` de pai, **meça o dono da filha antes de suspeitar da sessão**:

```sql
SELECT tableowner FROM pg_tables WHERE tablename = '<filha>';
SELECT grantee, privilege_type FROM information_schema.table_privileges
 WHERE table_name = '<filha>' AND grantee = '<dono>';
```
3. Em teste que monta cenário descartável e bate nessa parede: não tente `DELETE` da cadeia —
   deixe-a órfã de propósito (documentado), mesmo padrão de deixar `empresas`/`grupos` fora da
   limpeza quando o RESTRICT em cadeia torna a limpeza impossível pelo role normal.
