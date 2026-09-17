## Pre-mortem de plano longo em pedaços: pedaço só de título volta "CRITICAL", `grep truncad` casa o próprio prompt e o log é JSON de várias linhas {#pre-mortem-em-pedacos-tem-tres-armadilhas-de-leitura}

`tags: conselho, council-orchestrator, pre-mortem, plano longo, pedacos, chunk, truncamento, groq-llama, deepseek, council-log, jsonl, json multilinha, status error, falso positivo, leitura de resultado`

**Contexto:** para o conselho não truncar um plano de 7.268 linhas ([[conselho-trunca-o-prompt-antes-de-enviar]]), o
plano foi cortado por seção (`## ` e `### Task`) em pedaços abaixo do teto de cada provedor (DeepSeek ~20 mil caracteres,
Llama ~12 mil) e cada pedaço foi um `council-orchestrator.ps1 -Mode pre-mortem`. A voz Cross-Claude (subagente) leu o
plano inteiro. Medido em 2026-09-16, Empresa Milionária.

**Três armadilhas na leitura do resultado:**

1. **Pedaço que é só o título de uma seção** (`## Parte B — Schema` + linha em branco, 23 a 88 caracteres) volta com
   "CRITICAL: a seção está vazia, sem contrato". 5 de 44 pedaços foram assim. É defeito do CORTE, não do plano: junte o
   título ao primeiro bloco da seção seguinte, ou descarte essas respostas declarando por quê.
2. **`grep -i truncad` na saída do orquestrador casa o PRÓPRIO PROMPT**, que ele ecoa no JSON — o plano tinha a palavra
   "truncado" no texto. Duas falsas marcas de truncamento. Leia o campo `truncated` do log, nunca o texto da saída.
3. **O arquivo `.deepseek/council-log/*.jsonl` é UM objeto JSON formatado em várias linhas**, não JSON-lines. Ler linha a
   linha dá "SEM JSON" em todos; leia o arquivo inteiro (`json.loads(open(f, encoding="utf-8-sig").read())`).

**E um fato que muda a síntese:** a perna `groq-llama` devolveu `status: "error"` com `content: None` em **5 de 8**
pedaços (sem `aviso`). `respostas_usaveis` não é o que manda — conte `status == "ok"` por provedor e escreva quantos
pedaços cada voz realmente leu. "Conselho de três vozes" sobre o plano inteiro só existe se as três cobriram o plano.

**O que funcionou:** a voz que lê o documento inteiro (subagente) achou o CRITICAL mais forte (uma função compartilhada
por 9 arquivos com teste de 2), e o DeepSeek em pedaços o confirmou de forma independente. Todo achado com defeito
concreto foi conferido no texto do plano ou no código antes de aceitar: de 7 "defeitos de código" apontados, 3 não
procediam (o mecanismo existia por outro caminho, ou a spec mandava exatamente aquilo).
