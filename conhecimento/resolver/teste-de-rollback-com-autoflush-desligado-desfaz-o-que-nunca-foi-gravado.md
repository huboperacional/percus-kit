## Teste de "falha desfaz tudo" com `autoflush=False` passa sem provar nada — a mudança nunca chegou ao banco {#teste-de-rollback-com-autoflush-desligado-desfaz-o-que-nunca-foi-gravado}

`tags: sqlalchemy, autoflush, rollback, savepoint, begin_nested, atomicidade, mesma transacao, teste verde falso, monkeypatch, sessao de teste, unit of work, R23`

**Contexto:** Empresa Milionária, 17/09/2026, V2.3 Entregas, Task 10. `DevolverPedido` cancela as entregas pendentes
e **depois** arquiva os títulos, tudo na mesma transação. O teste da atomicidade seguia o molde de sempre: trocar a
etapa seguinte (`ArquivarTitulo.executar`) por uma que levanta, rodar dentro de `begin_nested()` e afirmar, por
releitura, que as entregas continuam `pendente`.

**O sintoma que salvou o teste:** o falso `ArquivarTitulo` também lia a situação da entrega (para provar que a falha
vinha **depois** do cancelamento) e leu `pendente`, não `cancelada`. Sem essa leitura extra, o teste teria ficado
verde **na primeira rodada**, afirmando que "a falha desfaz o cancelamento".

**Causa raiz:** a sessão da suíte é `async_sessionmaker(..., autoflush=False)`. O caso de uso só **atribui**
(`entrega.situacao = CANCELADA`), e o `flush` viria no fim. Quando a falha acontece antes desse `flush`, a mudança
existe **só no objeto**. O `select` de releitura não força flush e lê o banco intacto. O rollback "desfaz" algo que
nunca foi escrito. A asserção final (`pendente`) é verdadeira pelo motivo errado, e continuaria verdadeira se o caso de
uso **nem cancelasse** — ou se cancelasse em outra transação.

**Por que é armadilha de classe, não deste projeto:**
- produção costuma ter `autoflush=True`, e o teste com `False` mede um caminho que produção não percorre;
- toda prova de "mesma transação" por rollback tem essa forma, e a asserção pós-rollback não distingue "desfeito" de
  "nunca gravado".

**Conserto:** no ponto de falha simulado, **force o flush e confirme a escrita ANTES de levantar**:

```python
async def arquivarQueFalha(self, **kwargs):
    await self.session.flush()                        # a mudança CHEGA ao banco
    situacao = (await self.session.execute(
        select(Entrega.situacao).where(Entrega.id == remessaId))).scalar_one()
    chamadas.append(situacao)                         # prova: já estava gravada
    raise RuntimeError("falha simulada")
...
assert chamadas == [CANCELADA]                       # a negativa: foi gravado
assert situacaoRelida == PENDENTE                     # e o rollback desfez
```

As duas asserções juntas discriminam. Só a segunda, não.

**Efeito colateral a esperar:** depois do rollback do savepoint, os objetos da sessão ficam **expirados**. Ler
`objeto.id` depois dele dispara carga síncrona e estoura `MissingGreenlet` na sessão async. Guarde os ids antes.

**Como procurar em código existente:** `grep -rn "begin_nested" tests/` e, em cada teste que afirma "nada mudou" depois
de uma exceção, veja se algo prova que a mudança **foi gravada** antes da falha. Se não prova, o teste passa com o caso
de uso sabotado para não gravar nada. Faça essa sabotagem. No caso real, a S10f ("não cancela nada") derrubou o teste
**com** o conserto aplicado; a mesma sabotagem **não** foi rodada contra a versão sem `flush`, e o "passaria verde" acima
é raciocínio sobre a asserção, não medição.

**Relacionados:** `add-fora-do-savepoint-nao-e-isolado-por-ele.md` (o outro lado do savepoint: o que ficou pendente
**fora** dele).
