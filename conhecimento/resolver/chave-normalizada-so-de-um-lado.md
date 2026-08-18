## Chave de junção normalizada em um lado só: UPDATE vira no-op silencioso e a coluna nasce morta {#chave-normalizada-so-de-um-lado}

tags: update-no-op, coluna-morta, chave-divergente, normalizacao, lstrip, telefone, join-key,
silent-failure, teste-usa-mesmo-formato-dos-dois-lados

**Sintoma:** uma coluna existe no esquema, o código que a escreve existe e é chamado, os testes
passam — e em produção ela é sempre o default. Nenhum erro, nenhum log, nenhuma exceção.

**Causa raiz:** o registro grava com uma chave (`usuario.whatsapp` = `+5567...`) e o update casa
com outra (`sessao.numeroWhatsapp`, que o `upsertSession` normaliza com `lstrip("+")`). Como o
`UPDATE ... WHERE numero = :x` usa igualdade exata, ele acerta **zero linhas** — e `rowcount=0`
não é exceção, então o `try/except` best-effort não tem o que registrar. O caminho de falha é
silêncio absoluto.

**Por que o teste não pega:** o unitário monta os dois lados com a MESMA string. A divergência só
existe porque duas camadas diferentes produzem a chave — e só o teste de pipeline (que passa pelo
`upsertSession` real) exercita isso.

**Solução:** (1) derivar a chave da MESMA fonte nos dois lados; (2) teste de integração que roda o
pipeline de ponta a ponta e afirma a coluna, mutation-testado trocando a chave de volta; (3) se a
operação é best-effort, logue `rowcount == 0` — "não achei o que atualizar" é informação, não
sucesso.

**Como procurar no seu projeto:** `grep` pelas funções de normalização (`lstrip`, `strip`, `lower`,
`replace`) aplicadas a identificadores e cruze com todo `WHERE <id> =`. Cada par onde uma ponta
normaliza e a outra não é um no-op esperando acontecer.

**Ref:** Família Milionária, `042fb61` → `b00d534` (2026-08-11). Achado pelo `milestone-review`
sobre o diff completo, depois de 9 reviews por commit e 2713 testes verdes. R23.
