## `bg-x/90` sobre cor declarada como `var(--x)` não gera regra nenhuma {#tailwind-alpha-em-cor-var-nao-emite-regra}

`tags: tailwind, alpha-value, opacity modifier, bg-primary/10, hover:bg-x/90, shadcn, design tokens, CSS emitido, dist/assets, falha silenciosa, classe morta, webfont, font-display`

**Contexto:** um hover de botão "não funcionava". O reflexo é procurar especificidade, ordem de
cascata ou variável CSS ausente. Nenhum dos três era o caso.

**Causa raiz:** o modificador de opacidade do Tailwind (`/90`, `/10`, …) só funciona se a cor no
`tailwind.config` trouxer o placeholder **`<alpha-value>`**. Declarações como `accent2: 'var(--accent2)'`
ou `primary: { DEFAULT: 'hsl(var(--primary))' }` **não** trazem — a forma canônica do shadcn é
`'hsl(var(--primary) / <alpha-value>)'`. Sem o placeholder o Tailwind não sabe onde injetar o alpha e
**descarta o utilitário em build time**. Não é CSS inválido que o browser ignora: a classe **não
existe** no bundle.

**Por que ninguém vê:** `tsc`, a suíte de testes e o `build` passam **verdes**. Não há erro, não há
warning, e não há regra no CSS para inspecionar — só ausência. O elemento simplesmente não pinta.

**A medição que revela o tamanho real:** não procure a instância, procure a **classe do bug**. Liste
todo `(bg|text|border|ring)-<cor>/<n>` do `src/` e confira cada um contra o CSS emitido
(`dist/assets/*.css`). Num projeto real: das **19 classes distintas** com alpha, **ZERO** eram
emitidas — **109 usos mortos**. Todo `bg-primary/10` de fundo tingido, todo `bg-muted/30` de zebra,
todo `ring-primary/30` de foco. O hover "novo" que eu ia reportar como regressão nunca existira: o
botão *antigo* usava `hover:bg-primary/90` e também nunca teve hover.

**Cuidado com o grep:** os nomes vêm escapados no CSS (`.hover\:bg-x\/90:hover`, `.text-\[30px\]`).
Duas vezes eu dei falso-negativo por escape errado no shell e quase reportei que o build não emitiu o
que ele tinha emitido. Use Python/Node para procurar a string literal, não `grep` com aspas do shell.

**Correção:** para cor via `var()` + alpha, use um **token sólido** com o valor já calculado
(ex.: `--accent2Hover` = navy escurecido 10% em oklab), não `/NN`. Consertar a raiz — dar
`<alpha-value>` às cores — ressuscita todas as classes mortas **de uma vez**, o que muda a pintura de
todas as telas ao mesmo tempo: não faça isso na mesma corrida em que você precisa provar que as telas
não mudaram.

**Guard que impede reincidência:** derive os nomes de cor **do próprio config** (nunca uma lista fixa,
que apodrece) e falhe em qualquer `cor/NN` novo, com uma allowlist explícita da dívida conhecida — a
lista encolhendo é o rastro. Teste o guard **plantando a violação**: o meu passou verde com
`text-foreground/45` porque eu excluía `foreground` do conjunto, sendo ela cor **raiz**.

**Parente próximo:** o mesmo "o nome da classe mente sobre o que é emitido" aparece em
`leading-normal` (Tailwind emite `line-height:1.5`, **não** o `line-height:normal` do CSS — para esse
é preciso `leading-[normal]`) e em `last:[&>td]:border-b-0`, que gera `>td:last-child` (última célula
de **cada** linha) em vez de `:last-child > td`. Regra geral: **para mudança visual, verifique no CSS
emitido, não no `.tsx`**.

Ver também `#ui-falso-negativo-da-ferramenta` e `#redeclarar-custom-property-no-mesmo-root`.
