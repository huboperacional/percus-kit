## PGlite (`prisma dev`) serializa queries: teste de corrida passa sem o lock e não prova nada {#pglite-serializa-queries-e-nao-prova-lock}

`tags: postgres, pglite, prisma, corrida, lock, advisory-lock, concorrencia, teste, R23`

**Contexto:** critério de aceite do tipo "5 envios simultâneos com 8 vagas usadas terminam em 10, e
não em 13", protegido por `pg_advisory_xact_lock` dentro da transação que conta e grava. O teste
honesto é: comentar o lock e **ver a corrida acontecer** (RED), destravar e ver passar (GREEN).

**O que aconteceu (LiliCalc, 15/09):** com o lock comentado, o script devolvia `OK` sempre. Duas
causas somadas:

1. **`npx prisma dev` é PGlite** — um backend único que atende **uma query por vez**. Prova: cinco
   `pg_sleep(1)` concorrentes levam ~5 s, não ~1 s. Sob concorrência real ele ainda devolve
   `08P01 bind message supplies N parameters, but prepared statement "" requires 0` e derruba o
   banco local.
2. **Mesmo num Postgres de verdade a janela é curta demais.** Entre o `COUNT` e o `INSERT` da mesma
   transação passa ~1 ms num banco local; 30 envios concorrentes não se sobrepõem. Com 50 ms de
   janela, os mesmos 30 envios reservaram **18 vagas num limite de 10** — a vulnerabilidade é real,
   o teste é que não a alcançava.

**Como provar de verdade, sem mudar código de produção:**

- Rodar contra **Postgres real**. Sem Docker nem Postgres instalado, `npm i embedded-postgres` numa
  pasta de scratch resolve (lançar fora da árvore da sessão; `DATABASE_URL` exportada — atenção:
  `dotenv` **não** sobrescreve variável já exportada).
- **Alargar a janela só no script**, com uma extensão do cliente que atrasa a consulta de contagem:

```ts
const dbComLatencia = db.$extends({ query: { leitura: { async count({ args, query }) {
  const r = await query(args);
  await new Promise((ok) => setTimeout(ok, LATENCIA_MS)); // 50 ms: sem isso a corrida não aparece
  return r;
} } } });
```

  A extensão é herdada pelo cliente da transação interativa, então ela alcança o trecho protegido.
  O código de produção não muda — o teste passa a enxergar o que já estava lá.

**Regra:** um teste que não falha sem a proteção não prova a proteção. Se o RED não aparece,
o problema é o ambiente ou a janela — investigue antes de confiar no GREEN.

Relacionado: [[pg-isready-pelo-socket-responde-no-postgres-temporario-do-init]],
[[prisma-dev-morre-quando-a-sessao-troca-de-contexto]].
