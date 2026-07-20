# Loop: conselho — validação plural

**Quando — automático, sem pedir permissão:**

| Gatilho | Modo |
|---|---|
| Spec fechada | `analyze` — devolve PRONTA / AJUSTAR / BLOQUEADA |
| Plano fechado, antes de implementar | `pre-mortem` — "se isso falhar em 30 dias, por quê?" |
| Decisão reversível de design, naming ou pattern | `consult` |
| Diff antes de commit | `review` — ver `loops/review.md` |

**Por quê:** três provedores erram em lugares diferentes. Consenso de três sobre o mesmo risco é sinal; opinião de um é palpite.

## Como rodar

- **Arquivo de prompt único por invocação** — `council-<timestamp>-<pid>.txt`. Nome fixo já causou o bug de prompt stale (a 2ª rodada respondia à pergunta anterior).
- `council-orchestrator` com `-Mode <modo> -Providers "deepseek,groq-llama"`.
- **3ª voz (Cross-Claude):** sai pelo wrapper direto quando existe `ANTHROPIC_API_KEY`. Sem a chave, dispare um subagent Sonnet **em paralelo** com o mesmo prompt e sintetize as três.
- ⚠️ **Nunca envie `temperature` / `top_p` / `top_k`** — Opus 4.7+, Sonnet 5 e Fable 5 rejeitam com **400**.

## Como ler o resultado

- **3/3 no mesmo ponto** → trate como decisão. Se for difícil de reverter, vira ADR.
- **2/3** → sinal, não veredito. **Diga que foi 2/3.**
- **Divergência total** → a pergunta estava mal formulada. Reescreva antes de rodar de novo.
- **Um membro falhou** → reporte "2 de 3 responderam". Nunca apresente conselho parcial como completo.
- **`analyze` de spec exige ≥2 provedores** (DeepSeek + Cross-Claude). Spec é decisão de design — veredito de um provedor só não aprova spec.

## Quando parar (regra de parada)

O conselho converge ou não — **não roda pra sempre.** Achado do piloto-2 (Plexco,
2026-07-20): sem teto, uma barra de progresso gastou **4 rounds** — o real saiu no round 1,
os outros foram defender de findings alucinados. Num pino em que um provedor alucina, sem
regra isso rodaria sem fim.

- **Teto: 2 rounds.** O round 1 acha; o round 2 existe só pra endereçar bloqueador
  **confirmado** do round 1 — não pra reabrir o que já passou.
- **Só bloqueia o que é HIGH/CRITICAL e sobrevive ao fact-check.** Severidade menor, ou
  finding que não se confirma, vira **risco documentado** (linha na spec/PLANO), não trava.
- **Bateu o teto com findings abertos?** Viram risco aceito e registrado — não um 3º round.
  Rodar de novo sem pergunta nova é o mesmo anti-padrão do escape reincidente (`loops/drift.md`).

## O que o conselho NÃO faz

Ele **não decide** — expõe risco e alternativa. O operador decide. Conselho unânime numa direção ruim continua sendo direção ruim.

## Armadilha

Pergunta enviesada devolve confirmação, não perspectiva. Descreva contexto e opções **sem** revelar qual você prefere — sua recomendação vai para o operador, não para o conselho.
