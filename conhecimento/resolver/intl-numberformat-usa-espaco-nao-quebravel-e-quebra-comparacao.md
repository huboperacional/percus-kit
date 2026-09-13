## `Intl.NumberFormat` separa moeda com espaço não-quebrável e quebra toda comparação de string {#intl-numberformat-usa-espaco-nao-quebravel-e-quebra-comparacao}

`tags: intl, numberformat, moeda, BRL, espaco nao quebravel, nbsp, U+00A0, U+202F, teste falhando, whatsapp, comparacao de string, R23`

**Sintoma:** um teste que compara texto formatado falha mostrando **duas strings
visualmente idênticas**:

```
AssertionError: expected 'Total: R$ 120,00' to contain 'R$ 120,00'
- Expected
+ Received
```

O olho não distingue, o diff não ajuda, e a tentação é achar que o teste está
"com algum caractere invisível colado" e reescrevê-lo.

**Causa:** `Intl.NumberFormat` **não usa espaço comum** entre o símbolo da moeda e
o número. Usa espaço não-quebrável (`U+00A0`) e, dependendo do ambiente e da
versão do ICU, espaço estreito não-quebrável (`U+202F`).

```js
const f = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
f.format(120).charCodeAt(2)   // 160  -> U+00A0, não 32
f.format(120) === "R$ 120,00" // false, com espaço comum digitado à mão
```

Tipograficamente está **correto** — é o que impede "R$" de ficar sozinho no fim
da linha. O problema é que o valor vaza para lugares que tratam texto como dado.

**Onde machuca de verdade** (além do teste):
- mensagem montada por concatenação e enviada por WhatsApp ou e-mail;
- busca e filtro por texto na interface ("por que `R$ 10` não acha nada?");
- `grep` em log e em CSV exportado;
- comparação de snapshot.

**Correção:** normalizar na única função que formata moeda, não em cada uso.

```ts
const MOEDA = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

export function reais(valor: Decimal | number | string): string {
  return MOEDA.format(Number(valor.toString())).replace(/[  ]/g, " ");
}
```

**Não** resolva escrevendo ` ` dentro do teste: o caractere fica invisível no
código, o próximo desenvolvedor apaga sem perceber, e a diferença entre `U+00A0`
e `U+202F` volta a morder quando a versão do Node mudar.

**Vale para:** qualquer `Intl.NumberFormat` e `Intl.DateTimeFormat` cujo resultado
seja comparado, concatenado, buscado ou exportado — não só moeda.
