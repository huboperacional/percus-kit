## A R10 roteia por TIPO — só tela nova em alta fidelidade espera o operador {#r10-roteia-por-tipo-nem-toda-tela-espera-o-operador}

`tags: R10, design, v0.dev, shadcn, wireframe, mermaid, excalidraw, iteracao sobre tela existente, bloqueio inventado, trabalho parado, gate de design, R23`

**Sintoma.** O agente escreve "essa frente está travada pelo R10 / sem design aprovado", e o trabalho para. Dias depois alguém lê a regra literal e descobre que **aquele caso específico nunca precisou do operador** — o item ficou parado por uma frase larga demais, não por um gate.

**Causa raiz.** A R10 não diz "espere design". Ela **roteia por tipo de pedido**, e só um dos quatro caminhos passa pelo humano:

| Tipo | Ferramenta | Quem faz |
|---|---|---|
| Componente isolado (button, card, modal, form) | **shadcn MCP** (skill `vercel:shadcn`) | o agente |
| **Iteração sobre tela existente** | edição local + `npm run dev` | o agente — a regra diz literalmente *"sem custo de mockup; o loop de feedback é a tela real"* |
| Diagrama / wireframe | **Mermaid** ou **Excalidraw** | o agente — versionável, sem dependência externa |
| **Tela/fluxo novo, alta fidelidade** | **v0.dev** | **o operador** — browser próprio, créditos próprios |

Empacotar os quatro numa frase só (*"é visual, então é dele"*) transforma uma regra de roteamento num bloqueio inventado.

**Caso medido (2026-09-07/08).** Duas frentes tinham sido declaradas "travadas por design". Ao ler a regra:

- **Lançar peça no orçamento** era *seção dentro de uma tela que já existe* (`TelaOrcamentoEditor`, 1.263 linhas). Era iteração — construída no mesmo dia, em componente isolado para manter a mudança na tela grande em duas linhas.
- **Visão consolidada** era tela **nova de verdade** (nenhuma das 5 telas existentes a mostrava). Essa sim exige v0.dev — e mesmo nela o agente entrega **wireframe + brief versionados**, para a sessão do operador começar decidida em vez de partir do zero.

**Como aplicar.**

1. Antes de escrever "travado por design", responda: *isto é tela NOVA, ou seção dentro de tela que já existe?* Meça — `ls` nos componentes e nas rotas do app, não memória.
2. Se for iteração, construa. Se for componente isolado, shadcn.
3. Se for tela nova mesmo, **não pare**: entregue o wireframe e o brief, que a R10 lista como suas ferramentas, e passe ao operador só o que exige o navegador dele.
4. ⚠️ Entregar a tela **não** dispensa a prova: `tsc` verde não é tela renderizada. Se o critério do projeto exige screenshot para entrega de tela, a marca não sobe sem ele — declare a lacuna em vez de arredondar.

Anti-padrão do outro lado: começar a codar "uma tela nova rapidinha" sem mockup, ou esperar o Claude artifacts voltar quando v0.dev/shadcn resolvem.
