## Dois vocabulários de token convergem por apelido, não por rename em massa {#dois-vocabularios-de-token-convergem-por-apelido-nao-por-rename}

`tags: design system, design tokens, tailwind, shadcn, css variables, hsl, alpha, modo escuro, dark mode, data-theme, refactor, churn, convergencia, cascata, @layer, medicao antes de planejar`

**Contexto:** um app acumulou **dois vocabulários de cor** no `tailwind.config` — um herdado do
shadcn (`background`, `foreground`, `muted`, `primary`…) e um do design system próprio (`app`,
`surface`, `inset`, `t1`, `t3`, `accent2`…). O HANDOFF do projeto registrava isso como dívida e
sugeria remover o vocabulário shadcn.

**A primeira coisa a fazer é CONTAR, não renomear.** Medido: shadcn eram **896 usos em 83
arquivos**; o vocabulário próprio, **328**. Renomear 1.224 usos de classe para o vocabulário
*minoritário* seria churn enorme, com risco de regressão real, **sem mudar um pixel**. O documento
apontava para o lado errado, e ninguém tinha contado.

**A dívida real não era o nome — eram DUAS FONTES DE VERDADE.** Convertendo os dois lados para hex,
**9 dos 17** tokens próprios eram duplicata exata de um token shadcn (delta 0–3/255). Duas variáveis
para a mesma cor divergem em silêncio, e o modo escuro teria que declarar as duas e mantê-las em
sincronia para sempre.

**Conserto:** os duplicados viram **apelido no config**, apontando para a var canônica; as variáveis
duplicadas somem do CSS.

```js
app:     'hsl(var(--background))',
surface: 'hsl(var(--card))',
t1:      'hsl(var(--foreground))',
```

Os dois nomes continuam existindo como classe — **zero uso tocado** — e o otimizador do Tailwind até
funde os seletores, porque as declarações ficam idênticas (`.bg-app,.bg-background{…}`).

**Converter para HSL mata a armadilha do alpha de vez.** Com `var(--x)` guardando **hex**, o Tailwind
**descarta** toda utilidade com modificador de alpha em *build time* — `bg-accent2/90` não emite
regra nenhuma, sem erro, com build/tsc/teste verdes. Com tripla HSL ele reescreve para
`hsl(var(--x) / .9)` e a classe pinta. Enquanto metade do vocabulário aceitava alpha e a outra
metade não, a regra tinha que ser **lembrada**; depois da conversão a assimetria não existe.

**Zero mudança de cor é obtenível, e deve ser medida:** converta cada hex para HSL com **uma casa
decimal** e confira o round-trip de volta para hex. Num caso real os 22 tokens fecharam exatos, então
a convergência não moveu um pixel — e isso é afirmável, não esperável.

**Guarde a CAUSA, não o sintoma.** Em vez de uma lista de "classes que não podem usar alpha", duas
invariantes: *toda cor do config é `hsl(var(--x))`* e *toda var consumida como cor guarda tripla HSL,
nunca hex*. Teste o guard pelo lado negativo (sabote um token e veja reprovar), senão ele é verde
decorativo.

**Armadilhas medidas no caminho:**

- **A ordem das chaves do config é significativa.** O Tailwind emite na ordem em que elas aparecem;
  se dois utilitários de cor caem no mesmo elemento com a mesma especificidade (ex.: um `<th>` com
  `text-t3` fixo mais um `text-t2` vindo de `col.className`), vence **o emitido por último**.
  Reagrupar as chaves "para organizar" muda cor de tela inteira sem nenhum teste vermelho.
- **Contar classe no CSS emitido com `\.nome\{` erra** quando o otimizador funde seletores: a classe
  sai como `.bg-app,.bg-background{…}` e o padrão com chave devolve **zero**, parecendo que a classe
  sumiu. Conte o nome, não o nome-seguido-de-chave, e use `grep -F`.
- **Guard que casa menção com declaração obriga a apagar a explicação para ficar verde.** Um
  `toContain('--surface:')` reprovou porque um comentário histórico citava a variável. Ancore em
  início de linha (`/^\s*--surface:/m`).

**Modo escuro: procure quantos INTERRUPTORES existem antes de escolher a paleta.** No caso real havia
dois — o vocabulário próprio escutava `[data-theme="dark"]` e **já tinha paleta escura completa em
produção**, enquanto o shadcn escutava `.dark` e nunca teve paleta. Alinhar o `darkMode` do Tailwind
para o seletor que já funciona é uma linha, não muda nada enquanto não houver valores escuros, e
evita meia tela virando.

**CSS em texto não prova cascata.** Um `body { background: var(--x) }` num arquivo importado depois
do entry e **sem `@layer`** fica fora de todas as camadas e vence por ordem de fonte — sequestrando o
fundo do shell inteiro por meses, com 2 unidades por canal de diferença, invisível a olho. A única
resposta para "de que cor está a tela" é `getComputedStyle` no browser, contra o ambiente real.

Ver também: [[alfa-invisivel-mesmo-icone-parece-igual]], [[teste-string-nao-prova-gate-runtime]].
