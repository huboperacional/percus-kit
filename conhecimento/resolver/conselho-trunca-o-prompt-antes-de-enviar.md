## O conselho TRUNCA o documento antes de enviar, e silêncio sobre uma seção não é aprovação dela {#conselho-trunca-o-prompt-antes-de-enviar}

`tags: conselho, council, council-orchestrator, pre-mortem, analyze, truncamento, prompt truncado, groq-llama, teto de tokens, respostas_usaveis, ausencia de achado, plano longo, spec longa, cobertura de review, deepseek, cross-claude`

**Sintoma:** você manda um plano ou spec longo ao conselho (`council-orchestrator.ps1`, modo `pre-mortem` ou `analyze`), recebe as três respostas, e nenhuma comenta as últimas tasks. A leitura natural é *"não acharam nada ali"*. Não é isso: **eles não leram**.

**Causa raiz:** o orquestrador corta o prompt **antes de enviar**, e avisa em duas linhas de `stderr` que se perdem no meio da saída. Medido em 2026-09-07, num plano de 1.326 linhas:

```
[council-orchestrator] AVISO: prompt truncado de 20612 -> ~8000 tokens.
[council-orchestrator] perna 'groq-llama' tem teto proprio de 5000 tokens:
                       prompt truncado de 7953 -> ~4943 (o das outras pernas fica inteiro)
```

Nenhum dos três leu o documento inteiro; a Llama leu **menos de um quarto**. E o `.jsonl` grava `respostas_usaveis: 3`, `respostas_degradadas: []` — **o campo que soa como controle de qualidade não olha o truncamento**. O sinal está noutra chave (`truncated: true`, `original_token_count`), que ninguém abre quando o veredito veio limpo.

**O erro que isso produz não é acreditar num achado — é a leitura INVERSA.** Dos três "riscos" devolvidos naquela rodada, **dois eram sobre coisas que o plano já tratava em trechos cortados**, e um risco de consenso ("mudar o parâmetro para nulável quebra chamadores existentes") caiu num `rg` de dez segundos, porque o módulo não tinha chamador nenhum. É a mesma família de [[achado-de-review-satura-com-o-tamanho-do-diff]]: o instrumento responde, e a resposta descreve menos do que quem lê supõe.

**Solução:**

1. **Leia `truncated` e `original_token_count` no `.jsonl` ANTES dos achados**, e escreva no documento revisado quanto foi cortado. O veredito consolidado vale pelo que foi lido, não pelo que foi enviado.
2. **Trate cada achado como hipótese a medir, não como veredito.** Os que sobreviverem a uma medição valem; os que caírem custam segundos. Nunca reescreva desenho por achado de conselho sem antes reproduzir o cenário.
3. **Nunca escreva "o conselho aprovou a task N"** quando o corte pode tê-la deixado de fora. A frase honesta é *"nenhum provider comentou a task N, e o prompt foi truncado"* — e é ela que impede a próxima sessão de tratar silêncio como aval.
4. **Para documento longo, o conselho acha defeito no que ele LEU.** A cobertura continua sendo sua: rode a auto-revisão do `writing-plans` sobre o documento inteiro, que não passa pelo teto.

**Verbete irmão, do mesmo dia e do mesmo desenho:** um plano **não** deve conter código deliberadamente errado com aviso *"não copie sem pensar"* — foi exatamente o que o Cross-Claude pegou naquela rodada, e com razão. Subagente fresco não tem o contexto do aviso: ele copia. Se a intenção é ensinar, escreva a versão certa e explique o erro **em prosa**, fora do bloco de código.
