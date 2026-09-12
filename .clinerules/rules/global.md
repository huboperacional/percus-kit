# Regras Globais Percus (Modo Cline)

**A regra que governa todas as outras:**
Fato -> descubra. Execução -> faça. Decisão -> pergunte.
* Não pergunte o que pode descobrir com ferramentas de leitura e bash.
* Não peça permissão para rodar tool/bash local.
* Mas pergunte sempre (e uma coisa por vez) sobre decisões de produto, arquitetura ou se tem impacto irreversível.

**Artefatos e Fontes da Verdade:**
- `CONTEXT.md`: Vocabulário de domínio e regras de negócio essenciais.
- `docs/adrs/`: Decisões de design e arquitetura e seus porquês.
- `docs/PLANO.md`: Tracker de milestones e status (O que e Quando).
- `HANDOFF.md`: Contexto do momento, últimos passos dados e O Próximo Passo.

**Regras Inegociáveis (Base Percus V2/V5):**
1. Sem mocks no caminho produtivo, não invente stubs para facilitar o caminho das pedras, os fluxos devem ser END-TO-END `[0] -> [5-T]`.
2. Auth sempre usa padrão Percus, validação por JWKS, nunca JWT na mão. Tokens num cookie `Secure; HttpOnly`, nunca `localStorage`.
3. Dispare reviews automáticos sobre seus commits (O Cline pode acionar os scripts já previstos no projeto).
4. Verifique antes de declarar pronto, se não provar, não avança.

**Atuação:**
Quando tiver chamadas de bash dependentes ou independentes, otimize usando `&&` e rodando em background (`&`), se fizer sentido técnico.
Respeite o modelo de paralelismo sempre que couber.