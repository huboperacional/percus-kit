## E2E fixado em produção não prova código que ainda não foi deployado {#e2e-contra-producao-nao-prova-codigo-nao-deployado}

`tags: playwright, e2e, baseURL, deploy, falso-verde, producao, gate final, i18n, verificacao antes de completude`

**Contexto:** suíte Playwright cujo `playwright.config.ts` fixa
`baseURL: 'https://...'` (produção) sempre, com comentário explícito
justificando ("evita CORS local"). Terminei uma fase inteira de mudanças de
código (i18n, 40+ arquivos, 4 tasks + reconciliação, tudo commitado e com
gate local 100% verde) e rodei a suíte E2E completa como "prova final" antes
de marcar a fase como `[5-T]` (testada).

**O erro quase cometido:** 84/84 passou, zero flaky, mesma contagem da
baseline — pareceu a prova que faltava. Só ao escrever a entrada do PLANO.md
resumindo o resultado é que percebi: **nenhum commit da fase tinha sido
deployado**. O `baseURL` da suíte aponta pra produção incondicionalmente
(a menos que `E2E_BASE_URL` seja sobrescrita) — a suíte mediu o frontend
**já em produção**, sem nenhuma linha do meu trabalho. O 84/84 confirmava
"a baseline antiga não regrediu", não "a fase nova funciona".

**Por que é fácil cair nisso:** o comando (`npm run e2e:run`), a saída
(84/84, verde, zero flaky) e até a contagem (idêntica à baseline documentada
antes da fase) são exatamente o que se esperaria ver numa prova bem-sucedida.
Nada no output do Playwright avisa "isto não testou seu código" — só o
`baseURL` do config revela isso, e ninguém relê o config depois de já
confiar na suíte.

**Como aplicar**
1. Antes de rodar qualquer E2E como prova de uma mudança de CÓDIGO (não de
   infra/dado), leia o `baseURL`/`webServer` do config. Se aponta pra uma
   URL fixa de produção sem servir o build local, a suíte só valida o que
   **já está deployado** — nunca o working tree.
2. Trate "gate local verde + suite completa" e "deploy + validação em
   produção" como dois estágios SEPARADOS e sequenciais, nunca like o
   segundo prova o primeiro por engano. `[5-T]`/"testado de verdade" exige
   o SEGUNDO estágio ter de fato acontecido.
3. Se o objetivo é medir a mudança nova antes do deploy, use
   `E2E_BASE_URL` (ou equivalente) apontando pro build local/staging — não
   confie no comando padrão só porque ele "roda sem erro".
4. Ao escrever o registro de conclusão (PLANO/HANDOFF/changelog), pergunte
   explicitamente "o que essa medição realmente exercitou?" antes de citar
   o número — é o momento em que esse tipo de erro tende a aparecer, porque
   força reler o que foi de fato medido.
