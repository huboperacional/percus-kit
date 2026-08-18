## Função de "abandonar/encerrar" duplicada sem os irmãos: grava o status terminal mas esquece a trilha E o estado efêmero associado {#abandonar-duplicado-sem-trilha-e-estado-efemero}

`tags: append-only, trilha de auditoria, estado orfao, pendencia orfa, transacao atomica, funcao
duplicada, UPDATE solto, cleanup path, terminal state, DRY, side effect esquecido, tiatendo,
markAbandoned, order_status_transitions`

**Origem:** tiatendo, 2026-08-02 — dois achados (Pix cobrado sobre pedido `abandoned` sem trilha
nenhuma; saudação "oi" caindo no LLM genérico e alucinando um pedido fantasma) pareciam problemas
diferentes e tinham a MESMA causa raiz.

Um módulo tinha **3 funções que fazem a mesma coisa** — marcar um pedido como `abandoned` — cada
uma escrita em momento diferente por motivo diferente (`draftCleanup.abandonStaleDrafts`,
`nightlyReset`'s sweep, `orderModel.markAbandoned`). As duas mais antigas faziam **3 coisas** na
mesma transação: (1) `UPDATE status='abandoned'`, (2) `INSERT` na tabela de trilha de auditoria
(append-only), (3) `DELETE`/limpeza de qualquer estado efêmero associado (pendência aberta,
sessão em curso) que apontava pro pedido. A terceira função (`markAbandoned`, escrita depois, pra
um caminho de cleanup diferente — caixa/checkout web) fazia **só a primeira**: um `UPDATE` solto.

- **Como os dois sintomas pareciam problemas diferentes:** o achado 1 (dinheiro) mostrava um
  pedido `abandoned` com 0 linhas na tabela de trilha, enquanto os vizinhos tinham 2 cada — lido
  como "falta uma linha de auditoria", um problema de OBSERVABILIDADE. O achado 2 (conversa)
  mostrava uma saudação pura gerando uma resposta alucinada de LLM — lido como um buraco no guard
  de intent-routing, um problema de LÓGICA DE CONVERSA. Nenhum dos dois nomeava "abandonar sem
  limpar o estado associado" até se investigar o CAMINHO (qual função abandonou o pedido? o que
  ela faz e o que ela NÃO faz comparada às irmãs?), não só o SINTOMA.
- **O fio que conectou os dois:** a função sem trilha (`markAbandoned`) também não limpava a
  pendência — e essa pendência órfã (associada a um pedido que já não existe como `draft`) é
  exatamente o que fazia o guard de saudação (que defere pro LLM genérico quando há QUALQUER
  pendência viva não-trivial) rotear pro caminho errado. **A ausência de auditoria e a
  pendência órfã eram o MESMO buraco visto de dois ângulos** — não dois bugs.
- **Como confirmar rápido:** ache TODAS as funções do módulo que escrevem o mesmo status terminal
  (grep pelo valor do enum, ex. `'abandoned'`, `'cancelled'`, `'expired'`). Compare o CORPO delas
  lado a lado — não só a assinatura. A mais nova ou a menos usada costuma ser a que "esqueceu" um
  dos passos que as outras fazem juntas, porque foi escrita depois, isolada, resolvendo só o
  sintoma imediato de quem a criou.
- **Conserto:** reescrever a função faltante pra fazer as MESMAS 3 coisas das irmãs, na MESMA
  transação (não idempotência frouxa — `UPDATE ... RETURNING` como árbitro de que algo realmente
  mudou, e só então `INSERT` trilha + `DELETE` estado efêmero, condicionados ao `RETURNING` não
  vir vazio).
- ⚠️ **"Achar TODAS as funções" é mais estrito do que parece — a instância PARCIAL do bug conta
  também.** No mesmo módulo do tiatendo existe uma 4ª função (`abandonDraftForRestart`) que
  grava a trilha corretamente mas **ainda não limpa** a pendência associada — o mesmo buraco,
  só que pela metade. Não foi corrigida na mesma rodada (o gatilho dela é diferente: dispara no
  MESMO turno em que o cliente já mandou mensagem nova, então a janela de pendência órfã é bem
  mais estreita). Ao comparar os corpos lado a lado, não pare no primeiro "essa não tem os 3
  passos" — confira se as que TÊM os 3 passos realmente os têm todos, ou se alguma tem 2 de 3.

**Relacionado:** [#flag-ja-processei-que-mente] — parente de padrão: os dois casos são uma
única causa raiz produzindo dois sintomas que parecem não-relacionados até alguém seguir o
CAMINHO em vez do sintoma. Aqui a causa raiz é "função irmã incompleta"; lá é "flag que mente".
Também [#discriminador-parcial-reintroduz-bug] — mesma classe ("reusar a lógica da irmã sem
copiar TODOS os passos/ramos"), achada 1 dia depois no MESMO projeto, desta vez num guard de
confirmação de endereço em vez de num cleanup de pedido abandonado.
