# Conhecimento — ponteiro (e futura casa)

A base de "já vimos esse problema" **continua no V1** — é o que melhor funciona lá.

**Leia antes de debugar:** `${env:PERCUS_CANON_DIR}/conhecimento/resolver/`
**Como fazer coisas recorrentes:** `${env:PERCUS_CANON_DIR}/conhecimento/fazer/`

## Contrato de um verbete (vale já, e o gate cobra)

**Um arquivo por verbete** — `resolver/<slug>.md`, e o nome do arquivo **é** o slug. A obrigação
(quando registrar, o que é Forbidden) é da R23: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`
§ "R23. Base de conhecimento — consultar antes de resolver, registrar depois". Cada arquivo precisa de:

1. `## Sintoma curto {#slug}` — a âncora casa com o nome do arquivo
2. Linha `` `tags: ...` `` com termos independentes de idioma — **sem ela a busca não acha o verbete**
3. Corpo: **Sintoma · Causa raiz · Solução · Ref**

**Consulta é `grep` de tags**, não leitura do índice: `grep -l "tags:.*<termo>" resolver/*.md`.
**`INDICE.md` é gerado** por `scripts/gerar-indice-conhecimento.ps1` — editar à mão é Forbidden pela
R23, e o hook `knowledge-write-guard` recusa.

`gates/percus-gate.sh` bloqueia commit com verbete sem `tags:`, com slug fora do nome do arquivo, com
link morto para outro verbete, ou com verbete fora do `INDICE.md` — nesse último caso a correção é
**regerar** o índice, nunca editá-lo. Os defeitos já aconteceram de verdade — 11 verbetes num dia.

## Quando esta pasta deixa de ser ponteiro

Quando o piloto do tiatendo provar o V2 e a base migrar. Até lá, **não copie nada para cá**: duas cópias do mesmo conhecimento é exatamente o drift que o R25 combate.
