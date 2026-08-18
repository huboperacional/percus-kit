## Módulo fail-open: "quebrado" e "corretamente desligado" ficam idênticos de fora, e o teste passa nos dois {#fail-open-esconde-teste-vacuo}

`tags: fail-open, feature flag, allowlist, dark launch, teste vacuo, mutation testing, assert_not_awaited, AsyncMock, gate silencioso, LLM, timeout`

**Sintoma:** o teste do gate de uma feature flag / allowlist passa. Você apaga a linha de
produção que implementa o gate. **O teste continua verde.**

**Causa raiz:** num módulo fail-open, o gate e a falha real convergem para a **mesma saída
observável**. Com o gate apagado, a execução segue até a chamada externa (LLM, HTTP, etc.), que
levanta — por credencial ausente no ambiente de teste, timeout, o que for —, o `except Exception`
do fail-open engole, e a função devolve exatamente o mesmo `ok=False` que o gate devolveria.
Resultado igual, mecanismo oposto. Asserir o resultado não distingue os dois.

Isso é grave porque **o gate costuma SER o dark launch**: se ele regride, a feature liga para
todo mundo em produção e a suíte inteira continua verde.

**Solução:** não asserte só o resultado — asserte que **o efeito colateral caro não aconteceu**.
Mocke a dependência externa e verifique que ela não foi chamada:

```python
llm = AsyncMock(return_value={"itens": [{"titulo": "nao devia chegar aqui"}]})
with patch.object(S.settings, "FEATURE_ENABLED", False), \
     patch.object(S.Service, "chamada_cara", llm):
    r = await S.entrypoint(texto, org_id="qualquer")
assert r.ok is False
llm.assert_not_awaited()      # <- é isto que dá dente ao teste
```

E escreva a **contraprova**: a org DENTRO da allowlist tem que CHEGAR na dependência. Sem ela,
uma allowlist que bloqueia todo mundo também passaria no teste de cima.

**Como descobrir se você já tem esse buraco:** mutação. Apague a linha de produção do gate, rode
a suíte, e veja se alguma coisa fica vermelha. Verde = o gate não tem teste.

**Ref:** Plexco Tasks s154 (2026-07-28), `wa_structurer.py`. Achado por mutação durante a
implementação: com o gate `if not settings.WA_STRUCTURER_ENABLED or not _org_allowed(org_id)`
removido, **7 passed**. Vale para qualquer guarda absorvida por `except` genérico — flag,
allowlist, rate-limit, circuit breaker.
