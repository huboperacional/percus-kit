## `useSortable` sem `SortableContext` roda liso — mas a LINHA vira droppable, e o handler que lia `over.id` como enum de zona classifica errado {#usesortable-sem-context-linha-vira-droppable-fantasma}

`tags: dnd-kit, useSortable, SortableContext, useDraggable, useDroppable, drag and drop, over.id, zona, dropzone fantasma, migracao de componente compartilhado, React, refactor`

**Contexto:** um componente de card/linha usa `useDraggable` simples (sem sortable, sem zona
tipada). Ele é trocado por uma versão compartilhada que usa `useSortable` (`@dnd-kit/sortable`) —
tipicamente ao unificar duas telas que tinham implementações divergentes do mesmo conceito. O
código que interpreta o drop (`onDragEnd`) lê `event.over?.id` e faz cast direto pro enum de zonas
(`'existentes' | 'novas' | ...`), porque antes da troca `over.id` só podia ser o id do container
da zona — nada mais registrava `useDroppable`.

**Causa raiz:** `useSortable` é `useDraggable` + `useDroppable` combinados no MESMO nó — a linha
vira alvo de drop também, não só origem de drag. Isso é necessário pra reordenação (soltar sobre
outra linha reposiciona), mas o handler antigo nunca previu essa 2ª categoria de `over.id`. Soltar
perto de OUTRA LINHA (não do espaço vazio do container) faz `over.id` chegar como o id da linha
(ex. `task:<uuid>`), que o cast pro enum de zona não reconhece — cai no branch `else`/default do
código que decide a zona de destino, classificando o drop errado silenciosamente (sem erro, sem
teste vermelho óbvio, porque o `onDragEnd` real dispara normalmente).

**O que NÃO quebra (e por que é fácil concluir "tá tudo bem"):** rodar `useSortable` sem nenhum
`SortableContext` ancestral não trava nem lança erro — o hook lê o Context com um valor default
(`items: []`, `activeIndex: -1`), então drag/drop básico (`setNodeRef`, `listeners`, `isDragging`,
o evento chegando em `onDragEnd`) continua funcionando. O que se perde sem o Context é só a
geometria de reordenação (animação de deslocamento, hit-testing fino entre itens do grupo) — não
o disparo do evento. Isso faz o sintoma real (zona resolvida errado) fácil de confundir com "falta
`SortableContext`" quando a causa é outra (o handler não sabe que uma linha é um alvo válido).

**Como detectar:** teste de integração que simula `active.id`/`over.id` como o id de uma LINHA
(não do container), não só do container da zona — se o teste só testa "soltar no container",
nunca exercita esse caminho. `grep` no handler por `as <EnumDeZona>` ou `switch`/`if` que assume
`over.id` só pode ser um valor fixo da lista de zonas.

**Solução:** resolver a zona a partir do id, nunca assumir a forma: se `over.id` tem o prefixo/
formato de item (ex. `task:<id>`), procure a que zona aquele item PERTENCE hoje (uma função tipo
`zonaDe(itemId)` que varre as listas correntes); senão, trate como id de zona direto. Rode essa
resolução tanto pro `over` quanto, se o mesmo handler decide reorder-vs-mover-entre-zonas, pro
cálculo de "está na mesma zona?" (drop numa linha da MESMA zona costuma ser no-op fora do contexto
que persiste ordem manual — não repita a escrita redundante que a versão anterior fazia).
Adicionalmente, envolva os grupos migrados em `SortableContext` (com a `strategy` compatível,
`verticalListSortingStrategy` pra lista vertical, `rectSortingStrategy` pra grid) mesmo sem
reorder-dentro-da-zona: o hit-testing de drag ENTRE grupos fica mais confiável com a geometria do
grupo disponível, e é o padrão que zero custo adicional resolve de vez a ambiguidade.

**Regra geral:** *migrar um componente de `useDraggable` pra `useSortable` muda a FORMA do
universo de ids que `over.id` pode assumir — todo consumidor de `onDragEnd` que fazia cast direto
pro enum de zona precisa de auditoria, não só o componente que migrou.*

**Ref:** Plexco Tasks, F4d do redesign 26-set-08 (2026-09-09/10) — `my-plexco.tsx` trocou
`PlexcoCard`/`useDraggable` por `TaskRow`/`Top3Slot` compartilhados (`useSortable`) com
`plexco/page.tsx`. Achado no review cross-provider (DeepSeek, R11): a hipótese inicial do revisor
("sem `SortableContext` o drag não funciona") estava tecnicamente imprecisa (confirmado lendo o
source do dnd-kit — o hook degrada, não trava), mas apontou a superfície certa. Prova de não ser
vácuo: teste de regressão simulando o drop sobre outra linha (não o container) confirmado VERMELHO
antes do fix (classificava tudo como a zona errada), VERDE depois.
