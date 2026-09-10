## Popover/Dropdown Radix portalado escapa de override CSS scoped a um ancestral {#radix-portal-escapa-override-css-de-ancestral}

tags: radix-ui, dropdown-menu, popover, portal, react portal, css custom properties, data attribute selector, contraste, gradiente, tema escuro/claro, tailwind, shadcn

**Sintoma:** um componente flutuante (dropdown/popover/tooltip) é declarado no JSX dentro de um
wrapper que sobrescreve tokens CSS via seletor de atributo (`[data-algo] .foo`/`[data-algo]
[data-bar]`) pra ficar legível sobre um fundo colorido/gradiente — ex. `[data-canvas-text]` trocando
`--card`/`--foreground` por vidro translúcido branco quando a barra senta direto sobre um degradê. A
intuição diz que o popover herdaria o mesmo override e ficaria ilegível (texto branco sobre fundo
quase-branco), levando a escrever preventivamente um escape-hatch tipo `data-canvas-panel` (atributo
que reverte os tokens pro tema normal) achando que seria necessário.

**Causa raiz:** os wrappers `*Content` do Radix (`DropdownMenuPrimitive.Content`,
`PopoverPrimitive.Content`, `TooltipPrimitive.Content`, etc. — confirme por componente, mas é o
padrão) renderizam via `*Primitive.Portal`, ou seja, o React Portal manda o DOM real pro
`document.body` (ou outro container explícito via prop `container`), **não** pro lugar onde o JSX
foi escrito. Overrides CSS por seletor de atributo/descendente dependem da relação **DOM real** —
como o Portal quebra essa relação (o nó vive fora da subárvore do wrapper, mesmo a árvore REACT
continuando aninhada), o override simplesmente **não se aplica** ao conteúdo portalado. "Está dentro
do JSX" não implica "está dentro do DOM".

**Solução:** antes de adicionar um escape-hatch (`data-canvas-panel` ou equivalente) num componente
`*Content` do Radix/shadcn, confirme se ele já é portalado — a maioria dos wrappers shadcn embrulha
o `Content` em `*Primitive.Portal` por padrão (leia o arquivo do componente em
`components/ui/*.tsx`, procure por `Portal`). Se for portalado, **não precisa de nada** — ele já sai
com os tokens normais do `:root`, sem herdar o override do ancestral. Confirme com uma inspeção
real, não só leitura de fonte: renderize, abra o popover (`userEvent.click` + `findByRole`, Radix
não abre com `fireEvent.click` puro em jsdom — precisa do gesto completo de pointer que `userEvent`
simula) e capture `document.body.innerHTML` (não `container.innerHTML` — o portal não está dentro do
`container` que `render()` devolve). O escape-hatch continua necessário SÓ pra painéis hand-rolled
(`<div>` normal posicionado com `absolute`, sem Portal nenhum) — esses sim são descendentes DOM
reais do wrapper e herdam o override.

**Ref:** Plexco Tasks, sessão 2026-09-10 — `frontend/src/components/kanban/shared/columns-menu.tsx`
(`ColumnsMenu`, popover "Colunas" da Plexco View, redesign 26-set-08 item 6/F4d). O botão gatilho
fica dentro de `[data-canvas-text]` (override de tema5/6 pra texto sobre gradiente, `globals.css`);
cheguei a cogitar que `DropdownMenuContent` precisaria do mesmo escape `data-canvas-panel` que
`topbar-actions.tsx`/`new-task-dialog.tsx` usam pra painéis hand-rolled (`<div data-canvas-panel>`
literal, sem Portal). Confirmado com harness descartável (`DUMP_OUT` + abrir o menu dentro do jsdom
via `userEvent`, dump de `document.body.innerHTML`, servido e inspecionado no Playwright) que o
popover já sai 100% opaco sem ajuste nenhum — `components/ui/dropdown-menu.tsx` confirma
`DropdownMenuPrimitive.Portal` envolvendo `Content`. `docs/PLANO.md` (seção "Frente: Redesign
26-set-08", fatia F4d item 6) registra o achado.
