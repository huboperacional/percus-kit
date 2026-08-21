## Modo escuro revela defeito que o tema claro esconde — e o claro costuma ter MAIS {#modo-escuro-revela-defeito-que-o-tema-claro-esconde}

`tags: modo escuro, dark mode, tema, contraste, WCAG, acessibilidade, design tokens, tailwind, recharts, cor cravada, hardcoded, guard, medicao, varredura, legenda, paleta categorica`

**Contexto:** ligar modo escuro num app que só tinha tema claro. A expectativa natural é
"vou introduzir problemas no tema novo". Medido em produção (28 rotas, os dois temas):
**escuro 3 reprovas de contraste, CLARO 14**. O escuro não criou os defeitos — ele deu o
**instrumento** que mostrou os que já existiam no tema que todo mundo usava havia meses.

### Por que o tema claro esconde: a cor cravada COINCIDE com o token

Os piores achados eram invisíveis por construção, não por descuido:

| Cravado | No claro | No escuro |
|---|---|---|
| `bg-accent2 text-white` (17 sítios) | `--primary-foreground` **vale** branco → mesmo pixel | branco sobre CTA claro = **1,63** |
| `background: 'white'` na aba ativa | `--mi-surface` claro **é** `#ffffff` | 1,08, e o texto já é claro por herdar `--foreground` |
| `color: var(--mi-navy-700)` em link | legível sobre fundo claro | **1,65** sobre o escuro |

🔑 Nenhuma inspeção visual do tema claro jamais acusaria isso, porque **não há nada errado
nele**. O defeito só existe quando o outro lado do interruptor liga. Testar visualmente o
tema que você já usa é o teste que não pode falhar.

### Guard sobre a FORMA, não sobre a cor

A regra "não use `text-white` sobre fundo de token" é verificável estaticamente e não
depende de o defeito estar visível:

```ts
const TOKENS_DE_FUNDO = /bg-(primary|accent2|danger|destructive|surface|card|muted)\b/
const COR_CRAVADA = /\btext-(white|black|gray-\d{2,3}|slate-\d{2,3})\b/
// falha se as duas casarem na MESMA linha de className
```

Duas coisas que esse guard **não** alcança, e que precisam de guard próprio:

- **`style` inline.** Telas que pintam por objeto de estilo (fluxos de auth costumam)
  escapam de qualquer regex de classe. Ao escrever um guard, pergunte por qual caminho a
  cor chega: classe, inline, ou CSS de componente.
- **Cor de série virando cor de TEXTO.** Bibliotecas de gráfico (recharts) pintam o rótulo
  da legenda com a cor da série. Paleta categórica é desenhada para **superfície** (alvo
  3:1 de não-texto); como texto sobre card branco ela despenca — medido: lima 1,98, âmbar
  2,15, ciano 2,43, esmeralda 2,54, rosa 3,53, vermelho 3,76, violeta 4,23. A correção não
  é trocar a paleta: a cor continua inteira no **marcador** (onde tem trabalho a fazer) e
  só o texto passa a usar o token de tipografia.

**Não use fallback como defesa:** `var(--surface, #ffffff)` reintroduz o bug se a var
sumir — o fallback pinta branco e o escuro volta a ter claro sobre claro. Guard cobre;
fallback esconde.

### O observer de tema também é forma

Um `MutationObserver` com `attributeFilter: ['class']` sobrevive intacto quando o
interruptor do app passa a ser `data-theme`. Ele nunca dispara: trocar o tema deixa os
gráficos com as cores do tema ANTERIOR até um F5, sem erro nenhum. Isso só aparece
**trocando o tema com a página aberta** — reload esconde, porque aí as cores são lidas no
mount.

### Derivar os valores escuros: medir, não escolher

- **Reuse a paleta que já existe** se houver uma (fluxo de auth, tela de marketing). É a
  mesma marca, já aprovada, e evita uma segunda decisão de cor.
- **Semânticos precisam clarear, e o degrau se mede na PIOR superfície.** Um vermelho de
  tema claro deu 2,62 sobre o `--muted` escuro (reprova); só o terceiro degrau mais claro
  passou AA nas três superfícies.
- **Não ache tint achatando `rgba` sobre o fundo.** Transparência sobre azul-escuro rouba a
  matiz: âmbar a 18% vira `#292f2e` (cinza-esverdeado, matiz 170) e vermelho a 22% vira
  `#302235` (roxo). Construa o tint em HSL preservando a matiz do semântico com lightness
  baixa, e depois meça o par que a tela realmente mostra (texto semântico sobre o próprio
  tint).

### Ferramenta que nasce vermelha se desgasta

Um varredor de contraste que reprova em achado **pré-existente** ensina a ignorar o
código de saída. Mantenha uma lista de conhecidas: elas continuam sendo **impressas e
marcadas**, mas o exit code passa a significar "apareceu algo NOVO".

Duas armadilhas na conta do próprio varredor:

- **Alfa precisa ser composto**, no fundo e no texto. Tratar `rgba(...,.5)` como opaco mede
  uma cor que ninguém vê — e foi só depois de compor que apareceram dois rodapés a 3,71 que
  a versão anterior não via. Texto com alfa 0 deve ser **descartado**, senão
  `color: rgba(0,0,0,0)` é lido como preto e vira falso positivo.
- **O limiar de "texto grande" é em PONTOS.** WCAG 2.1: ≥18pt (24px), **ou** ≥14pt
  (18,66px) em negrito. Usar `px >= 18.66` para texto normal é frouxo — e limiar frouxo
  num instrumento de medição não produz alarme falso, produz **reprova real que passa
  batido**, que é o pior modo de falha possível.

Ver também: [[dois-vocabularios-de-token-convergem-por-apelido-nao-por-rename]],
[[grep-com-regex-em-css-emitido-mente]], [[teste-string-nao-prova-gate-runtime]].
