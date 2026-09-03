## Rodar só o globalSetup do Playwright com grep vazio ainda dispara o globalTeardown {#playwright-globalsetup-so-com-grep-vazio-ainda-dispara-globalteardown}

`tags: playwright, globalsetup, globalteardown, r1, harness, seed, race`

**Contexto:** Empresa Milionária, harness `empresa-frontend/tests/r1/` (janela R20, 03/09/2026).
Tentativa de rodar `npx playwright test -c tests/r1/playwright.r1.config.ts -g "zzz-nao-existe"`
só para disparar o `globalSetup` (login OTP real + criar a empresa sintética do run) sem rodar
nenhum spec de verdade — a intenção era seedar dado de apoio via SQL direto DEPOIS que a empresa
nascesse, numa chamada Bash separada, antes de rodar o spec de verdade.

**O que quebrou:** o Playwright roda `globalTeardown` ao FIM do processo `test` **mesmo quando
zero testes casaram** ("Error: No tests found"). No harness deste projeto, `global-teardown.ts`
ARQUIVA a empresa sintética do run (`POST /pj/empresas/{id}/arquivamento`) incondicionalmente.
Resultado: a empresa nasceu, ninguém rodou o seed que o operador queria montar nela, e ela já saiu
arquivada antes de qualquer segunda chamada conseguir usá-la.

**O que resolveu:** não separar setup e verificação em duas invocações do `npx playwright test`.
Escrever um `.spec.ts` de verdade (throwaway é aceitável — apagado ao fim da janela R20) cujo
`test.beforeAll` faz TODA a semeadura (chamadas de API onde há rota, `child_process.execFileSync`
com `ssh ... docker exec ... psql` onde não há) e cujo `test()` faz a verificação (navegar +
`page.screenshot`). Assim o `globalTeardown` só arquiva a empresa DEPOIS que o corpo do teste já
rodou — a ordem `globalSetup → spec → globalTeardown` é garantida pelo próprio test runner.

**Achado lateral relevante:** o `beforeAll` default (120s) não cobre ~6 POSTs sequenciais contra
um backend que fala com Postgres pelo túnel efêmero (~470ms/round-trip cada) MAIS um
`execFileSync('ssh', ...)` com handshake SSH frio. `test.setTimeout(300_000)` dentro do
`beforeAll` resolve — sem isso o hook estoura e o teste conta como falha mesmo com a semeadura
tendo terminado (o log mostra o passo final concluído, e MESMO ASSIM "beforeAll hook timeout
exceeded").

**Ref:** sessão Empresa Milionária, 03/09/2026, janelas R20 das Tasks 11 e 12 da fatia 1 de
produção (`zz-producao-screenshot.spec.ts` e `zz-producao-kanban-screenshot.spec.ts`, ambas
apagadas ao fim da janela).
