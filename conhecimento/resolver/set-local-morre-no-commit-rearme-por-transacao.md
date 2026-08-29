## `SET LOCAL` morre no commit — e código legado que comita por dentro precisa de rearme por transação {#set-local-morre-no-commit-rearme-por-transacao}

`tags: postgres, rls, set_config, set local, multi-tenant, sqlalchemy, after_begin, commit interno, legado, R23`

**Sintoma:** RLS por GUC (`current_setting('app.tenant_id')`) funciona em toda rota nova, mas num
pipeline legado o usuário recebe a resposta certa **e** um erro por cima: a primeira escrita passa
e a segunda quebra com `42501` (RLS) ou `23502` (NOT NULL via `server_default` lendo o GUC). Em
SQLite a suíte inteira fica verde — não há RLS nem GUC para morrer.

**Causa raiz:** `set_config(..., true)` é `SET LOCAL` — o valor vive **na transação**, e isso é
correto (valor de sessão vazaria no pool para o próximo tenant). Só que o código legado comita
**por dentro** dos serviços que ele chama (no caso real: `upsertSession`/`getSession` comitavam em
~90 sítios de um arquivo de 7.5k linhas congelado). O primeiro commit interno encerra a transação
e mata o contexto; tudo que vem depois roda num banco onde a política fail-closed nega tudo —
leitura devolve vazio sem erro, escrita estoura. Fixar o contexto "uma vez no topo do request"
**não sobrevive ao primeiro commit** e é exatamente a fiação que parece certa e não é.

**Solução — rearme por transação, opt-in por sessão:** um listener `after_begin` global na classe
`Session` (síncrona) que reaplica o contexto no começo de CADA transação nova, mas só em sessão
que optou:

```python
def _rearmar(sessaoSync, transacao, conexao):
    tenantId = sessaoSync.info.get(CHAVE_NAMESPACED)   # a chave PRIMEIRO: é o caminho quente
    if not tenantId:
        return
    if conexao.dialect.name != "postgresql":
        return
    conexao.execute(text("SELECT set_config('app.tenant_id', :t, true)"), {"t": tenantId})

event.listen(Session, "after_begin", _rearmar)

async def fixarContexto(session, tenantId):
    session.sync_session.info[CHAVE_NAMESPACED] = str(tenantId)   # transações FUTURAS
    await session.execute(...)  # e a CORRENTE — o lookup de usuário já abriu a transação,
                                # o after_begin dela já passou sem contexto
```

Quatro detalhes que decidem se isto funciona ou vira buraco:

1. **A dupla ação do `fixar` não é opcional.** No ponto de fiação, alguma consulta anterior já
   abriu a transação — sem a aplicação imediata, a primeira transação fica órfã.
2. **Opt-in é a chamada, então a chamada é o que se tranca.** Rearme automático em rota nova
   esconderia o `commit()` indevido que a invariante "contexto morre no commit" existe para
   acusar. Guarda estática: teste que varre o código e falha se `fixarContexto` aparecer fora dos
   módulos do canal legado.
3. **Chave de `session.info` com namespace** (`percus.canal.tenant_id`), e o lookup dela vem antes
   de qualquer outra checagem — o listener roda em toda transação do processo.
4. **A prova é contra Postgres real, com o padrão que quebrava:** escrita → commit interno →
   segunda escrita. E o teste de CONTRASTE (fiação ingênua de um `SET LOCAL` só) tem que FALHAR —
   se um dia passar, o rearme virou decoração ou a RLS foi desligada.

**Custo se ignorar:** dias — o defeito só aparece em produção (SQLite verde), é intermitente aos
olhos do usuário (resposta certa + erro), e a correção "óbvia" (fixar no topo do request) passa em
review e volta a quebrar no primeiro commit interno. Caso real: Empresa Milionária, fiação D2
revertida em 29/08 de manhã e refeita à tarde por este desenho
(`docs/superpowers/specs/2026-08-29-d2-fiacao-rearme-contexto-design.md`).

Relacionado: [[rls-sem-force-dono-ignora-politica]], [[404-por-design-esconde-tenancy]].
