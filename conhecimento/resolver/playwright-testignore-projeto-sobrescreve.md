## `testIgnore`/`testMatch` de PROJETO substitui o do config raiz — não soma {#playwright-testignore-projeto-sobrescreve}

`tags: playwright, testIgnore, testMatch, projects, particao de suite, spec roda no projeto errado, suite mistura ruido, config raiz, override silencioso`

**Sintoma:** uma partição de suíte que estava funcionando volta a misturar specs: testes mobile/mockados rodam no projeto desktop e falham por motivo errado (viewport, dev server ausente), e a rodada mistura defeito real com ruído — exatamente o problema que a partição existia pra resolver.

**Causa raiz:** no Playwright, `testIgnore` (e `testMatch`) declarados **dentro de um `project`** *substituem* os declarados no nível do config — eles **não somam**. Adicionar um `testIgnore` novo no projeto (ex.: pra não rodar as specs públicas duas vezes) **anula em silêncio** a lista global. Nada avisa: a suíte simplesmente passa a rodar mais coisa, e como a maioria dos specs extras passa, o sintoma aparece só nos poucos que dependem de viewport/servidor.

**Solução:**
1. Extraia as listas pra **constantes nomeadas** e **concatene explicitamente** no projeto: `testIgnore: [...SPECS_COM_CONFIG_PROPRIA, ...SPECS_PUBLICAS]`.
2. Trave com contagem: `npx playwright test --list` e conte por projeto. Se o número subiu depois de mexer em partição, você anulou alguma lista.
3. Comente o porquê no config — é contraintuitivo o bastante pra ser refeito por quem vier depois.

**Ref:** Família Milionária, 2026-07-29 — o `testIgnore` do projeto `chromium` (adicionado 1 dia antes) anulou a lista de 11 specs com config própria; a rodada "4 failed" era 3 ruídos + 1 defeito. Commit `569e4c8`.
