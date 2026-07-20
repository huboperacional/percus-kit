# Infra e stack — ponteiro

Não migrou, não deve migrar: referência lida sob demanda.

**Leia:** `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md`

## O que a Constituição já garante

- **Banco, role e namespace dedicados por projeto.** Nunca reaproveitar de outro, "nem para teste rápido".
- Deploy é autônomo e por milestone → `loops/deploy.md`.
- Armadilhas de Swarm/Traefik/build que já custaram incidente estão em `loops/deploy.md`, não aqui.

Precisa de detalhe (portas, stacks, Postgres/Redis compartilhados, Cloudflare) → abra o V1.
