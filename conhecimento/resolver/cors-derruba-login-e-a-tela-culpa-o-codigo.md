## Login diz "código inválido ou expirado" e o código está certo — quem recusou foi o CORS da SUA API {#cors-derruba-login-e-a-tela-culpa-o-codigo}

tags: cors, otp, login, auth-service, preflight, options, 400, fastapi, starlette, frontend_url, cors_origins, mensagem que aponta para o lugar errado

**Sintoma.** O usuário recebe o código no WhatsApp, digita, e a tela responde **"Código inválido
ou expirado"**. Reenviar não adianta. O código está certo.

**A evidência que desmonta a mensagem.** No auth-service:
```
otp.request.accepted  audience=<produto> outcome=accepted
gowa.sent             destination=+55... status=200
otp.validate.ok       audience=<produto> outcome=success     <-- validou!
```
E, na SUA API, no mesmo segundo:
```
"OPTIONS /api/v1/auth/me HTTP/1.1" 400 Bad Request
```

**Causa.** O OTP terminou bem e o navegador recebeu os tokens. O passo seguinte — a primeira
chamada autenticada à sua API — morreu no **preflight de CORS**, porque a origem de produção não
estava na lista permitida. `fetch` que falha por CORS não devolve status ao JavaScript: dá
`TypeError: Failed to fetch`. O `catch` do fluxo de login trata isso como falha de validação e
imprime a única mensagem que ele conhece — **a que culpa o código**.

Por isso o defeito é caro: a mensagem manda investigar o auth-service, que é o único componente
sem defeito nenhum.

**Diagnóstico em 1 comando** — reproduz o preflight sem navegador:
```
curl -s -i -X OPTIONS "https://api.SEU-DOMINIO/api/v1/auth/me" \
  -H "Origin: https://SEU-DOMINIO" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization" | head -3
# 200 = ok   |   400 "Disallowed CORS origin" = achou
```

**Correção estrutural — derive, não configure duas vezes.** `FRONTEND_URL` e `CORS_ORIGINS`
descrevem a mesma coisa ("quem é o frontend deste produto") e divergem em silêncio: localmente as
duas são localhost e tudo passa; no deploy uma sobe e a outra fica.

```python
@property
def origensPermitidas(self) -> list[str]:
    frontend = self.FRONTEND_URL.rstrip("/")
    conhecidas = [o.rstrip("/") for o in self.CORS_ORIGINS]
    return list(dict.fromkeys([*conhecidas, frontend])) if frontend else conhecidas
```
```python
app.add_middleware(CORSMiddleware, allow_origins=settings.origensPermitidas, ...)
```
Trave com teste que o middleware usa a lista **derivada** — trocar de volta para a crua deixa os
outros testes verdes e devolve o defeito à produção.

**Dois ruídos que fazem perder tempo neste diagnóstico:**
1. **`docker service ls` dizendo `1/1` não significa que a task NOVA já responde.** Com
   `order: start-first` a antiga fica de pé durante a troca, e o `curl` logo após o deploy bate
   nela. Reteste depois de `docker service ps <svc>` mostrar a task nova em `Running`.
2. **A origem CORS é string exata.** `https://x.app` e `https://x.app/` são diferentes, e
   `http` ≠ `https`. Normalize a barra final dos dois lados antes de comparar.

**Mensagem de erro é parte do conserto.** Se o `catch` do login não distingue "servidor recusou o
código" de "a requisição nem chegou", ele vai culpar o código toda vez. Trate `TypeError: Failed
to fetch` como falha de rede/CORS e diga isso.
