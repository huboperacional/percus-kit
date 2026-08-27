## `<summary>` não esconde o que está DENTRO dele — só o que vem DEPOIS, dentro do `<details>` {#summary-nao-esconde-o-que-esta-dentro-dele-so-o-que-vem-depois}

`tags: details, summary, html nativo, collapse, accordion, acessibilidade, sem estado, R23`

**Necessidade:** um bloco com "fato sempre visível" (ex.: uma contagem, um título) + "detalhamento
opcional" (explicação, lista longa) que o usuário pode recolher — mas o FATO não pode desaparecer
quando o bloco está fechado, só o detalhamento.

**Armadilha óbvia:** envolver o bloco inteiro (fato + detalhamento) num único `<details>` com um
`<summary>` só de título/chevron. Ao fechar, o `<details>` esconde **tudo que não é o
`<summary>`** — inclusive o fato que devia continuar visível, se ele estiver fora do `<summary>`
mas dentro do `<details>`.

**Truque que resolve sem JS/estado:** o `<summary>` de um `<details>` é a ÚNICA parte que o
navegador NUNCA esconde, aberto ou fechado — e `<summary>` aceita conteúdo rico (não só texto:
`<div>`, `<p>`, múltiplos elementos), apesar de o HTML5 "estrito" só prever conteúdo de frase ou um
único heading ali (funciona em todos os browsers evergreen mesmo assim). Então: põe o chevron +
título + o FATO que tem que ficar sempre visível DENTRO do `<summary>`; o detalhamento colapsável
vai nos irmãos do `<summary>`, dentro do mesmo `<details>`, depois dele.

```html
<details>
  <summary>
    <ChevronIcon />
    <div>
      <p>Título sempre visível</p>
      <p>Contagem/fato sempre visível</p>
    </div>
  </summary>
  <div><!-- detalhamento, some quando fechado --></div>
</details>
```

Zero estado React, zero JS — o teclado já abre/fecha nativamente, e o navegador cuida da
visibilidade sem CSS condicional.

**Consequência pra teste:** um teste que verificava "o fato não pode estar dentro de um
`<details>`" (`expect(el.closest('details')).toBeNull()`) precisa mudar de invariante quando o
`<details>` passa a envolver o bloco inteiro — o que importa não é mais "está fora do
`<details>`", é "está dentro do `<summary>`" (`expect(el.closest('summary')).not.toBeNull()`),
que é o que o navegador de fato nunca esconde.

**Medido em Paid Media Automation (26/08):** `AvisoOrfas.tsx` — pedido do operador foi "chevron no
título que recolhe o detalhamento", com a contagem total tendo que continuar sempre visível
(invariante pré-existente, documentada desde antes: "truncar sem dizer quantas apaga a
informação"). Primeira tentativa pôs tudo (título + contagem + detalhamento) dentro do `<details>`
com só o título no `<summary>` — quebrou 3 dos 6 testes existentes (a contagem sumia ao fechar).
Segunda tentativa moveu título+contagem pra DENTRO do `<summary>`, detalhamento pros irmãos —
6/6 verdes, e a mesma correção replicada no teste de página que exercitava o mesmo componente.

**Regra que fica:** "esconder o resto, manter isto visível" com `<details>` nativo = o que fica
visível vai no `<summary>`, não como irmão dele fora do `<details>` — irmão fora ainda funciona,
mas só se o toggle não precisar estar junto do fato (nesse caso o `<summary>` fica sozinho, sem o
fato, que é outra composição válida — a escolha depende de onde o design quer o clique).
