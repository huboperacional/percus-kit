## Setup com identificador FIXO + teardown que arquiva = harness que só roda UMA vez por container {#o-seed-que-so-roda-uma-vez-por-container}

`tags: harness de teste, seed, idempotencia, unique, soft delete, playwright, global-setup, R23`

**Sintoma:** a suíte passa na primeira execução. Na segunda, contra o **mesmo** banco, ela morre no
`globalSetup` — antes de qualquer teste — com um erro de unicidade que fala de algo já cadastrado
"mas arquivado", sugerindo uma ação de interface que nenhum setup automatizado faz:

```
POST /usuarios/me/empresas → 422
{"mensagem":"o CNPJ 11222333000181 já está cadastrado neste grupo.
             Ela está ARQUIVADA: desarquive pelo seletor em vez de cadastrar de novo."}
```

**Causa — são DUAS decisões corretas que se anulam:**

1. o `globalSetup` cria a entidade do run com um identificador **fixo** no código;
2. o `globalTeardown` **arquiva** (soft delete) essa entidade no fim, para não poluir listagens.

Cada metade é defensável sozinha. Juntas, a linha arquivada continua ocupando o índice único — que
quase nunca tem cláusula excluindo arquivados — e a execução seguinte não consegue recriar. O
harness passa a ser **descartável junto com o container**, o que ninguém escreveu em lugar nenhum e
custa caro: toda iteração exige derrubar o banco, remigrar e re-semear.

**Conserto — identificador único por run:**

```ts
cnpj: `7${String(Date.now()).slice(-11)}00`.slice(0, 14),
```

As arquivadas se acumulam, e isso é inofensivo quando (a) arquivada não consome cota/limite e
(b) o container é descartável. **Confira as duas antes**, e confira também se o valor fixo não
sustentava alguma asserção — no caso medido, o mesmo número aparecia em 9 outros arquivos, mas
como documento de **pessoa**, não como identificador da entidade do setup: `rg` separou os dois em
segundos e evitou um conserto que quebraria vizinhos.

**Como perceber antes de pagar:** a pergunta é *"o que o teardown faz com a entidade que o setup
cria, e o índice único distingue arquivado?"*. Se o teardown arquiva e o índice não distingue, o
setup tem de gerar identificador novo. Prima de
[[on-conflict-do-update-sem-a-coluna-que-voce-mudou]] — as duas vivem na semeadura e as duas só
aparecem na SEGUNDA execução, que é justamente a que ninguém testa.

Achado em 2026-09-12, projeto Empresa Milionária, no harness de R1 (`tests/r1/global-setup.ts` +
`global-teardown.ts`), ao tentar re-rodar um spec contra o mesmo Postgres efêmero.
