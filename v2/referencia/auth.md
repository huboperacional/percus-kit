# Auth — ponteiro

O padrão de auth Percus **não migrou** e não deve migrar: é referência de stack, não loop.

**Leia:** `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md`, Seção 2.

## O que a Constituição já garante sem você abrir o arquivo

- Todo projeto consome o **auth-service centralizado**; validação de JWT é **local**, via JWKS cacheado — nunca uma chamada externa por request.
- **Token nunca em `localStorage`.** Cookie `httpOnly` + `Secure` + `SameSite=lax`.
- Refresh token é **opaco em Redis**, com rotação a cada uso e invalidação de família.
- Chave dedicada por domínio. Nunca reaproveitar secret de outro serviço.

Precisa de mais que isso (migração de legado, bridge cross-domain, OTP) → abra o V1.
