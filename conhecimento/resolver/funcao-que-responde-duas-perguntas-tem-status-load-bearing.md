## Função que responde DUAS perguntas tem o `status` load-bearing — melhore a FALA, não o veredito {#funcao-que-responde-duas-perguntas-tem-status-load-bearing}

`tags: matcher, guarda, status, load-bearing, consumidor oculto, alargar matcher, regressao em massa, teste pinado, residuo deliberado, conselho nao ve a suite, R23`

**Sintoma:** existe uma pendência antiga descrevendo um caso que "obviamente deveria casar"
(`"uma coca gelada"` → `no_match`). O conserto parece ser um alargamento de uma linha no
resolvedor. Ao implementar, **30 testes caem de uma vez**, em famílias que nada têm a ver com a
frente — endereço, preservação de carrinho, um call site de outra feature.

**Causa raiz:** a função tem **mais de um consumidor perguntando coisas diferentes**. No caso
medido (tiatendo, `matchItems`, 2026-08-22) ela responde:

1. *"dá pra vender isto?"* — caminho do PEDIDO;
2. *"o cliente estava falando de COMIDA?"* — guarda do passo do ENDEREÇO.

O `no_match` era a resposta **negativa das duas**. Alargá-lo para o consumidor 1 fez `"Rua Coca"`
(uma RUA) virar comida para o consumidor 2 — e naquele fluxo 3 tentativas de bairro contadas como
falha **pausam o bot**. O ganho era cosmético; o dano, operacional.

**Três sinais que aparecem ANTES do vermelho, e que dá para ler de graça:**
- **Teste com nome de resíduo PINADO** (`test_..._residuos_PINADOS_..._sobrevivem_ao_fix`, docstring
  *"pinados desde <data> — X não pode movê-los"*). Isso não é dívida: é **decisão registrada**. A
  pendência que você está lendo pode ser o resíduo **deliberado** de outra frente.
- **Teste cujo nome contém a palavra TRAVA** (`test_..._status_no_match_e_a_TRAVA`).
- **Um `ACHADO` escrito no teste** endereçado a quem viesse depois. No caso real ele dizia,
  textualmente, *"quem for implementar a fala tem de escopá-la ao caminho do PEDIDO"* — a solução
  inteira estava escrita meses antes, dentro do arquivo de teste.

**Solução — o conserto correto é ADITIVO e mora na FALA:**
- o resolvedor publica um campo **novo** ao lado (`repescado_options`), e o `status` **não muda**;
- a melhoria vive no renderizador do **consumidor específico** que você quer melhorar, verificando
  antes que ele não é alcançado pelo outro consumidor (no caso: a função de fala tinha os dois call
  sites dentro do mesmo `_collect`, ou seja, caminho do pedido, e só);
- um teste `TestOStatusNaoSeMove` guarda a versão errada de voltar.

**Por que o conselho não pega isto:** conselho lê **prosa**. Três rodadas (duas com 3/3 pernas
usáveis) aprovaram o desenho, porque o contra-caso não estava no texto — estava na **suíte**. Irmão
direto de [#conselho-aprovou-desenho-que-um-teste-existente-derruba].

**E cuidado com a medição "das duas direções":** a regra de
[#alargar-matcher-de-guarda-troca-miss-por-alvo-errado] foi aplicada corretamente **e ainda assim
não pegou** — os 12 controles negativos eram todos do domínio de COMIDA, e o consumidor lesado era
o de ENDEREÇO. 🔑 **A pergunta não é "o que mais pode casar errado?", é "QUEM MAIS lê esta saída?"**
Enumere os consumidores (`grep` pelo nome do campo/status) **antes** de escolher os controles
negativos; o controle negativo tem que vir do domínio de cada consumidor, não do seu.

**Procedimento barato que teria evitado tudo:** rodar a suíte contra um espinho de 3 linhas do
desenho **antes** de escrever a spec. Custo: 4 minutos. Custo real pago: spec inteira + duas
rodadas de conselho + implementação, todas jogadas fora.

**Ref:** tiatendo, N33, 2026-08-22. Commit `9048175`. Irmãos:
[#alargar-matcher-de-guarda-troca-miss-por-alvo-errado],
[#conselho-aprovou-desenho-que-um-teste-existente-derruba],
[#a-porta-onde-o-estado-morre-nao-e-a-porta-do-defeito]. R23.
