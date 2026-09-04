## `mock-scan` casa a PALAVRA "hardcoded", não o sentido da frase {#mock-scan-casa-a-palavra-nao-o-sentido-da-frase}

`tags: mock-scan, pre-commit, R3, hook, falso positivo, comentário, hardcoded, texto sobre a regra`

**Sintoma:** `git commit` bloqueado por `mock-scan-pre-commit` (R3) apontando uma linha de
**comentário** que usa a palavra "hardcoded" — mas o comentário está dizendo o OPOSTO: que aquele
valor especificamente **não** está hardcoded, e por quê.

**Exemplo real** (Empresa Milionária, 2026-09-03/04, helper novo de teste R1):

```ts
/** Container e nome do banco... O NOME do container muda por sessão (não é
 *  constante, como a porta): quem sobe a janela R20 escolhe, e por isso
 *  entra por variável de ambiente, não hardcoded aqui — mesmo raciocínio
 *  de `$APP_PWD` no README. */
export function containerR1(): string {
  const nome = process.env.R1_PG_CONTAINER
  ...
```

O código faz exatamente a coisa certa (lê de `process.env`, não embute o valor) — mas o scanner
não lê semântica, lê substring. "hardcoded" no texto é suficiente pra disparar, esteja ele
afirmando ou negando.

**Causa raiz:** é a MESMA classe do achado `texto-sobre-a-regra-quebra-a-guarda` (documentado
para guardas de teste que julgam pela presença da palavra, não pelo efeito) — aqui aplicada ao
scanner de mock/placeholder do pre-commit. Um comentário que **explica** por que algo não é mock,
não é TODO, não é hardcoded, contém a mesma palavra-gatilho que o código problemático conteria.

**Solução:** confirme que é falso positivo lendo a linha:crime que o hook aponta (ele sempre
mostra arquivo:linha) — se o comentário está *negando* a prática, não descrevendo-a, é seguro
pular. Use `MOCK-OK: <motivo>` no **primeiro** `-m` do `git commit` (ver
`dois-hooks-pre-commit-r11-mock-scan.md` para a armadilha de colocar o marcador num `-m`
subsequente, que o hook nunca lê). Não vale reescrever o comentário só para escapar do scanner —
isso troca clareza por conformidade com uma ferramenta que está errada aqui.

**Ref:** Empresa Milionária, sessão `empresa-milionaria-80` (2026-09-03/04) — commit `6637379`,
`tests/r1/helpers/sqlR1.ts:35`.
