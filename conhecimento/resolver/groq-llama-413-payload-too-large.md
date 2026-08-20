## Groq devolve HTTP 413 e o status MENTE: não é tamanho de payload, é cota de tokens por minuto {#groq-llama-413-payload-too-large}

`tags: council-orchestrator, groq-llama, 413, payload too large, TPM, tokens per minute, rate limit, on_demand, MaxInputTokens, teto por provider, _provider-limites.json, ErrorDetails, corpo do erro, gpt-oss-120b`

**Sintoma:** o conselho devolve `"groq-llama: error"` com `413 (Payload Too Large)`. A perna DeepSeek, com o MESMO prompt, responde normal. Às vezes falha em diff grande, às vezes em diff pequeno, e rodadas seguidas falham mais que rodadas isoladas.

🔴 **CAUSA RAIZ CORRIGIDA EM 2026-08-19 — a versão anterior deste verbete estava ERRADA.** Ela dizia "a API da Groq tem um limite de tamanho de payload HTTP menor que o da DeepSeek", e mandava re-rodar a perna com `-MaxInputTokens` menor. Medido contra a API viva, o corpo do erro diz outra coisa:

```
"message": "Request too large for model `openai/gpt-oss-120b` ... service tier `on_demand`
            on tokens per minute (TPM): Limit 8000, Requested 10329"
"type": "tokens",  "code": "rate_limit_exceeded"
```

**É cota de TAXA — 8000 tokens por MINUTO no tier `on_demand`, somando entrada + saída de TODAS as chamadas do minuto.** O nome do status HTTP é que engana; `code` é literalmente `rate_limit_exceeded`.

Isso explica cada peça do sintoma, que a hipótese de "payload" não explicava:

- **Falha com prompt pequeno:** 6200 tokens sem truncar deu 413 porque as outras pernas e o fact-check já tinham gasto a cota daquele minuto.
- **Falha mesmo truncado:** truncar para 8000 não ajuda quando 8000 é o teto do minuto inteiro.
- **"2 de 3 rodadas de review":** rodadas seguidas dentro do mesmo minuto comem o orçamento uma da outra.
- **A aritmética que ninguém tinha feito:** `-MaxInputTokens 8000` + `-MaxTokens 2048` de saída = **10048 pedidos contra teto de 8000**. No tamanho máximo a perna era **impossível**, não azarada.

⚠️ **"Retentar falha de novo, não é transitório" — também errado.** É transitório, na escala de um minuto. Só falha de novo se você retentar dentro do mesmo minuto.

**Por que sobreviveu a 39 ocorrências registradas:** o `catch` do `groq-llama.ps1` guardava só `$_.Exception.Message` — o cego `"(413) Payload Too Large"` — e descartava `$_.ErrorDetails.Message`, que traz o JSON acima. 🔑 **Sem o corpo do erro, o diagnóstico vira leitura do nome do status; e o nome do status estava errado.** Detalhe que vale saber: a interpolação `"$_"` sozinha **já mostra o corpo** (`ErrorRecord.ToString()` prefere `ErrorDetails`) — é a forma explícita `$_.Exception.Message`, a que *parece* mais cuidadosa, que joga a informação fora.

**Solução (6.44.0):** teto de entrada **por provider**, em `providers/_provider-limites.json`, lido pelos dois orquestradores. A Groq recebe 5000 de entrada (5000 + 2048 = 7048, cabe nos 8000); DeepSeek e Cross-Claude continuam recebendo o prompt inteiro. Antes, um `-MaxInputTokens` único ou estourava a menor ou truncava as duas maiores à toa — pagar com a qualidade de duas pernas boas pelo limite da terceira.

**Trade-off aceito:** em diff grande a Groq vê um RECORTE. Trate como perspectiva parcial, não como voto cego — e note no relatório: desde 6.44.0 o `respostas_usaveis` é emitido também pelo lado bash, então perna degradada aparece.

⚠️ **Até onde o teto por provider resolve.** Ele torna a chamada **isolada** determinística — o
que era impossível por aritmética passa a caber. **Não** resolve a cota do minuto: duas rodadas
seguidas ainda estouram (medido 2026-08-20: 1ª `ok`, 2ª `429 Rate limit reached`). Se a perna
cair logo depois de outra rodada, **espere um minuto e repita** — agora é legítimo dizer isso,
porque a causa é taxa e não tamanho.

**Se precisar do prompt inteiro nas três pernas**, a saída é o Dev Tier da Groq (a própria mensagem de erro linka `console.groq.com/settings/billing`) — decisão de custo, não de engenharia.

**Relacionado:** [#conselho-perna-vazia-teto-tokens] (outra causa de perna degradada: teto de `max_tokens`, não cota) · [#jq-argv-too-long-review] (a MESMA perna também caía por argv em prompt grande — dois defeitos diferentes com o mesmo sintoma de "perna muda") · [#conserto-num-sitio-nao-varre-os-irmaos].

**Ref:** causa original registrada em Kommo-Disparo-WhatsApp (2026-08-05), **corrigida** em percus-kit 6.44.0 (2026-08-20) com medição direta contra `api.groq.com`.
