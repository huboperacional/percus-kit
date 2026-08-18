## Preflight CORS recusado: o serviço fica verde e só o browser do usuário quebra {#preflight-cors-falha-silenciosa}

tags: cors, preflight, OPTIONS, CORSMiddleware, access-control-allow-origin, origin recusada,
400 Disallowed CORS origin, curl esconde, healthcheck verde, falha invisivel, browser bloqueia

**Sintoma.** "Os usuários não conseguem entrar" / "o app não fala com o serviço central" — enquanto
todo monitor diz que está tudo bem: serviço `healthy`, `/health` 200, log do serviço limpo, backend
próprio intacto, build e testes do frontend passando.

**Causa.** O `CORSMiddleware` está recusando a origin: `OPTIONS` (preflight) devolve
`400 Disallowed CORS origin` **sem** `access-control-allow-origin`. O browser bloqueia antes de
enviar o body — nenhuma request chega ao handler, então **nada erra em lugar nenhum que se monitore**.
`curl` normal esconde: sem `Origin` + `Access-Control-Request-Method` você recebe 200 e conclui que
está bem.

**Diagnóstico (2 comandos).**
```bash
# 1) o preflight real
curl -s -o /dev/null -w "%{http_code}" -X OPTIONS <url> \
  -H "Origin: <sua-origin>" -H "Access-Control-Request-Method: POST"     # 200 esperado; 400 = recusada

# 2) o CONTROLE — uma origin de OUTRO produto que você sabe que funciona
#    passa? => a lista está recortada.  falha também? => o middleware/serviço é que quebrou.
```
No browser, da origin real: `fetch(...)` com `TypeError: Failed to fetch` **sem status** = bloqueado
no preflight; com status legível = chegou.

**Correções.** A causa mais comum é env sobrepondo o default versionado do código
(`CORS_ALLOWED_ORIGINS` no service spec). Estado correto costuma ser **sem** o env:
`docker service update --env-rm CORS_ALLOWED_ORIGINS <servico>`.

**Duas armadilhas que custaram horas (caso real 2026-07-30, 6 produtos fora por ~11h):**

1. **Falso-verde por população errada.** O smoke de CORS de um dos produtos rodou durante o incidente
   e devolveu **15/15 verde** — foi reportado como prova de saúde. Ele não errou no que mediu: mediu
   **só os origins dele**. O modo de falha perigoso de um smoke não é errar um item, é **acertar todos
   os itens da lista errada e imprimir PASS**. Regras: mudança em serviço compartilhado se verifica
   pela lista do **dono do serviço**; lista vazia é **FATAL**, nunca "0/0 passou"; exigir `ACAO`
   **ecoando a origin** (`*` deve reprovar — com `Authorization` o browser recusa wildcard).
2. **Gate pós-deploy não cobre regressão que chega sem deploy.** O incidente entrou por um
   `docker service update` disparado de fora, num dia sem deploy do serviço. Um gate pós-deploy teria
   ficado mudo o incidente inteiro. Cobertura real exige verificação **periódica**.

**Corolário.** Resposta de erro (401/422) **sem** `ACAO` quando a origin é permitida é sintoma do
mesmo bug, não comportamento separado do middleware — e enquanto durar, o cliente **não consegue
distinguir "sessão morta" de "falha de rede"**, o que quebra qualquer regra do tipo "só descarte o
refresh token em 401".
