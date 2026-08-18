## Recurso finito consumido por N filhos: travar só a linha PAI errada deixa a soma estourar {#lock-no-pai-errado-soma-estoura}

tags: with_for_update, race condition, TOCTOU, soma excede, saldo, alocacao, N:N, baixa, pagamento parcial, SELECT FOR UPDATE, concorrencia, teto, over-allocation, conciliacao

**Contexto:** relação N:N em que os dois lados são finitos — um pagamento quita vários títulos,
um lote atende vários pedidos, um crédito cobre várias faturas. Você faz o certo e trava a
linha antes de conferir o saldo:

```python
titulo = (await s.execute(
    select(Titulo).where(Titulo.id == tituloId).with_for_update())).scalar_one()
jaAplicado = (await s.execute(
    select(func.sum(Baixa.valor)).where(Baixa.movimentoId == movimentoId))).scalar_one()
if jaAplicado + novo > movimento.valor:
    raise SemSaldo()
```

**Causa raiz:** o lock está no **título**, e o recurso que estoura é o **movimento**. Duas
transações que baixam títulos DIFERENTES do MESMO movimento não disputam linha nenhuma em
comum: as duas passam pelo `with_for_update` sem esperar, as duas leem `jaAplicado` no mesmo
valor antigo, e as duas gravam. A soma final passa do teto sem que nenhuma constraint reclame —
`SUM` não é constraint.

**Sintoma em produção:** conciliação que fecha com dinheiro a mais e não reproduz em teste,
porque teste roda uma transação por vez. Some quando você olha, porque o `SELECT` de
conferência lê o estado final já consistente-parecendo.

**Regra:** trave a linha do **recurso finito** — a que a soma consulta —, não só a que você
está alterando. Se as duas são finitas (aqui: saldo do título E valor do movimento), trave as
duas, **sempre na mesma ordem** em todos os caminhos de código, senão troca a corrida por
deadlock.

```python
titulo = ... .with_for_update()      # 1º sempre
movimento = ... .with_for_update()   # 2º sempre
```

**Onde mais aparece:** estoque com reserva por pedido, cupom com limite de uso, cota de plano
consumida por várias chamadas, verba de campanha rateada por peça.

**Teste que pega:** o de unidade NÃO pega — precisa de duas transações reais concorrentes,
contra Postgres. Enquanto não existir, o teto é garantia de intenção, não de banco.

**Ref:** Empresa Milionária, Fase A Task 9 (`AplicarBaixa`), 2026-08-12. Achado por revisor
cross-provider; o lock do título já estava lá e escondia o buraco, porque parecia que "tem
lock".
