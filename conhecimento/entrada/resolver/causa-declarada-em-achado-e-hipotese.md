## A causa escrita num achado de changelog/handoff é hipótese — reproduza antes de consertar {#causa-declarada-em-achado-e-hipotese}

`tags: changelog, handoff, achado nao corrigido, causa mal atribuida, reproduzir, hipotese vs medicao, consertar arquivo errado, retomada de sessao, versao anterior, R23`

**Sintoma:** você retoma um achado deixado por escrito ("teste X ficou vermelho por causa de Y,
merece decisão própria"), vai direto ao arquivo X, e ele está **verde**. Ou pior: você "conserta" X,
o sintoma continua, e o defeito real segue em outro arquivo.

**Causa raiz:** quem registra um achado normalmente está **fechando outra coisa** — anota o que viu
de relance, sem reproduzir. O fenômeno costuma estar certo; a **atribuição** é palpite. Um changelog
diz onde o autor *olhou*, não onde o defeito *mora*.

No caso real (percus-kit): a 6.36.6 registrou *"o teste do `external-action-guard` ficou vermelho com
a autorização viva"*. Medido na retomada: os 19 casos daquele arquivo passavam — eles isolavam o
`cwd`. Quem caía era `hardening-2026-05-18.tests.ps1`, outro arquivo, que rodava o mesmo hook sem
isolar. Seguir a atribuição literal teria levado a mexer num arquivo correto.

**Solução — três passos, nesta ordem:**

1. **Separe o fenômeno da causa.** "Fica vermelho quando existe autorização viva" é observação e
   costuma se sustentar. "É o teste do arquivo X" é hipótese e precisa de medição.
2. **Reproduza sob condição controlada antes de editar.** Rode com a condição presente e ausente, e
   compare o **conjunto** de falhas. A diferença aponta o culpado sem depender do relato.
3. **Capture a saída inteira, não o rabo.** `| tail -30` num runner de suíte entrega o total e come o
   nome do teste que falhou — foi assim que a atribuição errada nasceu na primeira vez e quase
   nasceu de novo na segunda. Peça a lista de falhas explicitamente (`-PassThru` + iterar `.Failed`).

⚠️ **Não trate o achado como ruído por não reproduzir de primeira.** Aqui a suspeita inicial foi
"a evidência não bate, o achado está errado" — e estava errada: o fenômeno era real, com número
(361/1 contra 362/0). Achado mal atribuído ainda é achado.

**Ref:** percus-kit 6.36.7, 2026-08-17 — achado da 6.36.6 reaberto na retomada. Relacionado:
[[reproduzir-antes-de-fixar]] (mesma disciplina aplicada a bug de produção) e
[[teste-de-hook-roda-na-raiz-le-estado-real]] (o defeito que estava por baixo).
