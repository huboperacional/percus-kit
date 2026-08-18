## Brief de design que cita a fonte pelo NOME propaga erro invisível {#brief-cita-token-nao-nome}

`tags: design, brief, handoff de design, fonte, tipografia, token, ff-sans, comentario desatualizado, mockup, altura do componente, documentacao nao testada`

Um brief de redesenho dizia "Space Grotesk + JetBrains Mono". Eu copiei isso de um **comentário
desatualizado** no template base; o produto carregava **Geist** havia muito tempo. O designer
calibrou o mockup na métrica da fonte errada, e a altura prevista do componente (148px) não bateu com
a implementada (160px) — diferença que só apareceu depois de construir.

**Regra:** no brief, cite o **token** (`--ff-sans`, `--ff-mono`), não o nome da família. Token é
verificável e não mente; nome é cópia, e cópia envelhece. Se precisar citar o nome para o designer se
orientar, **leia do arquivo de tokens na hora**, nunca de um comentário.

Vale para qualquer valor de design no brief: cor, raio, sombra, escala. Comentário em template é
documentação **não testada** — envelhece em silêncio e vira fonte de verdade por acidente.

Visto em: tiatendo, 2026-07-28 (rodada 1 do card recusada; brief corrigido para a rodada 2).
