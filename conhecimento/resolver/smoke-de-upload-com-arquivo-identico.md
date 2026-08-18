## Provar um caminho de UPLOAD em produção sem mudar o que o visitante vê {#smoke-de-upload-com-arquivo-identico}

`tags: smoke de upload em producao, provar rota atras do middleware, unitario nao prova a rota, arquivo identico ao fallback, 307 vira 200, num_redirects 0, md5 identico, reversao provada, credencial fica no servidor, risco visual zero`

**Sintoma / impasse.** O teste unitário do handler está verde, mas ele não prova a rota atrás do
middleware, do proxy e do TLS. O smoke de verdade exige subir um arquivo em produção — e isso muda o
que o cliente vê. Resultado comum: o furo fica declarado no plano e nunca fecha.

**Saída: suba exatamente o arquivo que o fallback já serve.** Quando a rota de leitura tem um ramo de
fallback (307 para um asset estático ou para outro host), os dois estados possíveis passam a
renderizar **pixel idêntico** — então não existe janela em que o site fique diferente, e o que você
mede é só o CAMINHO:

- antes: `GET /api/asset/<...>` → **307** para o fallback
- depois do upload: **200, `num_redirects=0`**, servido do disco, `md5` idêntico ao da origem
- restaura (apaga arquivo + entrada do manifesto): volta a **307**, `md5` igual

Isso cobre a cadeia inteira — `401` sem cookie, login, `multipart` por HTTPS com o middleware na
frente, escrita no volume, releitura pela rota — com risco visual zero e reversão provada, não
prometida. Rodar o smoke **a partir do próprio servidor** mantém a credencial no `.env` de lá e fora
do shell local.

Medido em 2026-08-16 (`ads4agencies-site` v44, painel AutoWorx passando a aceitar mp4).
