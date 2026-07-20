# Conhecimento — ponteiro (e futura casa)

A base de "já vimos esse problema" **continua no V1** — é o que melhor funciona lá.

**Leia antes de debugar:** `${env:PERCUS_CANON_DIR}/conhecimento/COMO_RESOLVER.md`
**Como fazer coisas recorrentes:** `${env:PERCUS_CANON_DIR}/conhecimento/COMO_FAZER.md`

## Contrato de um verbete (vale já, e o gate cobra)

Se você registrar conhecimento aqui — ou lá — cada entrada precisa de:

1. `## Sintoma curto {#ancora-kebab}`
2. Linha `` `tags: ...` `` com termos independentes de idioma — **sem ela a busca não acha o verbete**
3. Entrada no índice: `- [Sintoma](#ancora-kebab)`
4. Corpo: **Sintoma · Causa raiz · Solução · Ref**

`gates/percus-gate.sh` bloqueia commit com verbete órfão do índice ou sem `tags:`. Os dois defeitos já aconteceram de verdade — 11 verbetes num único dia.

## Quando esta pasta deixa de ser ponteiro

Quando o piloto do tiatendo provar o V2 e a base migrar. Até lá, **não copie nada para cá**: duas cópias do mesmo conhecimento é exatamente o drift que o R25 combate.
