## `Intl.NumberFormat` de moeda descarta as casas que o chamador pediu, e preço por unidade vira R$ 0,00 {#intl-currency-descarta-as-casas-que-o-chamador-pediu}

`tags: intl, numberformat, moeda, BRL, casas decimais, toFixed, preco por unidade, custo unitario, decimal.js, arredondamento na exibicao, R23`

**Sintoma:** um valor real e diferente de zero aparece na tela como **R$ 0,00**. Não é bug de
cálculo — o número está certo no banco e certo em memória; quem zera é a formatação.

**Reprodução real** (LiliCalc, 2026-09-13): a lista de insumos mostra o custo por unidade-base.
1 g de açúcar custa R$ 0,0045. O chamador pedia quatro casas:

```tsx
{reais(porUnidade.toFixed(4))}/{i.unidade}      // esperado: R$ 0,0045/g
```

```ts
const MOEDA = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
export function reais(valor) { return MOEDA.format(Number(valor)); }
```

Saída: `R$ 0,00/g`. A tela dizia à confeiteira que **o açúcar é de graça**.

**Por quê:** `style: "currency"` traz `minimumFractionDigits` e `maximumFractionDigits` já definidos
pela moeda — 2 para BRL. O `.toFixed(4)` do chamador produz a string `"0.0045"`, o `Number()`
converte de volta para `0.0045`, e o formatador **arredonda para 2 casas** porque é o que a moeda
manda. O pedido do chamador não é ignorado com aviso: ele é ignorado em silêncio, e o resultado é
um zero plausível.

🔑 **`.toFixed(n)` antes de um formatador de moeda não faz nada.** Ele só produz uma string que será
reconvertida e reformatada. Quem decide as casas é o `Intl`, e ele decide pela moeda, não pelo caso
de uso.

### O conserto

As casas viram parâmetro da função de exibição — e o padrão continua 2, que é o certo para todo
valor que se cobra de alguém:

```ts
const PRECISOS = new Map<number, Intl.NumberFormat>();   // montar Intl é caro; a lista chama por linha

function formatador(casas: number) {
  let f = PRECISOS.get(casas);
  if (!f) {
    f = new Intl.NumberFormat("pt-BR", {
      style: "currency", currency: "BRL",
      minimumFractionDigits: casas, maximumFractionDigits: casas,
    });
    PRECISOS.set(casas, f);
  }
  return f;
}

export function reais(valor, casas = 2) {
  return (casas === 2 ? MOEDA : formatador(casas)).format(Number(valor));
}
```

E os chamadores param de mentir sobre a precisão: `reais(porUnidade, 4)` em vez de
`reais(porUnidade.toFixed(4))`.

### Como achar todos os pontos afetados

`grep` por `toFixed(` **dentro** da chamada do formatador — é a assinatura do erro, porque é o
chamador tentando pedir precisão pelo único caminho que ele conhecia:

```bash
grep -rn "reais(.*toFixed(" app/
```

No caso real havia três, e um deles era condicional (`toFixed(sufixo ? 4 : 2)`), que declara a
intenção de forma ainda mais explícita — e era ignorada do mesmo jeito.

### A ressalva de produto que fica

`R$ 0,0045/g` é honesto e resolve o zero, mas é muita casa decimal para ler correndo. Mostrar por
100 g ou por kg costuma ser mais legível. É decisão de produto, não de formatação — e vale registrar
como dívida em vez de deixar a precisão resolver sozinha um problema de leitura.

### Verbetes relacionados

- [[intl-numberformat-usa-espaco-nao-quebravel-e-quebra-comparacao]]
