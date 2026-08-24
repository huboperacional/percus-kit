## Consertar metade da frase deixa a tela pior do que antes {#consertar-metade-da-frase-piora-a-tela}

`tags: i18n, traducao, prosa, JSX, Trans, interpolacao, escopo, curadoria, coerencia, formatacao de data, preservacao`

**Contexto:** externalizar strings de uma interface para i18n, quando a prosa é cortada por
marcação (`<strong>`, link) ou por interpolação (`{n} imóveis`). O extrator captura **pedaços**, não
a frase — e é fácil externalizar um pedaço e deixar o vizinho.

**O resultado é pior que não ter feito nada**, porque a incoerência fica **visível**. Casos medidos
em 2026-08-24:

- Tela de login em inglês exibindo **"Terms of Use e a Privacy Policy"** — o conector ficou em
  português porque foi classificado, corretamente, como "genérico demais para virar chave".
- Tela de primeiro acesso exibindo **"Li e aceito os Terms of Use and Privacy Policy"** — a
  segunda metade foi consertada numa rodada e a primeira ficou. Antes do conserto a frase era
  **coerentemente** portuguesa; depois virou mistura.

**A saída não é externalizar o pedaço solto.** `"e a"` como chave colidiria em toda parte e teria
de entrar numa allowlist — e allowlist grande é teste desligado. A saída é a **frase inteira virar
uma chave**, com as partes variáveis como placeholders:

```tsx
<Trans i18nKey="auth.legal.acceptLinks" components={{ link1: <a .../>, link2: <a .../> }} />
```

E o JSON guarda **só conectores e placeholders** (`"<link1/> and <link2/>"`), **nunca** o rótulo
visível — porque ele provavelmente já existe em outra chave, e duplicá-lo cria duas fontes que
divergem no primeiro ajuste.

**A mesma classe aparece fora de tradução: formatação.** Ao tornar `formatDate` sensível ao idioma,
duas telas passaram a concatenar data **dinâmica** com hora **cravada** em `pt-BR` — antes as duas
eram fixas e a linha era coerente. O reparo dessas duas linhas foi classificado como
**preservação**, não expansão de escopo: *a regra de "não toque na área alheia" existe para não
expandir escopo, não para deixar de reparar dano que o próprio patch causou.*

**Procedimento que pega:** depois de externalizar um bloco, **leia o parágrafo inteiro em volta** —
não só as linhas do diff. E procure a **classe**, não os exemplares: se dois pontos concatenam
formatador dinâmico com cravado, vá atrás do terceiro antes de fechar.

**Bônus de escopo:** `DD/MM/YYYY` vs `MM/DD/YYYY` não é cosmética. `08/09/2026` são **duas datas
diferentes** conforme quem lê — numa tela de distribuição financeira, isso é ambiguidade de dado, e
reclassifica o item de "polimento" para "escopo".

Ver também [[o-brief-errado-que-o-implementador-obedece]].
