## Parâmetro adicionado e NÃO propagado: suíte verde, defeito vivo — e a contagem não é o discriminador {#parametro-adicionado-sem-propagar}

tags: `propagacao-de-parametro`, `relogio-congelado`, `race-condition`, `teste-vacuo`, `discriminador-de-teste`, `spy`, `refactor-incompleto`

**Sintoma.** Você adiciona um parâmetro para corrigir um defeito (relógio congelado, request-id, tenant, `now`), escreve um teste de unidade da função que o recebe, fica verde — e **o defeito continua em produção**, porque o ciclo real chama a função sem o parâmetro e cai no `param or default()`.

**Causa raiz.** O default silencioso (`agora = agora or utcNow()`) faz o call-site esquecido **funcionar**, só que errado. Testar a função isolada mede a assinatura, não a propagação.

**Solução — espione a propagação, não a função:**

    instantes = []
    real = mod.readX
    async def espiao(*a, param=None, **kw):
        instantes.append(param)
        return await real(*a, param=param, **kw)
    monkeypatch.setattr(mod, "readX", espiao)

    await fluxoReal(...)                       # a PORTA de entrada, nao a funcao interna
    assert instantes, "o fluxo nao leu nenhuma vez"
    assert all(i is not None for i in instantes), "algum call-site nao propagou"
    assert len(set(instantes)) == 1, "o ciclo usou mais de um valor"

⚠️ **O discriminador é o `None`, NÃO a contagem de leituras.** Exigir `>= 2` leituras parece tornar o teste não-vacuoso, mas a contagem varia com o estado: um fluxo que aborta cedo (o caminho correto!) lê uma vez só e o assert quebra sem defeito nenhum. O `None` é o que denuncia o call-site esquecido, e denuncia com uma leitura só.

⚠️ **Um kill-switch pode esconder o buraco do seu próprio teste.** Se o call-site não propagado está depois de um `if not settings.FLAG: return`, o espião nunca o vê. Cheque a lista de call-sites por AST, não só o que o teste percorre.

**Ref:** Família Milionária, 2026-08-17. `agora` foi adicionado a `readSession` e o ciclo real seguia chamando sem ele; o review pegou, e o segundo caso (`_guardPendingUnificado`) estava atrás de `PENDING_UNIFIED_ENABLED=False`, invisível ao teste.
