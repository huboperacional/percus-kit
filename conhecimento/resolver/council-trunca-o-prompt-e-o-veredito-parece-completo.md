## O orquestrador do conselho TRUNCA o prompt e o veredito volta parecendo completo {#council-trunca-o-prompt-e-o-veredito-parece-completo}

`tags: conselho, pre-mortem, council-orchestrator, truncamento, teto de tokens, veredito parcial, perna degradada, groq, review, falso consenso`

**Contexto:** um plano de 1.155 linhas foi ao pre-mortem. O conselho devolveu achados concretos e
bem fundamentados, com cara de leitura completa. Um deles chegou a apontar um buraco real.

**Causa raiz:** a primeira linha do stdout dizia
`[council-orchestrator] AVISO: prompt truncado de 20316 -> ~8000 tokens`. O conselho leu **~40% do
plano** — e opinou com total naturalidade sobre o que leu. As tasks finais, onde estava o achado
mais pesado da sessão (PII em claro sendo gravada), **nunca entraram no prompt** e não receberam
nenhuma perna.

**Por que ninguém viu antes:** o aviso é **uma linha de stdout antes de um JSON grande**, some no
scroll, e não aparece no JSON de resultado. E o sintoma é invertido: um veredito truncado não parece
vazio nem confuso — parece **um bom review de escopo menor**. Quem não olhou o contador conclui
"revisado, sem mais achados" sobre uma área que ninguém abriu.

**Como resolver:**
1. Depois de rodar o conselho, **leia `original_token_count` e o aviso de truncamento** antes de
   ler qualquer achado.
2. Se truncou, **declare em voz alta qual parte não foi revisada** — no ledger, no PLANO e no
   registro do veredito ("as Tasks 7-12 ficaram fora do prompt, incluindo a RF-7").
3. Para artefato grande, **fatie**: mande o conselho por blocos (requisitos, depois tasks de
   backend, depois de frontend), em vez de mandar tudo e deixar o corte escolher sozinho.
4. Some isso à contagem de pernas: o veredito real é
   **"N de M pernas responderam, sobre X% do artefato"** — não só "N de M".

**Sinal de que você está neste caso:** o conselho não menciona **nenhuma** das seções finais do
documento, e os achados param todos na mesma altura do texto.
