## Aviso no topo NÃO neutraliza tabela acionável abaixo — corrigir recomendação errada é editar o número {#aviso-no-topo-nao-neutraliza-tabela-acionavel-abaixo}

`tags: documento de cliente, relatorio, correcao, recomendacao, tabela, gate cross-documento, duas fontes da verdade, R23, entrega`

**Sintoma:** uma análise entregue ao cliente se prova errada. O reflexo é **anexar uma ressalva no
topo** ("esta leitura foi corrigida, veja a versão nova") e seguir em frente. Semanas — ou horas —
depois, alguém abre o documento, rola até a tabela e **age pelo número antigo**, que continua lá,
específico e acionável.

**Caso real (Paid Media, 2026-09-07).** Uma remedição derrubou a régua que sustentava um plano de
mídia: a recomendação de cortar 94% da verba de uma conta vinha de um custo por reunião que era
artefato de medição. Refiz a estratégia na leitura nova (v3) e pus um **aviso de correção no topo**
das leituras antigas (v1 e v2). Duas horas depois o operador abriu a v1, rolou até a seção de
detalhamento e perguntou: *"não mudamos nossa sugestão de acoplamento de verba?"* — a tabela ainda
dizia `EUA US$ 20.420` e `Brasil −94%`, **com drill-down por campanha**. As duas páginas propunham
verbas diferentes para o mesmo cliente, que as abre com a mesma senha.

**Causa raiz:** o leitor de um documento de decisão não lê para se informar — lê para **executar**.
Ele vai direto ao número que diz o que fazer. Um aviso no topo compete com a tabela pela atenção e
perde, porque a tabela é o que ele veio buscar. Quanto mais concreto o número (valor por conta,
variação percentual, lista de campanhas), mais forte ele é do que qualquer prosa acima dele.

**Como corrigir de verdade:**

1. **Edite o número, não anexe ressalva.** O documento antigo passa a propor o que se propõe hoje.
   Uma verba, uma proposta — em todas as leituras.
2. **Mantenha a distinção entre o que mudou e o que não mudou.** No caso, o cenário em nível de
   frente (Marca/Geração/Meta) continuava válido; o que mudou foi a repartição por conta e o
   caminho. Dizer isso explicitamente evita jogar fora o que ainda serve.
3. **Marque o número contaminado onde ele ainda aparece.** Se o documento continua exibindo a
   métrica que produziu a recomendação errada (por comparação histórica), ela vai com marca
   visível — publicá-la limpa repete o erro.
4. **O aviso no topo fica** — mas como explicação do *porquê*, não como neutralizador do número.

**O gate que fecha (a parte que impede a reincidência):** quando dois documentos publicam a mesma
decisão, um teste tem de comparar os dois. No caso, o `dados.json` da v1 é preenchido **à mão** e a
v3 **deriva** a alocação de um módulo — então o gate lê o JSON e confere contra o módulo: totais,
soma das linhas, envelope, conta a conta, o que um zera e o outro tem de zerar, e a ausência do
texto da recomendação antiga. **Visto reprovando com a alocação antiga (7 falhas)** antes de passar
com a nova.

```ts
const GERACAO = tabela("Geração (Google)");   // por TÍTULO, nunca por índice
it("cada conta recebe na v1 o mesmo valor que a v3 deriva", () => { … });
it("o que a v3 zera, a v1 zera", () => { … });
it("o documento não promete mais o corte antigo", () => { … });
```

⚠️ Duas armadilhas no próprio gate, as duas apontadas por review cross-provider:
- **localizar bloco por índice** (`blocos[1]`) passa calado se o documento ganhar um bloco antes —
  valida a tabela errada e reprova nada. Localize por título, e exija exatamente uma correspondência.
- `toBeCloseTo(x, -1)` não é contrato suportado (espera dígitos ≥ 0). Para dinheiro, tolerância
  explícita: `expect(Math.abs(a - b)).toBeLessThan(1)`.

**Teste de bolso antes de dar por corrigido:** abra o documento como o cliente abre, role até a
tabela e leia **só ela**. Se o que está lá ainda manda fazer o que você acabou de desaconselhar, a
correção não aconteceu.

Ver [[carimbo-quebrado-inverte-a-regua-nas-duas-pontas]].
