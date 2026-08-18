## Cloudflare: `X-Auth-Key` recusa a chave e o token Bearer funciona {#cloudflare-token-vs-global-key}

tags: cloudflare, api, X-Auth-Key, X-Auth-Email, Global API Key, Bearer, CF_TOKEN, CF_API, 6003, 6103, Invalid request headers, Invalid format for X-Auth-Key, dns record, zona

**Contexto:** você tem `CF_EMAIL` e `CF_API` no `.env` e a API responde:

```json
{"code": 6003, "message": "Invalid request headers",
 "error_chain": [{"code": 6103, "message": "Invalid format for X-Auth-Key header"}]}
```

**Causa raiz:** o par `X-Auth-Email` + `X-Auth-Key` exige a **Global API Key** (37 caracteres
hexadecimais). Qualquer outra coisa — um API Token, uma chave de origin CA, uma chave truncada —
é recusada pelo **formato**, antes de qualquer verificação de permissão. A mensagem fala de
formato, não de credencial inválida, e é essa distinção que economiza tempo.

**Solução:** use API Token com `Authorization: Bearer <token>`, que é o método atual e o
recomendado (permissão por escopo, revogável isoladamente). Verifique antes de usar:

```bash
curl -s https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer $CF_TOKEN"      # espera "status": "active"
```

**Ao criar registro DNS apontando para VPS com Traefik/Let's Encrypt:** `proxied: false`
(grey cloud, "DNS only") é **obrigatório**. Com o proxy ligado, o desafio HTTP do Let's Encrypt
falha e o site responde erro 520. E o campo `comment` tem limite de **100 caracteres** — acima
disso a API devolve `9313` e não cria o registro.

**Ref:** Empresa Milionária, 2026-08-12.
