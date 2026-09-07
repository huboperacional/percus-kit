## Review que LÊ o diff acha uma fração do que review que EXECUTA o código acha — e a suíte verde não cobre a diferença {#review-que-le-acha-menos-que-review-que-executa}

`tags: code review, revisao adversarial, executar o codigo, suite verde, falso negativo, subagente revisor, vite-node, medicao, R11, R23`

**Origem:** Paid Media Automation, 07/09/2026 — frente `0-ANUNCIOS-RESUMO`, 4 passadas de review
sobre ~8.900 linhas escritas por dois agentes em paralelo contra um contrato compartilhado.

**A medição, no mesmo código:**

| passada | método | achados |
|---|---|---|
| 1ª | leu o diff | **2** (1 bug de cor, 1 preferência) |
| 2ª, 3ª, 4ª | **executaram** o código com entradas reais | **11**, incluindo 6 bloqueantes |

E o código que passou pelas quatro tinha, o tempo todo: **394 testes verdes, `tsc` limpo, `eslint`
zerado e mutantes provados mortos**. A suíte não pegou nenhum dos seis bloqueantes.

**O que "executar" significa na prática.** O revisor não precisou de ambiente completo: montou um
harness fora do repo (`vite-node`/`vitest` com `root` apontando para a árvore), chamou a função de
montagem do payload com entradas construídas à mão, e **leu a saída**. Exemplos do que só apareceu
assim:

- `moedaExibida` vindo de uma variável e o VALOR de outra: lendo, as duas linhas parecem
  coerentes; executando com `fx: null`, saiu `"≈ US$ 13.005,58"` para um gasto de **US$ 2.408,44**.
- Delta calculado em BRL com valor exibido em USD: lendo, cada linha está certa; executando duas
  janelas com o mesmo gasto nativo e PTAX diferente, saiu **"US$ 700 / US$ 700 / ↑20% em
  vermelho"**.
- Manchete acusando o cliente: lendo, a condição `naoColetadas > 0 && noAr === 0` parece cobrir;
  executando com todas as campanhas pausadas, o estado `NAO_COLETADO` nunca nasce (regras
  anteriores retornam antes) e a caixa vermelha volta.

🔑 **Por que a leitura falha sistematicamente aqui:** ler verifica que cada trecho **diz** a coisa
certa. Os defeitos caros moram na **composição** — duas partes individualmente corretas que, juntas,
produzem um número errado. Composição não se lê, se executa.

⚠️ **E por que a suíte também não pega:** os testes foram escritos pelos mesmos agentes que
escreveram o código, contra o mesmo entendimento. Eles cobrem os ramos que o autor imaginou. O teste
que existia para o cenário do bug de 5,4x montava o setup certo (BRL+USD, display USD, PTAX 5,4) e
**parava uma asserção antes de olhar um valor**.

**Como aplicar:**
1. Em review de código que produz NÚMERO para consumo humano, exija do revisor **a saída medida**,
   não a análise. "Executei X com a entrada Y e saiu Z" vale mais que três parágrafos de leitura.
2. Peça o harness fora do repo, para o revisor não sujar a árvore e não ser tentado a "consertar".
3. Trate "suíte verde / tsc limpo / mutantes mortos" como **pré-requisito**, nunca como evidência de
   correção. São afirmações sobre o que foi imaginado, não sobre o que o sistema faz.
4. Quando o revisor citar linha e cenário mas não a saída, peça a saída. Foi assim que um achado
   "confirmado" da rodada 1 se revelou fechado pela metade na rodada 2.

Relacionado: [[duas-fontes-para-a-mesma-verdade]], [[gate_must_seen_failing]],
[[postgres_real_com_dado_sintetico_nao_e_dado_real]].
