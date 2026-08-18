## Fix editado DEPOIS do `add` fica fora do commit — review revisa versão limpa, commit embarca a buggy {#staging-pos-review-drift}

`tags: git stage staged add diff review commit stale fix hook marker`

**Sintoma:** você roda a review (R11), ela aponta um bug, você corrige o arquivo, mas o commit embarca a versão SEM o fix. O `git status` mostra o arquivo como `MM` (staged + working-tree divergem): o stage capturou o estado ANTES da correção; as edições pós-stage ficaram só no working tree.

**Como pegou (2026-07-12, tiatendo billing):** o Cross-Claude comparou `git diff --cached` (staged) vs `git diff` (working) e viu que o guard de refund/chargeback (não regride `canceled` terminal) existia no working tree mas NÃO no índice → o commit ali embarcaria o bug. O DeepSeek, que só olhou o staged, apontou o mesmo bug como "não corrigido" — porque de fato o fix não estava staged.

**Solução:** depois de QUALQUER edição pós-review (fixes de findings, ajustes), **re-adicione ao índice todos os arquivos tocados ANTES de fechar o commit**. Confirme com `git status --short`: nenhum `MM`/` M` nos arquivos do escopo; tudo `M `/`A ` (staged limpo). Regra: o gate de review roda sobre o MESMO conteúdo que vai pro commit — editou depois, re-stage.

**Generaliza:** vale pra qualquer gate que inspeciona staged (mock-scan, types-check). Editar após o gate e fechar o commit sem re-stage fura o gate silenciosamente. Um 2º revisor (Cross-Claude) que compara staged vs working é o que pega — peça a comparação explícita quando o diff for sensível (pagamento/migrations).

**Ref:** tiatendo billing (2026-07-12) — o Cross-Claude comparou `git diff --cached` vs `git diff` e pegou o guard de refund/chargeback fora do índice.
