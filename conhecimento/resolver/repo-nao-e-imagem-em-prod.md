## "O backend já aceita X" — repo ≠ imagem em prod (422 silencioso pós-deploy parcial) {#repo-nao-e-imagem-em-prod}

`tags: repo vs imagem, deploy parcial, 422, Literal, capacidade nao verificada, handoff herdado, smoke honeypot, gate de versao no deploy, milestone review`

**Sintoma:** feature nova (form do `/investors`) 100% pronta e testada em código; o HANDOFF afirmava "o backend já aceita `source=investors` desde `d3ec75e`". Verdade **no repo** — mas a imagem em prod (`:0.2.40`) foi buildada ANTES desse commit, e o POST levava **422** (`Input should be 'portal' or 'landing'`). Se o portal tivesse subido sozinho, 100% dos leads da página de captação quebrariam com "Algo deu errado" e nada apareceria em log de erro do portal.

**Causa raiz:** afirmação de capacidade baseada em `git log`, não na imagem deployada. Commits de fundação (schema/Literal/notifier) entram no repo semanas antes do deploy que os carrega.

**Solução (2 camadas):**
1. **Smoke da capacidade direto em prod ANTES do deploy dependente**, sem side-effect: POST com **honeypot preenchido** (`website`) — se o Literal aceita, vem 201 falso sem persistir nada; se não, vem o 422. Custo: 1 curl.
2. **Milestone review adversarial paga:** foi o revisor cross-contexto (subagente de contexto limpo) que testou ao vivo e derrubou a premissa — o autor do plano (eu) tinha herdado a afirmação do HANDOFF sem re-verificar.

**Padrão do gate no script de deploy:** o deploy dependente começa com `curl /health` e **aborta** se a versão exigida não está em prod (ver `.tmp/deploy_frontend_v76.py` step 0 no Micro Investors).

**Ref:** Micro Investors, deploy F3 `portal:v9` (2026-07-19). O fix virou a ordem: `:0.2.41` → `v9` → `v76`.
