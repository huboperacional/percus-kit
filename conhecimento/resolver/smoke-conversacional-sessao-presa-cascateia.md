## Smoke test conversacional (webhook + estado de sessão de bot): mandar a próxima mensagem sem confirmar o estado via poll() cascateia falso-negativo {#smoke-conversacional-sessao-presa-cascateia}

`tags: smoke test, bot conversacional, webhook, whatsapp, estado de sessão, confirmation state, poll, falso negativo, cascata, teste em produção`

**Contexto:** smoke test que injeta mensagens sequenciais REAIS (assinadas HMAC) contra um bot
conversacional em produção, onde o bot usa uma máquina de estados de sessão (`CONFIRMATION_STATES`
ou equivalente) — comum em bots de criação-com-confirmação (WhatsApp, etc.) que perguntam um dado
faltante antes de confirmar.

**Sintoma:** um cenário do meio do script (ex.: "testar recusa de confirmação") falha, e TODOS os
cenários seguintes do mesmo script também falham, com uma resposta genérica/de erro repetida
("não entendi", menu de desambiguação) que não tem nada a ver com o que cada mensagem pedia.
Parece bug de produto generalizado, mas só o primeiro cenário tem causa real.

**Causa raiz:** o script assumiu que uma mensagem de setup levaria a sessão a um estado específico
(ex.: "confirmando_X", pronto pra receber sim/não), sem checar isso via `poll()` antes de mandar a
próxima mensagem. Na prática a mensagem de setup não tinha sinal suficiente (ex.: faltava uma
keyword que o extrator de intent precisa) e o bot foi pra um estado DIFERENTE (ex.: "perguntando
categoria/campo faltante"). A mensagem seguinte do script ("nao", pensada como recusa de
confirmação) foi interpretada como resposta INVÁLIDA daquele outro estado — e, por design correto
do bot (não limpar sessão em resposta inválida, só repetir a pergunta), a sessão ficou PRESA
esperando uma resposta válida pro resto do script. Toda mensagem seguinte (consulta, ação, setup do
próximo cenário) foi interceptada pelo handler desse estado pendente.

**Solução:**
1. Em qualquer bloco do script que depende de um estado específico ter sido atingido, confirme com
   `poll(query_do_estado, "estado_esperado", timeout)` **antes** de mandar a mensagem que depende
   dele — nunca assuma a transição só porque a mensagem anterior "parecia" certa.
2. Se o cenário pretende testar uma RECUSA/cancelamento de confirmação, garanta que a mensagem de
   setup tem sinal suficiente (keyword detectável, etc.) pra chegar no estado de confirmação de
   verdade antes de mandar a recusa — não escolha a frase de setup mais "neutra" só porque parece
   representativa; teste primeiro que ela bate o estado certo.
3. Isolar cada cenário num bloco com `try/except` (`runBlock`) evita que uma EXCEÇÃO derrube o
   script inteiro, mas **não substitui** o `poll()` de estado — uma sessão presa sem exceção passa
   reto pelo `runBlock` e ainda cascateia falso-negativo por todos os cenários seguintes.

**Ref:** Família Milionária, `execution/smoke_metas.py` (Fase 2, Metas/Desejos), 2026-08-07 — 1ª
rodada teve 4 falsas-FALHA em cascata porque o cenário de recusa mandava "nao" numa frase sem
keyword de categoria (foi pra `aguardando_categoria_meta`, não `confirmando_meta`); corrigido
trocando a frase de setup por uma com keyword válida, e a suíte foi de 9/13 pra 15/15 PASS.
