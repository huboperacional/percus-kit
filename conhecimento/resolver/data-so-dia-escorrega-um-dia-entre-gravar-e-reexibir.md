## Data "só dia" escorrega 24h entre gravar e reexibir quando os dois lados usam fusos diferentes {#data-so-dia-escorrega-um-dia-entre-gravar-e-reexibir}

`tags: data, fuso horario, timezone, toISOString, input type date, validade, off by one, America/Sao_Paulo, UTC, R23`

**Sintoma:** a pessoa escolhe **20/09** num `<input type="date">`, salva, reabre o
registro e o campo mostra **21/09**. Às vezes o bug some na máquina do
desenvolvedor e aparece só em produção — ou o contrário.

**Causa:** gravar e ler usam âncoras de fuso diferentes, e ninguém percebe porque
cada metade, isolada, parece correta.

```ts
// gravação — ancorada em Brasília
new Date("2026-09-20T23:59:59-03:00")   // = 2026-09-21T02:59:59Z

// leitura — em UTC
data.toISOString().slice(0, 10)          // "2026-09-21"  ← já pulou o dia
```

Qualquer instante depois das 21:00 em Brasília já caiu no dia seguinte em UTC.
Como uma validade costuma ser gravada no **fim do dia**, ela cai sempre nessa
faixa: o bug é **determinístico**, não intermitente.

**Por que escapa do teste:** um teste escrito como
`new Date("2026-09-20T23:59:59")` — sem offset — é interpretado no fuso da
máquina. Ele passa no notebook de quem escreveu e falha no CI, ou vice-versa, o
que faz o time culpar o CI em vez do código.

**Correção — manter o par junto, num arquivo só:**

```ts
const OFFSET_BRASILIA = "-03:00";   // o Brasil não tem mais horário de verão

export function dataDoInput(texto: string): Date | null {
  const limpo = texto.trim();
  if (!limpo) return null;
  return new Date(`${limpo}T23:59:59${OFFSET_BRASILIA}`);
}

export function dataParaInput(data: Date | null | undefined): string {
  if (!data) return "";
  // `en-CA` formata como AAAA-MM-DD, que é o que o <input type="date"> exige,
  // e já converte para o fuso pedido.
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric", month: "2-digit", day: "2-digit",
  }).format(data);
}
```

**Duas regras que evitam a classe inteira do problema:**

1. **Nunca use `toISOString().slice(0,10)` para exibir data de calendário.** Ele é
   sempre UTC; só serve quando o dado também é UTC por definição.
2. **Todo teste de data carrega offset explícito** (`...T23:59:59-03:00`). Sem
   ele, o teste mede o fuso da máquina, não o código.

**Teste que fecha o caso** é o de ida e volta, não o de formatação:

```ts
expect(dataParaInput(dataDoInput("2026-09-20"))).toBe("2026-09-20");
```
