## `percus-review-auto.ps1` não tem modo "zero API paga" — o roteador sempre pode cair em DeepSeek solo {#percus-review-auto-nao-tem-modo-zero-api}

`tags: r11, percus-review-auto, deepseek, roteador, zero api, custo, cross-claude, R23`

**Sintoma:** numa rodada em que o operador declarou explicitamente "zero API paga" (revisão só
por Cross-Claude via subagente, sem crédito), um agente roda o wrapper PADRÃO de commit
(`percus-review-auto.ps1`, o mesmo documentado no workflow genérico "Agente AUTO-DISPARA review
antes de `git commit`") e ele chama a API paga da DeepSeek mesmo assim.

**Causa raiz:** o roteador de `percus-review-auto.ps1` decide entre `deepseek` / `cross-claude` /
`dual` / `council` olhando só o DIFF (pasta sensível? commit veio de DeepSeek? mudança grande?) —
ele não tem noção de "este agente está numa rodada de custo zero". Pra qualquer diff comum, não
sensível, a decisão solo é `deepseek`, que chama a API direto. O único jeito de escalar pra
Cross-Claude é o marker `__PERCUS_NEEDS_CROSS_CLAUDE__`, emitido só quando o roteador já decidiu
`cross-claude`/`dual`/`council`, ou quando o DeepSeek falha (outage/chave). Não existe flag
`-ZeroApi` nem env var que force a rota solo pra Cross-Claude.

**Medido em tiatendo (2026-09-04):** um agente, seguindo o workflow padrão documentado no
`CLAUDE.md` do projeto (que descreve o wrapper genérico, sem mencionar a exceção da rodada),
rodou `percus-review-auto.ps1` num diff de 3 arquivos não-sensíveis durante um mandato "zero API
paga" explícito. O roteador escolheu `deepseek`, gastou crédito real. Duas rodadas depois, ao
tentar reproduzir com um marco/commit maior, o mesmo aconteceu de novo até o agente aprender a
regra.

**Solução:** durante qualquer rodada com restrição de custo declarada (mandato noturno, operador
disse "zero API", conselho já truncado por saldo, etc.), **não invoque
`percus-review-auto.ps1`** — invoque a skill/comando que força só Cross-Claude:

```
Skill(skill: "percus-review:cross-claude-review")
```

Isso dispara um subagente Sonnet que revisa o diff e escreve o registro em
`.deepseek/reviews/latest.jsonl` no mesmo schema que o wrapper normal produziria — o hook de
pre-commit (Layer 1) não distingue a origem, só lê o arquivo. Zero custo, mesmo efeito de
satisfazer o gate R11.

**Se já aconteceu** (crédito já gasto por engano): não dá pra desfazer a chamada, mas dá pra
corrigir a PROVENIÊNCIA — rode uma review Cross-Claude retroativa contra o MESMO diff/commit e
sobrescreva `.deepseek/reviews/latest.jsonl` com o registro correto, documentando no commit
seguinte que a rota original foi indevida.

**Contra-regra:** fora de uma rodada com restrição de custo explícita, `percus-review-auto.ps1` é
o wrapper CORRETO e recomendado (é o R11 padrão do projeto) — este verbete só se aplica quando o
operador já declarou zero-API pra aquela sessão/rodada especificamente.

Irmãos: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]] ·
[[guard-r20-bloqueia-a-gravacao-da-propria-autorizacao]]
