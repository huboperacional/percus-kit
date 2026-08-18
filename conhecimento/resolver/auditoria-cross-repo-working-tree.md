## Auditoria cross-repo que lê o CHECKOUT LOCAL vira evidência circular {#auditoria-cross-repo-working-tree}

`tags: auditoria cross-repo, working tree, origin, evidencia circular, checkout local, git fetch, alerta retirado por engano, prova de codigo, revisao entre times`

**Sintoma:** um time audita o repo do outro, conclui "vocês já estão cobertos" e **retira um alerta
procedente**, citando linhas de arquivo como prova. O time auditado quase arquiva um defeito real.

**Causa raiz:** a auditoria leu os arquivos do **working tree** do outro repo, não de
`origin/<branch>`. Como havia uma sessão editando naquele momento — **em resposta ao próprio
alerta** — o auditor enxergou o efeito do que ele mesmo causou e reportou como prova de que o alerta
era desnecessário. Evidência circular perfeita: quanto mais rápido o outro time corrige, mais
convincente fica o argumento de que não havia o que corrigir.

**Solução:** auditoria cross-repo lê **`git show origin/<branch>:<arquivo>`**, sempre. O checkout
local pode conter trabalho em andamento, stash aplicado, ou branch diferente.

**Do lado de quem RECEBE a devolutiva:** se um documento cita o *seu* código como evidência, confira
contra `origin` antes de aceitar — inclusive (e principalmente) quando a conclusão é elogiosa. Um
`git grep -c "<símbolo citado>" origin/main -- <path>` devolvendo **0** encerra a discussão em
segundos. Elogio que bate com o que você acabou de escrever e ainda não publicou é sinal de alarme,
não de conforto.

**Ref:** Família Milionária × auth-service (2026-07-27),
`docs/cross-product/2026-07-27-auth-retrata-retirada-familia-e-responde-5xx.md` — o auditor
retratou-se e adotou a regra do `origin/`.
