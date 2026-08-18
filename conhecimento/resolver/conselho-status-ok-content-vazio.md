## Conselho: `status: ok` NÃO significa que o membro respondeu {#conselho-status-ok-content-vazio}

`tags: conselho, council-orchestrator, status ok, content vazio, deepseek mudo, reasoning_tokens, llama tautologia, finding falso, cross-claude, N de 3 responderam, quorum`

O `council-orchestrator` marca `status: "ok"` quando a chamada HTTP deu certo — **mesmo com
`content: ""`**. Numa sessão o **DeepSeek devolveu conteúdo vazio 3 vezes seguidas** (analyze de
spec e pre-mortem de plano, prompts de ~2,8k tokens), gastando **1024 de 1024 tokens de completion
inteiramente em `reasoning_tokens`** e não emitindo resposta. Quem lê o `status` conclui que o
conselho rodou.

**Como detectar:** olhe `responses[].content`, não `status`. Vazio = membro caiu.
**Efeito:** o canon exige ≥2 provedores para aprovar spec. Com o DeepSeek mudo e a Llama
produzindo genérico, o conselho fica **abaixo do mínimo sem avisar**.

⚠️ **A Llama passa no `status` e no `content`, e ainda assim pode não valer nada.** No mesmo dia ela
devolveu, num pre-mortem, três tautologias: *"se a atualização não foi feita corretamente, o plano
pode falhar"*. E num analyze pediu para especificar o que dois requisitos já especificavam —
**findings falsos**, que só não viraram retrabalho porque foram conferidos contra a fonte.

**O que fazer:** quando o conselho vier vazio ou genérico, dispare o **Cross-Claude (subagente
Sonnet)** com o prompt e **mande ele ler os arquivos** que o artefato cita. Foi o único membro que
produziu achado real nas duas rodadas — inclusive um CRITICAL que teria feito uma fatia inteira ir
a produção sem mudar nada.

### 🔧 O CONSERTO (verificado 2026-08-13): o orquestrador diagnostica e não deixa consertar

O `council-orchestrator.ps1` hoje **emite o diagnóstico exato** em `respostas_degradadas`:

```
deepseek: empty -- resposta VAZIA: o modelo gastou o teto de tokens RACIOCINANDO e nao sobrou
nada pra resposta -- suba -MaxTokens. (completion=8192 reasoning=8192 finish_reason=length)
```

🪤 **Mas `-MaxTokens` NÃO é parâmetro do orquestrador** — ele existe só no wrapper do provider
(`plugin/percus-review/providers/deepseek.ps1`, `[int]$MaxTokens = 8192`) e o orquestrador **não
repassa**. Ou seja: a ferramenta imprime uma instrução que ela própria não aceita. Quem lê o aviso
e tenta `-MaxTokens` no orquestrador leva erro de parâmetro e conclui que não tem jeito.

**Fix imediato — chamar o provider DIRETO, fora do orquestrador:**

```powershell
& "…\percus-kit\plugin\percus-review\providers\deepseek.ps1" `
    -PromptFile "d:\tmp\prompt.txt" -MaxTokens 32000 -Model "deepseek-v4-pro"
```

Medido no mesmo prompt (~4,4k tokens de entrada, spec de frente): com 8192 → `content` vazio,
**duas rodadas seguidas**; com 32000 → resposta completa, `status: ok`, 1.530 caracteres, com
veredito e uma **discordância substantiva** da outra perna (que era exatamente o valor de ter a
perna). O `deepseek-v4-pro` é modelo de RACIOCÍNIO: o teto tem que caber pensamento **+** resposta,
e 8192 não cabe nem o pensamento de uma spec média.

**Consequência pro canon:** `-MaxTokens` precisa virar parâmetro do orquestrador (repassado por
provider). Enquanto não for, "DeepSeek voltou vazio" **não é** motivo pra declarar conselho
degradado — é motivo pra re-rodar a perna direto com o teto maior. Declarar 1,5 de 3 sem tentar
isso subestima o conselho e pode aprovar spec com uma perna a menos sem necessidade.

**Reporte sempre "N de 3 responderam".** Conselho parcial apresentado como completo é pior que
conselho nenhum.

**Relacionado (mesma classe, medição posterior e mais completa):**
[#conselho-perna-vazia-teto-tokens] — a causa do `content` vazio é o **teto de `max_tokens`** contra
um modelo de raciocínio. Leia os dois como um só: aqui está o sintoma no consumidor, lá está a conta.

Visto em: Plexco Tasks, s151 (2026-07-27).
