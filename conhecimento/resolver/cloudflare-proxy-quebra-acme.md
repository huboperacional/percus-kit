## Cloudflare proxied (laranja) impede Traefik/Let's Encrypt de emitir cert {#cloudflare-proxy-quebra-acme}

`tags: cloudflare, proxy, laranja, orange cloud, dns only, cinza, traefik, lets encrypt, acme, certificado, tls, 403 unauthorized, well-known, acme-challenge, full strict, origin cert, dominio`

**Contexto:** dominio servido por Traefik + Let's Encrypt num VPS. O A record aponta certo pro VPS, o site funciona, cadeado verde no browser -- mas o Traefik loga falha de ACME em loop e nunca emite o cert.

**Causa raiz:** o registro esta **proxied (nuvem laranja)** no Cloudflare. O desafio ACME e' validado contra o IP que o DNS PUBLICO devolve, que sob proxy e' o do Cloudflare -- e o CF nao tem o token, entao responde **404**. O IP do CF aparece na propria mensagem de erro, e e' o que denuncia:
`invalid authorization: acme: error: 403 :: unauthorized :: 2606:4700:3036::6815:5069: Invalid response from https://DOMINIO/.well-known/acme-challenge/... : 404`

**Por que passa despercebido:** o site **funciona** -- o CF termina o TLS com cert proprio (emissor *Google Trust Services*) e encaminha pro origin. So olhando o cert do ORIGIN se ve o problema: fica em `TRAEFIK DEFAULT CERT` (auto-assinado). Funciona porque o CF esta em modo **"Full"**, que aceita cert invalido no origin. **Se alguem mudar pra "Full (strict)", o site cai na hora.** E o Traefik queima o limite do LE (5 falhas/h por hostname) em retry perpetuo.

**Solução:** para dominio servido por Traefik, o registro tem que ser **DNS-only (nuvem cinza)**. Apagar tambem os **AAAA** -- sobrando IPv6 do CF, cliente dual-stack continua caindo no destino antigo. Alternativa (se quiser manter o CF na frente): instalar um **Cloudflare Origin Certificate** no Traefik, ou trocar o desafio pra **DNS-01** com token de API do CF.

**Diagnostico em 10s** -- compare o emissor no publico e no origin:
```bash
echo | openssl s_client -connect DOMINIO:443 -servername DOMINIO 2>/dev/null | openssl x509 -noout -issuer
echo | openssl s_client -connect IP_DO_VPS:443 -servername DOMINIO 2>/dev/null | openssl x509 -noout -issuer
```
Ambos *Let's Encrypt* -> cinza, saudavel. Publico *Google Trust Services* + origin *TRAEFIK DEFAULT CERT* -> laranja, ACME quebrado.

**Ref:** Micro Investors, corte de dominio do F4 (2026-07-22). Os 3 subdominios irmaos ja eram cinza com LE; so apex e www estavam laranja. Desligar o laranja emitiu o cert em segundos e parou o churn. Familia de `#verificar-runtime-nao-estrutura`: o cert "existia" e era o errado.
