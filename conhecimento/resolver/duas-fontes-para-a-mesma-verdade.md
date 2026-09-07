## "Duas fontes para a mesma verdade" é uma FAMÍLIA de defeito — ache uma e procure as outras cinco {#duas-fontes-para-a-mesma-verdade}

`tags: familia de defeito, invariante, fonte unica, divergencia, rotulo e valor, indice e arvore, fixture e producao, regua duplicada, irrepresentavel, R23`

**Origem:** Paid Media Automation, 07/09/2026 — frente `0-ANUNCIOS-RESUMO`. Quatro passadas
adversariais, **seis defeitos bloqueantes, e todos a mesma forma**.

**A forma.** Dois lugares do sistema afirmam o mesmo fato. Enquanto concordam, ninguém percebe que
são dois. Quando divergem, o sistema fica internamente inconsistente — e o pior é que **cada metade
continua correta isoladamente**, então nenhum teste unitário acusa.

**As seis ocorrências, no mesmo código, para você reconhecer a forma:**

| o fato | fonte A | fonte B | o que saiu |
|---|---|---|---|
| moeda do gasto | valor convertido no servidor | rótulo lido de outra variável | "≈ US$ 13.005" para US$ 2.408 (**5,4x**) |
| variação do gasto | valor exibido em USD | delta calculado em BRL | "US$ 700 / US$ 700 / **↑20%**" |
| conversão aplicada | `approx` de uma chamada | valor de outra chamada | número 16,7% errado **sem** marca de aproximação |
| houve cobertura? | medida real dos dias | **proxy**: estado da campanha | manchete vermelha acusando o cliente pela nossa falha |
| pode comparar? | régua do total | régua da campanha | "↘29%" e "—" no mesmo print |
| intervalo da janela | `intervaloDaJanela()` | 5ª superfície montando à mão | "nenhuma semana fechada até 06/09" (fechou em 06/09) |

E fora do código, no mesmo dia, a mesma forma: **árvore de trabalho × índice do git** (o `commit`
publicaria uma rodada de correção anterior), e **fixture × servidor** (a UI só era vista renderizando
um payload que o servidor não consegue produzir).

**Como caçar, depois de achar a primeira.** A pergunta é sempre: *este fato é derivado ou copiado?*
Procure especificamente:
- **rótulo separado do valor** (unidade, moeda, data, escala) — o rótulo tem de sair do MESMO objeto
  que produziu o número;
- **um agregado e um detalhe** que deveriam fechar (total × soma das partes);
- **um proxy** — "infiro X pelo estado de Y" é sempre uma segunda fonte, e ela diverge quando Y ganha
  um caminho novo;
- **a mesma regra escrita duas vezes** em níveis diferentes (item × total, dia × semana);
- **um helper criado para ser "porta única"** — verifique se TODAS as superfícies passam por ele; a
  que escapa costuma ser a do caso raro, que é onde o defeito aparece;
- **fixture / mock** que representa um estado que o produtor real não emite.

🔑 **O conserto que funciona não é corrigir a divergência — é tornar a segunda fonte
irrepresentável.** Foi o que fechou a frente, e a diferença é visível:

```ts
// antes: dois argumentos, e dava para reescolher errado
valorDeGasto(dia, moeda)          // → moeda.aproximado ? dia.spendBrl : dia.spendNative
// depois: um argumento; reescolher não tem como ser escrito
valorDeGasto(fonte: { spendExibido: number | null })
```

Outros três do mesmo lote: `lerEntrega` passou a exigir a cobertura MEDIDA como 3º argumento
**obrigatório** (o compilador força todo chamador a medir em vez de inferir); `compararJanelas`
consulta a régua ANTES da aritmética e devolve tudo `null` (o payload não consegue carregar
"não comparável" junto com um número); e o motivo de cada ausência passou a nascer do MESMO par que
a divisão consumiu.

⚠️ **Corrigir a metade errada é o modo de falha desta família.** Uma rodada moveu a conversão para o
servidor (o VALOR) e deixou o RÓTULO vindo de outra variável — o defeito voltou inteiro, por outra
porta, agora com o número errado nascendo mais cedo. Ao consertar, pergunte **qual das duas fontes
morre**; se as duas continuam vivas, você não consertou, só realinhou.

Relacionado: [[review-que-le-acha-menos-que-review-que-executa]],
[[indice-do-git-e-uma-terceira-fonte-da-verdade]], [[mock_mirrors_bug]].
