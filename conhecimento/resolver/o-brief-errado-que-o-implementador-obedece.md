## O brief errado que o implementador obedece vira defeito; o que ele questiona vira correção {#o-brief-errado-que-o-implementador-obedece}

`tags: subagente, brief, coordenacao, escopo, inventario, fonte de verdade, medicao, autoridade, SDD, orquestracao`

**Contexto:** execução subagent-driven, em que o coordenador escreve um brief por tarefa e o
implementador executa. O brief parece a autoridade — foi escrito por quem tem a visão do plano
inteiro, e o implementador só vê a própria tarefa.

**O problema:** o coordenador erra. Numa execução de 19 tarefas medida em 2026-08-24, **8 dos 15
briefs continham defeito real** — código com bug, número desatualizado, teste que não media o que
o próprio requisito exigia. E **todos** foram achados por quem **leu** o que estava copiando, nunca
por quem copiou.

**O caso que fecha o argumento.** O brief de uma tarefa dizia: *"toast é interface e entra no
escopo"*, mandando externalizar `'Conta a pagar excluída'` e afins. O inventário curado e o README
diziam o contrário: CRUD de operador, fora de escopo. O implementador **seguiu o inventário e parou
para perguntar**, em vez de obedecer ao texto do coordenador.

A medição deu razão a ele: `AccountsTab.tsx:287,390` e `DistributionsPage.tsx:156,214` gateiam as
ações por `isAdmin` — o investidor nunca vê "Nova Conta" nem o botão de excluir, então aqueles
toasts **só disparam para admin**. Se ele tivesse obedecido, teria trazido ~8 strings de superfície
alheia para dentro da fase, e o portão passaria a cobrá-las traduzidas **para sempre**.

**A regra que sai daí, e que vale a pena escrever no brief:**

> O artefato medido (inventário, catálogo, schema) **vence o brief** quando divergirem. Se algo no
> brief não bater com o código, **pare e avise** em vez de decidir sozinho — nos dois sentidos.

**Por que isso não é só "seja cuidadoso":** sem a regra escrita, o implementador que discorda tem
dois caminhos ruins — obedecer contra a evidência, ou divergir em silêncio. O primeiro produz o
defeito com a assinatura do coordenador; o segundo produz uma decisão não registrada que ninguém
revisa. A regra dá um terceiro caminho, e é o único que gera rastro.

**Contraprova de que a regra funciona:** na tarefa seguinte, com a frase já no brief, o
implementador encontrou outra divergência (o brief prometia `aria-label` de duas ações, o inventário
tinha uma) — mediu que a segunda ação só renderiza sob `canEdit=true`, que nunca ocorre na tela em
questão, e **não** criou entrada. Decisão certa, registrada, sem custar rodada.

**Sinal de que você está no caso:** o brief afirma uma classificação (*"isto é interface"*, *"isto é
do usuário X"*) que só se sustenta se um gate de autorização ou de renderização se comportar de um
jeito específico — e ninguém foi conferir esse gate.

Ver também [[a-sabotagem-prova-o-que-voce-imaginou]].
