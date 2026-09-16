## Review acha ~2,6 coisas por chamada, não importa o tamanho do diff — juntar commits economiza dinheiro e perde achado {#achado-de-review-satura-com-o-tamanho-do-diff}

`tags: R11, review, custo, diff grande, lote, batch, economia, findings, densidade de achados, saturacao, commit grande, telemetria de gasto, deepseek-review`

**Pergunta que isto responde:** *"e se a gente juntasse tudo e revisasse/commitasse só no fim do dia? economizaria?"* — Economiza. E é uma má ideia. Os dois lados agora estão medidos, então a decisão deixa de ser opinião.

**Medido em 2026-08-24, 346 reviews reais com `diff_lines` e findings registrados:**

| tamanho do diff | n | findings médios | por 1000 linhas |
|---|---|---|---|
| 0–100 linhas | 95 | 0,14 | 4,46 |
| 100–500 | 150 | 0,88 | 3,91 |
| 500–1500 | 76 | 2,12 | 2,64 |
| 1500–5000 | 25 | 2,60 | 1,45 |

🔑 **Os achados SATURAM em ~2,6 por chamada.** Um diff 3,3x maior rende 23% mais achados; a densidade cai 3x. O revisor tem um orçamento de atenção por chamada, e ele não cresce junto com o diff — mesmo sem truncagem (que é outro problema, ver [#r11-diff-truncation-silent]).

**A simulação do modo lote, com os mesmos dados:** 1 review por projeto por dia economizaria **46%** do custo, e levaria o diff mediano a **10.108 linhas**. Pela tabela, essa review acharia ~3 coisas. As mesmas mudanças revisadas em pedaços de ~500 linhas acham ~40. **Você compra 46% de desconto pagando com ~90% dos achados.**

⚠️ **O corte inverso também não funciona — medi antes de propor.** Dispensar review de diff pequeno parece óbvio (diffs de 0–100 linhas acham 0,14 em média), mas: dispensar `< 100 linhas` economiza **3%** e perde 3,3% dos achados; `< 200 linhas` economiza 8,8% e perde **14,6%**. Diff pequeno é barato *porque* é pequeno — 14% das chamadas custam 3% do dinheiro. Não há gordura nas pontas.

**A faixa boa é 100–1500 linhas**, e é onde a operação normalmente já está (mediana medida: 454 linhas). Antes de "otimizar" o tamanho de commit, meça onde vocês estão — pode já ser o ponto ótimo.

**Riscos do modo lote que não são de custo, e pesam mais:**
- Em checkout compartilhado, um dia de trabalho não commitado em N projetos trava o commit de todos: o gate valida a árvore inteira (ver [#checkout-compartilhado-entre-sessoes] na memória de projeto).
- Deploy sem commit coloca em produção código que não está no git — sem rastro e sem rollback.
- Trabalho não commitado não tem backup.

**A conclusão que vale guardar:** quando não há desperdício para espremer — 1 review por commit, sub-centavo cada, cache no teto — a pergunta deixa de ser *"como gastar menos fazendo o mesmo"* e vira *"quanta revisão queremos comprar"*. São decisões diferentes, e só a segunda é honesta nesse cenário.

**Consequência adotada (2026-09-15, ponto 23):** o `deepseek-review` (`.ps1` e `.sh`) passou a **fatiar o diff por arquivo** em vez de mandar tudo numa chamada só. Acima de `-MaxLinhasFatia` (env `PERCUS_R11_MAX_LINHAS_FATIA`, padrão 1500, mín. 200) ele parte nas fronteiras `diff --git`, empacota de forma gulosa até o teto — **código primeiro, teste depois, sem misturar** — e faz uma chamada por fatia, cada uma com o timeout/retry de sempre. O orçamento de atenção deixa de ser por commit e passa a ser por fatia: a densidade de achados volta à faixa boa sem exigir que o operador pique o commit à mão. Limites e garantias:
- teto de `-MaxFatias` (env `PERCUS_R11_MAX_FATIAS`, padrão 8). Acima dele **não** fatia: revisa inteiro como antes e avisa na stderr (`WARN: diff de <N> linhas precisaria de <k> fatias`) — o remédio aí é dividir o commit, não pagar 20 chamadas;
- arquivo sozinho maior que o teto vira fatia própria, **sem corte** (cortar diff é a classe [#r11-diff-truncation-silent]);
- **um** `latest.jsonl` no fim, com `findings` de todas as fatias (`### Fatia i/n — <arquivos>`), `usage` somado campo a campo e `fatias: n`; o `d-<hash>` continua sendo o hash de `git diff HEAD` inteiro. Fatia que falha encerra com o código de sempre (4/3/1) + `(fatia i/n)` e **não grava marcador nenhum** — marcador parcial liberaria commit meio revisado;
- telemetria: uma linha de spend por fatia, com `fatia`, `fatias` e `latency_ms`.

⏱️ **Ao chamar a review de um agente:** 8 fatias × até 180 s não cabem no teto padrão de 120 s do Bash tool. Use **timeout 600000** ou background com espera explícita — senão a chamada é morta no meio e a review some sem marcador.

**Relacionado:** [#taxa-de-cache-tem-teto-estrutural] (medição irmã, mesma investigação) · [#r11-diff-truncation-silent] (diff grande também pode ser truncado, e aí a review parece limpa).

**Ref:** percus-kit, investigação do gasto DeepSeek de 2026-08-24. Base: 1.009 reviews e 1.026 commits em 13 projetos, 19–24/08.
