## Override de tema/superfície num container pai vaza por herança e invisibiliza um filho que ficou "solid" de propósito {#custom-property-de-tema-no-pai-invisibiliza-filho-solid}

`tags: CSS, custom property, herança, design system, tema, white on white, texto invisível, data-attribute, color-mix, card-foreground`

**Classe de sintoma:** um bloco de tema/superfície colorida (ex.: "cor do menu", "cor de fundo por
organização") troca `--foreground`/`--muted-foreground` pra branco (ou outro tom) num container pai,
pra deixar o TEXTO GERAL legível sobre um fundo escuro/colorido. Um elemento FILHO desse container
foi desenhado pra ficar SEMPRE num tom sólido específico (ex.: um card "selecionado" que continua
branco de propósito, por cima do degradê do pai) — mas reusa uma classe genérica de texto
(`text-foreground`) em vez de uma classe amarrada ao tom sólido dele mesmo (`text-card-foreground`).
Resultado: o filho renderiza com o texto branco herdado do pai sentado sobre o próprio fundo branco
dele — invisível. Passa em `tsc`/testes de snapshot/testes de presença de elemento (o texto EXISTE
no DOM, só não se vê).

**O mecanismo:** custom properties CSS (`--foreground` etc.) são herdadas por padrão — uma
declaração no seletor do pai vale pra toda a subárvore, a menos que um seletor MAIS ESPECÍFICO
redeclare a mesma variável pra um valor diferente. Trocar `--foreground` no pai muda o valor pra
QUALQUER filho que leia `var(--foreground)` via `text-foreground`, mesmo filhos que sentam sobre um
fundo diferente do pai (ex.: `bg-card` sólido em vez do `background` degradê do pai). O token de
FUNDO (`--card`) pode estar corretamente intocado (o filho continua branco/navy conforme o modo) —
o bug é só no texto, porque ele lê um token que o pai redefiniu pra um contexto diferente.

**Por que não aparece óbvio revisando o componente isolado:** o componente do filho, olhado
sozinho, está correto — usa `bg-card` (fundo sólido, esperado) e `text-foreground` (texto normal,
parece razoável). O bug só existe na COMBINAÇÃO com o override do pai, que fica em outro arquivo
(`globals.css`), possivelmente escrito depois ou por outra pessoa/sessão.

**Fix — resetar os tokens de texto no filho, não confiar na herança:**
```css
[data-menu="roxa"] [data-rail-menu-surface] [data-filho-solid]{
  --foreground: var(--card-foreground);
  --muted-foreground: color-mix(in srgb, var(--card-foreground) 65%, transparent);
  color: var(--card-foreground);
}
```
Usar `var(--card-foreground)` (não hex fixo) quando o bloco pai NÃO está escopado a um único modo
claro/escuro (`:not(.dark)`) — o reset precisa acompanhar o modo atual, e `--card-foreground` já
faz isso automaticamente porque não foi tocado pelo override do pai. Hex fixo só é seguro quando o
próprio bloco pai já está condicionado a um modo só (padrão já usado em overrides de tema-de-fundo
que só existem em claro).

**Como pegar isso ANTES de deployar:** review de CÓDIGO (não só de comportamento) pega — basta
perguntar "esse `--foreground` que o pai redefine, ele HERDA pra algum filho que devia ficar num
tom fixo?" Um review automatizado (DeepSeek/Cross-Claude) pegou este caso especificamente porque o
comentário do código afirmava "o item ativo não é tocado por esse override" e a herança CSS
contradizia a afirmação — util procurar comentários que fazem essa promessa e verificar se ela é
realmente verdadeira dado o mecanismo de herança.

**Ref:** Plexco Tasks, 2026-09-01, sidebar "Tarefas" da ficha de tarefa docked
(`task-detail-list-rail.tsx` + `globals.css`) — item ativo (`bg-card` branco de propósito, "sempre
selecionado branco") ficava com texto branco herdado do bloco de "cor do menu" do pai. Achado por
review antes de deployar, não em produção. Relacionado:
`redeclarar-custom-property-no-mesmo-root` (classe de bug irmã: aquele é sobre redeclarar a MESMA
propriedade no MESMO seletor; este é sobre herança pra um seletor DESCENDENTE que não devia herdar).
