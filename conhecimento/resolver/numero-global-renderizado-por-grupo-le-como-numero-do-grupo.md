## Número GLOBAL renderizado dentro de cada grupo lê como número DO grupo — e o leitor soma {#numero-global-renderizado-por-grupo-le-como-numero-do-grupo}

`tags: ui, tabela, agregacao, aviso, duplicacao, leitura, dashboard, smoke, dado-real, R23`

**Sintoma:** um aviso correto, com um número correto, mentindo. Medido em 31/08/2026 no Relatório de
Vendas: a linha *"79 campanha(s) sem conta cadastrada"* aparecia dentro do grupo `PAID_SOCIAL` **e**
dentro do grupo `PAID_SEARCH`. Os dois 79 eram o mesmo 79 — a contagem é do CLIENTE inteiro. Quem lê
uma tabela agrupada soma o que está dentro de cada grupo: **158**.

**Causa raiz:** o JSX que emite o aviso mora dentro do `map` dos grupos, condicionado a algo que é
verdade em mais de um grupo (`grupo.linhas.some(l => l.semConta)`), mas o VALOR que ele imprime vem
de fora do grupo (`campanhasOrfas.length`, que é global). Escopo do laço ≠ escopo do dado. O
componente está "certo" em cada iteração e errado no conjunto.

**Correção:** o aviso sai UMA vez, no escopo a que o número pertence, e o texto **diz** de que
escopo ele é:

```tsx
{/* fora do map dos grupos, no fim da seção */}
{campanhasOrfas != null && todas.some((l) => l.semConta) && (
  <p>
    {campanhasOrfas.length} campanha(s) do CLIENTE INTEIRO não existem em nenhuma conta
    cadastrada — é a mesma lista do aviso no topo, não um número por grupo.
  </p>
)}
```

Nomear o escopo dentro da frase é o que sobrevive a alguém mover o bloco de novo.

**O gate que pega** precisa de **DOIS grupos** na fixture — com um só, o defeito não existe:

```tsx
montar({ nodes: [fonte({ source: "PAID_SEARCH", ... }), fonte({ source: "PAID_SOCIAL", ... })], campanhasOrfas: ["c1","c2","c3"] });
const ocorrencias = texto().split("3 campanha(s) do cliente inteiro").length - 1;
expect(ocorrencias).toBe(1);
```

**A lição maior:** nenhum teste de fixture pequena ia ver isso, porque fixture pequena tem **uma**
unidade de agrupamento. Foi o smoke em produção, com dado real de um cliente que tem duas plataformas
pagas, que mostrou. Quando a tela agrega, **a fixture do gate precisa de pelo menos duas unidades do
nível que agrega** — senão o teste prova só que uma linha renderiza.

Parente de [[agregado-nao-e-componente]] e de
[[medicao-uniforme-na-populacao-inteira-e-bug-da-medicao]]: número certo, escopo errado.
