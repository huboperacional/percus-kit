## `WITH CHECK` não existe para `DELETE` — política `FOR ALL` com `USING` mais largo que `WITH CHECK` abre exclusão, não só leitura {#rls-with-check-nao-existe-para-delete}

tags: postgres, row level security, FOR ALL, FOR SELECT, USING, WITH CHECK, DELETE, politica
assimetrica, terceira chave, papel_provado, guc, permissive policy, conselho, spec-analyze

**O padrão que parece seguro e não é:** uma tabela já tem RLS por uma chave (ex.: `empresa_id`).
Surge um TERCEIRO leitor legítimo — alguém que provou algo (OTP, token, papel) mas não tem a
chave normal ainda. A saída óbvia parece ser: acrescentar um ramo `OR` no `USING` da política
`FOR ALL` existente, e deixar o `WITH CHECK` sem esse ramo, "pra não abrir escrita".

**O buraco:** em PostgreSQL, `WITH CHECK` **não participa de `DELETE` nenhum**. A cláusula só
entra em jogo pra `INSERT` (linha nova) e pra `UPDATE` (linha resultante). `DELETE` é filtrado
**só pelo `USING`**. Uma política `FOR ALL` com esse desenho deixa **qualquer sessão que satisfaça
o ramo novo do `USING` apagar a linha** — o oposto exato do que "`WITH CHECK` mais estreito" tinha
a intenção de impedir.

```sql
-- ERRADO: parece fechar escrita, mas nao fecha DELETE
CREATE POLICY t_leitura_ou_provado ON t
  USING (dono = current_setting('app.dono') OR provado = 'true')       -- 2 ramos
  WITH CHECK (dono = current_setting('app.dono'));                     -- 1 ramo só

-- uma sessao so com app.provado = 'true' (sem app.dono) PASSA no USING
-- para SELECT e para DELETE -- e so e barrada pelo WITH CHECK em INSERT/UPDATE.
-- DELETE FROM t WHERE id = ... TEM SUCESSO sob esse contexto.
```

**Solução: duas políticas PERMISSIVE, não uma assimétrica.** PostgreSQL soma políticas PERMISSIVE
por `OR`, mas só **dentro do comando a que cada uma se aplica** — uma política `FOR SELECT` nunca
é avaliada para `INSERT`/`UPDATE`/`DELETE`, estruturalmente, sem depender de nenhuma cláusula
escrita certa.

```sql
-- A politica FOR ALL de base fica INTOCADA (cobre INSERT/UPDATE/DELETE/SELECT como sempre)

-- Nova, so pra SELECT -- nao precisa de WITH CHECK, nao se aplica
CREATE POLICY t_leitura_provado ON t
  FOR SELECT
  USING (provado = 'true' AND alvo = current_setting('app.alvo'));
```

Nada precisa de `DROP` na política existente — é puramente aditivo. `INSERT`/`UPDATE`/`DELETE`
continuam decididos só pela política de base, porque a nova nem entra na conta pra esses comandos.

**Como isso passou por 2 rodadas de conselho antes de ser achado:** a primeira rodada (2
provedores) validou o desenho assimétrico sem pegar o buraco — um achou uma citação de regra
fabricada (CRITICAL sobre "simetria" que não existia em regra nenhuma do projeto, refutado por
fact-check), o outro achou problemas de conteúdo da spec, nenhum achou o mecanismo. Só a segunda
rodada, com o terceiro provedor, achou o `DELETE`. **Não fechar `/spec-analyze` com perna faltando
em domínio sensível** é o que salvou aqui.

**Prova que fecha o caso:** teste as três operações separadamente sob o contexto só-provado, e com
a asserção certa pra cada uma — `INSERT` levanta erro (`42501`, `WITH CHECK` reprovando a linha
nova); `UPDATE`/`DELETE` **não levantam erro nenhum**, só afetam **0 linhas** (a linha não é
visível pra eles, silêncio, não exceção). Esperar `42501` nos três é o erro de teste gêmeo deste
achado — ver [[delete-sob-rls-nao-apaga-erro-no-insert]].

**Parente:** [[trava-que-cobre-update-e-nao-delete-nao-e-trava]] — mesmo princípio ("DELETE não
herda a proteção que você escreveu pra UPDATE"), mecanismo diferente (trigger `BEFORE
UPDATE`/`BEFORE DELETE`, não política RLS).

**Ref:** Empresa Milionária, Frente A (primeiro acesso via WhatsApp provado), 2026-08-25.
`docs/superpowers/specs/2026-08-25-primeiro-acesso-rls-whatsapp-provado-design.md` §1/§6.
