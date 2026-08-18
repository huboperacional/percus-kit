## Flag de "já processei" que mente produz PERDA e DUPLICAÇÃO ao mesmo tempo — e uma esconde a outra {#flag-ja-processei-que-mente}

`tags: idempotencia, _preSaved, pre-salvo, duplicata, mensagem perdida, webhook, batch, pipeline inbound, persistencia, contrato de flag, defeitos de sinais opostos`

**Sintoma:** você investiga "o item X não é gravado" e a contagem no banco parece desmentir a
suspeita (há linhas de X, então "não perde"). Meses de dados dizem que está tudo bem. Ao mesmo tempo,
ninguém reclama de duplicata — porque duplicata não dispara alarme: o total fica ALTO, a lista parece
completa, e nenhum contador acusa falta.

**Causa raiz:** um flag booleano do tipo `_preSaved` / `alreadyHandled` / `processed` cujo CONTRATO
("este item já está persistido") não é honrado nas duas pontas:
1. quem **carimba** o flag o faz incondicionalmente, mas só persiste um subconjunto
   (ex.: `if text:` — então o item sem texto é marcado como salvo sem ter sido) → **PERDA**;
2. quem **deveria ler** o flag não lê (ex.: gates que gravam "pra trilha de auditoria") → **DUPLICAÇÃO**.

Os dois defeitos têm a MESMA raiz e sinais opostos, então se cancelam na hora de procurar: quem
duplica parece não ter perdido nada, e é por isso que a suspeita original nunca fecha.

**Solução:**
- Teste as DUAS direções no mesmo commit: o caso em que o flag mente pra mais (perde) e o caso em que
  quem deveria lê-lo não lê (duplica). Um teste só deixa o outro defeito passar.
- Faça quem carimba persistir TUDO que é persistível (não só o caminho feliz), e todo ponto de escrita
  ler o flag antes de escrever e carimbá-lo depois.
- **A metadata é o melhor delator de autoria.** Quando a mesma chave lógica aparece 2×, compare a
  metadata das duas linhas: o formato de cada uma aponta o arquivo que a escreveu. Foi assim que os 5
  pontos de escrita apareceram, sem ler o código todo.
- Consulta que acha o defeito sem saber onde ele está (janela + `lag`):
  `lag(content) OVER (PARTITION BY <conversa> ORDER BY created_at)` e filtrar
  `content = prev_content AND created_at - prev_at < interval '5 seconds'`; agrupe **por mês** pra
  saber se é defeito VIVO ou fóssil de uma era antiga do sistema.

**Armadilha ao consertar:** se "não há nada a persistir" (evento de protocolo, payload vazio), o flag
deve ficar **True** — "não sobrou nada pra jusante gravar". Marcá-lo False por "honestidade" faz cada
evento vazio virar uma linha placeholder FANTASMA, porque o save a jusante costuma ser
`conteudo or "[placeholder]"`. O contrato certo é "não há pendência", não "eu gravei".

**Ref:** tiatendo `0.259.0` (2026-07-29) — 3711 pares idênticos com o mesmo `messageId`, 54 em julho;
`execution/webhooks/inboundPipeline.py`, `execution/core/messageRouter.py` (5 pontos de save),
`tests/test_inboundPersistenceContract.py`.
