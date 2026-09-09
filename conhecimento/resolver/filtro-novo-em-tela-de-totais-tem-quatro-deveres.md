## Filtro novo em tela de totais tem quatro deveres {#filtro-novo-em-tela-de-totais-tem-quatro-deveres}

tags: honestidade-de-dado, filtro, url, print-para-cliente, review

**Classe de sintoma:** a tela ganhou um seletor (canal, conta, período) e passou a mostrar um número
CERTO para o recorte e ERRADO para quem lê sem saber do recorte. Nenhum teste reprova: cada número,
isolado, bate com o banco.

Medido em 2026-09-09 na tela *Anúncios · Resumo* (Paid Media Automation), ao pôr o seletor
Todas · Google · Meta na linha das abas. A implementação estava "certa" pelos 9 gates escritos antes
do código, e o conselho + três rodadas de review R11 acharam quatro defeitos — todos da família
*duas fontes para a mesma verdade que divergem*, e um deles no TEMPO, não no espaço.

### Os quatro deveres

| dever | o que estava errado | o que passou a valer |
|---|---|---|
| **1. Declarar o filtro onde o print mostra** | "só Google" só na faixa técnica, dentro de uma sanfona fechada por padrão — invisível no print | a declaração vai no bloco que ABRE a tela (etiqueta ao lado do título dos totais), além do payload (`escopo.canal`) e da faixa |
| **2. Bloco que NÃO segue o filtro diz isso** | leads do nosso tracking (população diferente) apareciam sob o botão "META" como se fossem da Meta | ressalva em texto, só quando há filtro ativo — aviso sem causa é ruído |
| **3. "Ausente" ≠ "presente e inválido"** | o parser do toggle cai em "Todas" para qualquer lixo (`?platform=google`); a API responde 400 ao mesmo valor e a UI respondia "Todas" em silêncio | a moldura testa `get("platform") !== null` junto com o fallback e mostra erro sem buscar |
| **4. Trocar o filtro descarta o payload velho AGORA** | o hook refazia o fetch mas só substituía `dados` na resposta: botão META pressionado sobre totais de Google por segundos | `setDados(null)` no instante em que a URL muda (ref da URL anterior); recarregar a MESMA URL pode manter o número |

### Por que o gate normal não pega

- O dever 1 exige **definir "print"** na spec: *a página como renderizada, capturada em imagem, sem
  hover, sem clique, sanfonas fechadas*. Sem isso "a tela declara o filtro" é verdade e inútil.
- O dever 4 vive **entre** o clique e a resposta. Gate: `fetch` mockado devolvendo uma Promise que
  nunca resolve na segunda chamada + `rerender` com o parâmetro novo; afirma o que está e o que NÃO
  está na tela antes da resposta. Escreva o par invertido: "trocar descarta" e "reler mantém".
- Escopo vazio por **interseção** de filtros (`platform=GOOGLE&contas=<conta Meta>`) não é "o
  cliente não tem conta Google": nomeie o conflito, reserve a frase de ausência para a ausência real.

### Como aplicar

Ao adicionar QUALQUER filtro a uma superfície de totalização que vira relatório, passe os quatro
deveres antes de chamar de pronto — e recalcule no servidor a partir das entidades filtradas, nunca
filtrando um agregado já somado (a cobertura depende de quem entra no denominador).

Relacionado: [ausência de medição envenenando número medido](ausencia-de-medicao-envenena-numero-medido.md),
[spec antes de tela](../fazer/spec-antes-de-tela-senao-o-review-nao-tem-contra-o-que-comparar.md).
