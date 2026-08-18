## Teste de fuso passa VERDE na sua máquina e o código quebra em produção — o teste validou o `TZ` do dev, não o do runtime {#teste-timezone-passa-por-coincidencia-da-maquina}

`tags: timezone, fuso horario, TZ, teste falso verde, UTC, container, new Date, toLocaleString, America/Campo_Grande, America/Cuiaba, agendamento, next_send_at, teste valida ambiente errado`

**Sintoma:** a suíte está verde, o teste é sério (roda a lógica REAL extraída do artefato, não uma
cópia), as asserções conferem timestamps absolutos — e mesmo assim o valor gravado em produção sai
com algumas horas de diferença do que o teste afirma.

**Causa raiz:** o código converte "hora local" → instante absoluto usando o fuso **da máquina**, e o
teste roda numa máquina cujo fuso por acaso coincide com o do negócio. Em JS o padrão é
`new Date(d.toLocaleString('en-US', { timeZone: tz }))`: o `toLocaleString` acerta o fuso alvo, mas
o `new Date(string)` reinterpreta a string no fuso **do processo**. Na máquina do dev (UTC-4, mesmo
offset do cliente) os dois se cancelam e o resultado sai certo; no container (UTC) sobra a diferença
inteira. Em SQL o gêmeo é montar um `timestamp` *naive* (`::date + hora_local`) e atribuir a uma
coluna `timestamptz`: o Postgres completa o fuso com o `TimeZone` **da sessão**, que no container é
`UTC`.

Confirme em um comando, antes de discutir qualquer outra hipótese:

```bash
TZ=UTC node tests/test_alguma_logica_de_horario.mjs   # roda o MESMO teste no fuso do runtime
psql -c "SHOW TimeZone;"                              # o fuso que o Postgres vai assumir
```

Se o teste reprova sob `TZ=UTC` e passa sem ele, o teste nunca testou a lógica — testou o seu
relógio.

**Solução:** (1) fixe o fuso no harness de teste (ou rode a suíte nos dois fusos: o do runtime e um
diferente — um código correto passa nos dois); (2) no código, nunca deixe a conversão de volta pra
instante absoluto depender do fuso do processo — em SQL, feche com `AT TIME ZONE <tz>` explícito
(`(expr_naive) AT TIME ZONE c.timezone`); em JS, calcule o offset do fuso alvo e aplique, em vez de
reparsear string.

**Por que passa despercebido:** o erro é constante e do tamanho exato do offset, então o valor
*parece* plausível — é uma hora do dia válida, só que errada. E some completamente da revisão de
código, porque a linha suspeita é a que "já converte pro fuso do cliente".

**Irmão conceitual:** [#teste-verde-dependencia-morre-antes-do-gate] e o caso do realm do `vm` — nos
três, o teste está verde porque mediu o ambiente errado, não porque o código está certo.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12. Máquina do dev = `America/Cuiaba` (UTC-4), cliente =
`America/Campo_Grande` (UTC-4), container n8n = UTC. `TZ=UTC node tests/test_next_delay_logic.mjs`
reprovou 2 dos 3 testes, devolvendo `08:00:00.000Z` onde o teste exigia `12:00:00.000Z` — as mesmas
4h que apareciam gravadas em `next_send_at` no banco de produção.

### Receita do conserto (2026-08-13) — as duas metades

**JS — nunca reparseie string; leia partes e reconstrua.** `formatToParts` dá a hora de parede no
fuso alvo sem passar por string ambígua, e o caminho de volta é offset explícito:

```js
function wallParts(date, zone) {            // hora de parede em `zone`, independe da maquina
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone, hourCycle: 'h23',       // NAO hour12:false -- ver armadilha abaixo
    year:'numeric', month:'2-digit', day:'2-digit',
    hour:'2-digit', minute:'2-digit', second:'2-digit',
  });
  const p = {}; for (const x of fmt.formatToParts(date)) p[x.type] = x.value;
  return { y:+p.year, mo:+p.month, d:+p.day, h:+p.hour % 24, mi:+p.minute, s:+p.second };
}
function tzOffsetMs(date, zone) {           // parede - UTC (negativo a oeste)
  const w = wallParts(date, zone);
  return Date.UTC(w.y, w.mo-1, w.d, w.h, w.mi, w.s) - (date.getTime() - date.getMilliseconds());
}
function utcFromWall(y, mo, d, h, mi, zone) {   // hora de parede -> instante UTC
  const wallAsUtc = Date.UTC(y, mo-1, d, h, mi, 0, 0);
  let guess = wallAsUtc;
  for (let i = 0; i < 2; i++) guess = wallAsUtc - tzOffsetMs(new Date(guess), zone);
  return new Date(guess);                       // 2 passadas cobrem virada de DST
}
```

E **role o dia em `Date.UTC`**, nunca com `setDate()` num Date construído a partir da hora de parede
— `setDate`/`setHours` operam no fuso do processo e reintroduzem o bug pela porta dos fundos.

⚠️ **Armadilha do `hour12: false`:** algumas implementações formatam meia-noite como hora **"24"**
(ciclo h24). Peça `hourCycle: 'h23'`. Os dois **não coexistem** — se `hour12` estiver presente, ele
sobrescreve `hourCycle`, então trocar um pelo outro é obrigatório, não cosmético.

**Teste — matriz de fusos, não "rodar nos dois".** Deixar isso na disciplina de quem roda garante
que um dia não roda. Faça o arquivo se re-executar:

```js
const TZ_MATRIX = ["UTC", "America/Campo_Grande", "Asia/Tokyo", "America/Los_Angeles"];
if (!process.env.MEU_TZ_CHILD) {
  const { spawnSync } = await import("node:child_process");
  let falhou = false;
  for (const tz of TZ_MATRIX) {
    const r = spawnSync(process.execPath, [fileURLToPath(import.meta.url)],
      { env: { ...process.env, TZ: tz, MEU_TZ_CHILD: "1" }, encoding: "utf-8" });
    process.stdout.write(`\n== TZ=${tz} ==\n${r.stdout || ""}`);
    if (r.status !== 0) { falhou = true; process.stderr.write(r.stderr || ""); }
  }
  process.exit(falhou ? 1 : 0);
}
```

Do lado do Postgres o equivalente é forçar `SET TIME ZONE '<tz>'` na sessão dentro do teste e exigir
**o mesmo resultado** em todos — é isso que prova que o `AT TIME ZONE` explícito está fazendo o
trabalho, e não o default do servidor.

**Pegue o caso que sai do fuso da equipe.** Os 3 primeiros testes que escrevi usavam
`America/Campo_Grande` e passaram de primeira — o defeito real só apareceu no caso `Asia/Tokyo`
(UTC+9), e por um motivo que nem era o fuso: ver
[#helper-de-teste-descarta-override-em-silencio].
