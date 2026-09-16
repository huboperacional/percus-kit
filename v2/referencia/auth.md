# Auth — ponteiro

O padrão de auth Percus **não migrou** e não deve migrar: é referência de stack, não loop.

**Leia:** `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md`, Seção 2.

## O que a Constituição já garante sem você abrir o arquivo

- Todo projeto consome o **auth-service centralizado**; validação de JWT é **local**, via JWKS cacheado — nunca uma chamada externa por request.
- **Token em `localStorage` é vetado por padrão.** Cookie `httpOnly` + `Secure` + `SameSite=lax`. Há **uma** exceção documentada (SPA pura sem backend próprio), com as condições e os projetos que operam nela em `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` § "R7. Auth — padrão Percus único" — leia lá, não há cópia aqui.
- Refresh token é **opaco em Redis**, com rotação a cada uso e invalidação de família.
- Chave dedicada por domínio. Nunca reaproveitar secret de outro serviço.

Precisa de mais que isso (migração de legado, bridge cross-domain, OTP) → abra o V1.
