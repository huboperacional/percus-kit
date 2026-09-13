## Dado inicial que só o seed cria nunca chega em conta real, e a conta de dev esconde isso para sempre {#dado-inicial-que-so-o-seed-cria-nunca-chega-em-conta-real}

`tags: seed, onboarding, primeira tela vazia, conta nova, cadastro, webhook, funil, prisma, dado de partida, conta de desenvolvimento, R23`

**Sintoma:** quem se cadastra abre a tela principal do produto e encontra um `<select>` com só
"Escolha…" atrás, ou uma lista vazia sem caminho de saída. Nada erra, nada loga, nada quebra — o
produto simplesmente não faz nada, e a pessoa vai embora achando que está quebrado.

**Reprodução real** (LiliCalc, 2026-09-13): a calculadora nasce com 12 insumos de partida (farinha,
açúcar, leite condensado…) para a confeiteira não encarar tela em branco. A lista morava em
`prisma/seed.ts`:

```ts
// prisma/seed.ts — roda contra UMA conta, a de desenvolvimento
const conta = await db.conta.upsert({ where: { email: "lili@…" }, … });
for (const i of INSUMOS_INICIAIS) await db.insumo.create({ data: { ...i, contaId: conta.id } });
```

E a criação de conta de verdade era outra coisa, noutro arquivo:

```ts
// lib/licenca/repositorio.ts — o caminho que TODA conta real percorre
const conta = await cliente.conta.create({
  data: { email, config: { create: {} } },   // config sim, insumos não
});
```

Resultado: **toda conta real nascia com estoque zero** — tanto o cadastro gratuito quanto a compra
paga pelo webhook. O seed nunca tocou nenhuma delas.

### Por que ninguém vê durante meses

A conta de desenvolvimento tem os 12 desde o primeiro `npm run seed`. Todo teste manual, todo
screenshot, toda demonstração acontece **logada nela**. O caminho quebrado é justamente o único que
o time nunca percorre: criar uma conta nova e olhar a primeira tela com os olhos de quem chega.

Mais cruel: no caso real o comentário do próprio `seed.ts` dizia

> "a tela vazia no primeiro acesso é onde estes produtos perdem o usuário"

A percepção estava certa e escrita. Ela só nunca chegou no código que cria conta de verdade.

🔑 **Seed é ferramenta de desenvolvimento, não regra de produto.** No instante em que um dado de
partida vira promessa ao usuário ("você já começa com os básicos"), ele deixa de pertencer ao seed
e passa a pertencer ao caminho de criação de conta. Enquanto morar só no seed, ele é uma promessa
que só o time recebe.

### O conserto que resolve a classe

1. **Uma fonte só**, num módulo que não seja o seed:

```ts
// lib/insumos-iniciais.ts
export const INSUMOS_INICIAIS = [...] as const;
```

2. **O seed passa a ler dela** — vira um consumidor, não o dono.

3. **A criação de conta cria o dado junto, no mesmo `create`:**

```ts
const conta = await cliente.conta.create({
  data: { email, config: { create: {} }, insumos: { create: [...INSUMOS_INICIAIS] } },
});
```

Aninhar em vez de fazer dois passos não é estilo: conta que exista sem o dado, **ainda que por um
instante**, é uma conta que a pessoa pode abrir — e o que ela encontra é a tela vazia.

4. **Backfill para quem já entrou.** O código novo só serve para quem chegar depois; quem já está
   dentro continua no beco até um script idempotente passar:

```ts
const vazias = await db.conta.findMany({ where: { insumos: { none: {} } }, select: { id: true } });
```

`{ none: {} }` é o filtro certo — "conta sem nenhum insumo" —, e restringir a ela é o que torna o
script seguro para rodar duas vezes.

### O teste que pega isto sem banco

O caminho quebrado é uma **chamada**, não um cálculo, então o teste barato é injetar um cliente
falso e afirmar o formato do pedido:

```ts
await repositorioPrisma(clienteFalso, ctx).criarConta("nova@x.com");
expect(criadas[0].data.insumos.create).toHaveLength(INSUMOS_INICIAIS.length);
```

Ele prova a intenção, não o resultado contra o schema real — a lacuna se fecha criando **uma conta
do zero no navegador** e olhando a primeira tela. Faça isso uma vez por release; é o único teste
que enxerga esta classe.

### Onde mais essa classe mora

Qualquer coisa "que já vem pronta" e é criada por script: categorias padrão, templates iniciais,
papéis, configuração default, tags de exemplo, primeiro projeto. A pergunta que revela todas é a
mesma: **quem cria isto quando ninguém roda o seed?**

### Verbetes relacionados

- [[seed-parcial-parece-sucesso-conte-as-linhas]]
- [[o-seed-que-so-roda-uma-vez-por-container]]
