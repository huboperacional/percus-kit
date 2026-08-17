## Perna Cross-Claude do review queima o teto INTEIRO pensando e volta vazia — a 6.36.4 moveu o teto, não consertou a causa {#cross-claude-review-queima-16000-e-volta-vazio}

`tags: conselho, cross-claude, review, R11, status empty, max_tokens, thinking budget, sonnet 5, 16000, council-orchestrator, resposta vazia paga, finish_reason length`

**Sintoma:** `council-orchestrator -Mode review -Providers "cross-claude"` devolve
`"status": "empty"`, `content: null` — e o `usage` mostra **`completion_tokens` exatamente igual ao
teto**. Medido em 2026-08-17, canon **6.36.6**:

```
=== cross-claude claude-sonnet-5 status= empty
usage: {"prompt_tokens": 3857, "completion_tokens": 16000, ...}
```

Prompt de 3857 tokens, um único arquivo de 208 linhas. O modelo gastou **16000 tokens pensando** e
não sobrou orçamento para escrever a resposta.

🔴 **Por que isto não é o bug já conhecido:** a 6.36.4 diagnosticou a mesma classe (`"o teto do
DeepSeek em 8192 caía no meio da faixa de raciocínio do modo review"`) e consertou **subindo o teto
de 8192 para 16000**. Este registro é a prova de que subir o teto **não fecha o buraco**: com
thinking ligado por padrão nos modelos 5, o raciocínio se expande até onde houver orçamento. Qualquer
teto novo vira o novo tamanho do pensamento. **A 6.36.4 comprou tempo, não conserto.**

**Causa raiz:** `max_tokens` cobre **pensamento + resposta** nos modelos 5, o thinking adaptativo vem
**ligado por padrão**, e o request não limitava a profundidade. O raciocínio se expande até encher o
teto e não sobra orçamento para escrever.

🔴 **CORREÇÃO IMPORTANTE — a primeira versão deste verbete prescrevia um conserto que devolve 400.**
Ela mandava usar `thinking: { type: "enabled", budget_tokens: N }`. Nos modelos 5 esse campo foi
**removido**, não depreciado:

```
HTTP 400 invalid_request_error
"thinking.type.enabled" is not supported for this model
```

Quem me corrigiu foi a skill `claude-api`, antes de eu aplicar. **A lição operacional é essa:
consultar a referência da API antes de "consertar" chamada de LLM por memória** — o parâmetro que eu
lembrava existia, foi removido, e o verbete errado teria derrubado a perna de vez em vez de
consertá-la.

**O controle que existe hoje é `output_config.effort`.** Medido em 2026-08-17, mesmo prompt de review,
mesmo arquivo, três execuções:

| configuração | `output_tokens` | `stop_reason` | texto | tempo |
|---|---|---|---|---|
| sem controle (como estava) | **16000** | `max_tokens` | **0 chars** | 153 s |
| `thinking.budget_tokens=8000` | — | — | **HTTP 400** | — |
| `output_config.effort=low` | 3719 | `end_turn` | **1378 chars** | 47 s |

**Solução:**
1. Mandar `output_config: { effort: "low" }` no corpo do request. Além de devolver resposta, ficou
   **3× mais rápido e ~4× mais barato** — o teto de 16000 nunca era consumido escrevendo, era
   consumido pensando.
2. **Não mandar `thinking` nenhum.** Adaptativo é o default nos modelos 5; qualquer configuração
   explícita de budget é 400.
3. ❌ **NÃO subir `max_tokens` de novo.** Já foi feito (8192→16000) e o sintoma voltou idêntico —
   teto maior é só pensamento maior.
4. `status == "empty"` **tem de ser tratado como falha da perna**, não como "sem findings". Hoje é
   reportado num campo que passa batido.

⚠️ **O sinal barato que separa "vazio por truncamento" de "vazio por não ter achado nada":**
`completion_tokens` colado no teto. Resposta legítima curta gasta centenas de tokens; esta gasta
exatamente `max_tokens`. Se bateu no teto, **foi truncada e foi paga**.

**E encolher o prompt não resolve:** testado na mesma sessão com 904 linhas e depois com 208 — as
duas voltaram `empty`. O gargalo é o orçamento de raciocínio, não o tamanho da entrada.

**Consequência operacional imediata, que vale para todo projeto:** a matriz de roteamento do R11 manda
**pasta sensível → DeepSeek + Cross-Claude duplo**. Com a perna Cross-Claude devolvendo vazio, o
"duplo" é **simples** — e a segunda opinião que justificava a regra não existe. Some com
[[groq-llama-3-3-decomissionado-404]] (perna Groq morta desde ~06/08) e o conselho de 3 membros está
**de fato rodando com 1**. Isso precisa ser dito em voz alta no relatório, nunca assumido.

**Ref:** medido em 2026-08-17 revisando `lib/admin/auth.ts` do repo `website-autoworxnj`, canon
6.36.6, modelo `claude-sonnet-5`. Ver também [[reference_review_limpo_pode_ser_vacuidade]] — mesma
família: a ferramenta responde, o resultado parece legítimo, e o que falta é invisível.
