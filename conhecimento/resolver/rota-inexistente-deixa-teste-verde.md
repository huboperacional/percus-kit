## Rota que ainda não existe devolve 404 — e isso deixa o teste VERDE sem implementação {#rota-inexistente-deixa-teste-verde}

`tags: tdd, fastapi, 404, teste vácuo, mutação, fase vermelha, escopo multi-tenant, idempotência`

**Sintoma:** você escreve o teste do endpoint antes do endpoint, roda a fase vermelha e ele
**passa**. Não é sorte nem cache: o framework devolve **404 para rota ausente**, e o banco fica
intacto porque nada rodou. Justamente os testes mais rigorosos são os que caem nessa.

Três numa sessão só (Plexco Tasks, s155):

| O teste | Por que ficou verde sem código |
|---|---|
| escopo de org (`assert status == 404`) | rota ausente **também** dá 404 |
| idempotência (`primeira == segunda`) | os 2 POSTs deram 404 e os dois lados eram `None` |
| atomicidade ("nada mudou de projeto") | nada mudou porque **nada rodou** |

**O que fazer, em ordem de força:**

1. **Prova por mutação.** Apague a linha de produção que o teste deveria proteger e confirme que ele
   cai; reponha. Numa delas, trocar o filtro de organização por um `select` sem filtro matou
   **exatamente** o teste de escopo e nenhum outro — é esse sinal que você quer ver.
2. **Assere o contrato observável** — `(status, corpo)` — em vez do estado final. `200 +
   {"cancelled": false}` distingue no-op limpo de erro engolido; "o carimbo não mudou" não distingue.
3. **`assert_not_awaited`** na chamada externa quando há fail-open: "não chamou" e "chamou e falhou"
   produzem a mesma saída.

Relacionado: {#fail-open-esconde-teste-vacuo}, {#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra}.
