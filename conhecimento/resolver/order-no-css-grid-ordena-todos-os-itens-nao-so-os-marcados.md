## `order` no CSS Grid ordena TODOS os itens, e quem não foi marcado vale 0 e passa na frente {#order-no-css-grid-ordena-todos-os-itens-nao-so-os-marcados}

`tags: CSS Grid, order, flexbox, tailwind, lg:order, colunas trocadas, responsivo, mobile first, layout quebrado, R23`

**Sintoma:** você marca **um** item com `order` para mandá-lo para a outra coluna no desktop, e as
duas colunas trocam de lado — o item que você nem tocou é que foi parar onde você queria o marcado.

**Reprodução real** (LiliCalc, 2026-09-13): lista larga à esquerda, formulário estreito à direita.
No celular o formulário vem primeiro (a primeira visita é tela vazia, e o formulário é a única
saída), então ele é o primeiro no DOM. Para invertê-los no desktop, bastava marcar a lista:

```tsx
<div className="grid lg:grid-cols-[1fr_20rem]">
  <Cartao titulo="Nova ficha">…</Cartao>        {/* sem order → order: 0 */}
  <Pilha className="lg:order-1">…lista…</Pilha> {/* order: 1 */}
</div>
```

Resultado no desktop: o **formulário** ocupou a coluna `1fr` (a larga) e a **lista** ficou espremida
nos `20rem`. Exatamente o contrário do pedido.

**Por quê:** `order` não é "mova este item". É uma chave de ordenação aplicada ao conjunto inteiro,
e o valor inicial de todo item é `0`. Um item sem `order` não fica parado — ele participa da
ordenação valendo zero, e **zero vem antes de um**. Ao marcar só a lista com `order-1`, você não a
moveu para a frente: mandou-a para trás do formulário.

🔑 **`order` só é previsível quando todos os itens do container têm valor.** Marcar um item é
sempre implicitamente marcar os outros com 0 — a diferença é que você não escreveu isso, então não
lê no código.

### O conserto

Marque os dois lados, explicitamente, e o código passa a dizer a ordem que ele produz:

```tsx
<Cartao className="lg:order-2">…formulário…</Cartao>
<Pilha  className="lg:order-1">…lista…</Pilha>
```

Alternativa igualmente válida: **não usar `order`** e reordenar o DOM, aceitando a ordem do celular
como a ordem "real". Só não fique no meio do caminho — um item marcado e outro não é a configuração
que engana.

### Como isto passou pela revisão

O diff parecia certo: havia um `lg:order-1` e ele estava no elemento que deveria ficar à esquerda.
Só a **tela aberta na largura certa** mostrou o resultado. É o tipo de defeito que nenhum teste de
unidade e nenhuma leitura de diff pega, porque o erro não está no que foi escrito — está no que não
foi.

### Verbetes relacionados

- [[css-grid-autofit-estica-item-unico]]
- [[colunas-fixas-prometem-fileira-inteira-para-um-total-so]]
