## Review R11 (DeepSeek) devolve "Sem findings críticos" mas viu só um pedaço do diff — truncamento silencioso em diffs grandes {#r11-diff-truncation-silent}

`tags: council-orchestrator, deepseek review, prompt truncado, diff grande, false confidence, avaliar so metade do codigo, revisao incompleta parece completa`

**Sintoma:** rodar `council-orchestrator.ps1 -Mode review` num diff grande (~3000 linhas, ~40k
tokens) devolve `"Sem findings críticos"` de forma limpa — parece um review completo e tranquilizador.
O JSON de resposta tem uma linha fácil de não notar no meio do output:
`"[council-orchestrator] AVISO: prompt truncado de 40891 -> ~8000 tokens."` seguida de
`"truncated": true` no JSON. O truncamento corta do MEIO (mantém início e fim do diff), então os
arquivos mais centrais/críticos do diff (que caem no meio alfabético/posicional) podem nunca ter
sido vistos pelo revisor — o "sem findings" não é "revisei e está limpo", é "revisei metade e a
metade que vi está limpa".

**Causa raiz:** o wrapper do provider (DeepSeek/Groq) tem um teto de contexto de prompt bem menor que
o que o Claude Code consegue montar num diff real de uma sessão longa — sem um teto explícito, o
comportamento default é truncar em vez de falhar, e o aviso de truncamento fica fácil de perder no
meio de um JSON grande.

**Solução:** antes de aceitar um "Sem findings críticos" como válido pra um diff grande, checar
explicitamente `"truncated"` no JSON de resposta (ou o aviso de stderr). Se truncou: dividir o diff
em pedaços por arquivo/módulo lógico (cada `git diff -- <paths>` separado, um por chunk) e rodar o
review em cada pedaço independentemente — cada chamada then cabe no teto de ~8000 tokens do provider.
Reconsolidar os achados de todos os pedaços antes de decidir se o commit está limpo. Achados que
citam um arquivo/trecho que NÃO estava no chunk revisado (ex.: um revisor comentando sobre um arquivo
que só apareceu num chunk diferente) são sinal de que o revisor está alucinando contexto que nunca
viu — desconfie e verifique manualmente.

**Trade-off:** dividir em N chunks custa N chamadas de review em vez de 1, mas cada chunk cabe
inteiro no contexto do provider — a alternativa (1 chamada só, confiando no truncamento) já produziu
nesta sessão um review que teria dado "aprovado" pulando o arquivo com a lógica de merge mais crítica
do diff inteiro (`destinations.py`, onde 2 bugs reais foram achados quando revisado em separado).

**🔴 SEGUNDA CAUSA, medida em 2026-08-16 (Scraper-prospeccao) — o "Sem findings" pode vir vazio pelo
OUTRO lado do teto, e sem nenhum aviso de `truncated`.** Aqui o prompt cabia; o que não cabia era a
RESPOSTA. Nos modelos com raciocínio ligado por padrão, o `max_tokens` cobre **pensamento + resposta
juntos**, e o system prompt do modo *review* **dobra** o raciocínio. Medidos **6784, 7649 e 8192+**
tokens de raciocínio em três chamadas do **mesmo prompt**: com teto em 8192, a resposta voltava `ok`,
`truncada` ou **vazia na sorte** — e o gate do R11 **aceitava a review vazia como aprovação**,
liberando o commit. Três reviews seguidos deram "Sem findings críticos"; re-rodando o **mesmo diff**
com o teto corrigido, apareceu um bug real que os três tinham deixado passar.

- ⚠️ **Não reduza `max_tokens` pra caber num timeout** — é o reflexo errado e piora tudo: o modelo
  gasta o teto pensando e devolve `finish_reason=length` com conteúdo vazio. **Encolha o prompt.**
  (Medido na mesma sessão: o diff inteiro estourou 180 s; só o diff de produção voltou em 93 s.)
- 🔑 **Regra que serve para os dois casos:** *"Sem findings" não é sinal, é ausência de sinal.* Um
  review que aprova **sem citar um único arquivo ou linha** do diff é indistinguível de um review que
  não rodou. Exija que o revisor **descreva o que leu** antes de tratar o aval como aval.
- ⚠️ **Smoke de perna de conselho não pode usar prompt trivial:** "responda PONG" não dispara bloco de
  raciocínio, então o teste fica verde enquanto todo review real volta vazio. Valide com prompt que
  **force raciocínio**.
- ⚠️ **Teste de paridade compara o que você mandou comparar:** o que existia comparava **modelos**
  entre as duas implementações e ficava verde enquanto os **parâmetros** divergiam — e era o parâmetro
  que quebrava a chamada.

**Ref:** Paid Media Automation, cont.151, sessão 2026-08-05 (R11 da Fatia 2 do Google Ads
multi-conta). Segunda causa: Scraper-prospeccao, 2026-08-16 (canon 6.36.4).
