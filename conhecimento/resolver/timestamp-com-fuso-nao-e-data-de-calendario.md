## Formatador de DATA DE CALENDÁRIO (`vencimento`, `competência`) não serve pra INSTANTE com fuso (`criado_em` de evento/notificação) {#timestamp-com-fuso-nao-e-data-de-calendario}

`tags: timezone, datetime, DateTime(timezone=True), formatacao, frontend, Intl.DateTimeFormat, R23`

**Contexto:** produto com dois tipos de campo temporal que PARECEM iguais no frontend (os dois
chegam como string ISO) mas significam coisas diferentes: (1) data de calendário —
`vencimento`, `competência` — onde a HORA não importa e o valor tem que renderizar o MESMO dia
em qualquer fuso; (2) instante — `criado_em` de um evento/notificação — onde a hora importa e o
valor tem que renderizar convertido pro fuso de quem olha.

**O que ninguém nota:** um formatador escrito pro caso (1) costuma FATIAR a string
(`iso.slice(0, 10)`) e montar `new Date(ano, mes-1, dia)` — meia-noite LOCAL, de propósito, pra
não sofrer o deslocamento clássico de `new Date('2026-08-10')` (que o JS interpreta como UTC e
em fuso negativo mostra um dia antes). Esse formatador é CORRETO pro caso (1) e SILENCIOSAMENTE
ERRADO pro caso (2): fatiar os 10 primeiros caracteres de um instante com offset (`"2026-09-03T2
1:00:00-04:00"`) ignora a hora E o offset, e o valor renderizado pode ser o dia ERRADO (não só a
hora errada) se o instante cair perto da virada de dia UTC.

**Sintoma medido (Empresa Milionária, 2026-09-03):** `EventoTitulo.criado_em` chega ao frontend
SEM fuso (naive) — decisão registrada no próprio comentário de `TelaTituloDetalhe.tsx`, e por
isso o formatador de data-de-calendário (`fmt.data()`) é usado ali de propósito, aceitando perder
a hora. `Notificacao.criado_em`, campo NOVO e diferente, é `DateTime(timezone=True)` no modelo —
carrega offset de verdade. Reusar `fmt.data()` nele seria o MESMO padrão de código (`fmt.data(x.
criado_em)`) produzindo o resultado ERRADO por uma razão que só aparece lendo os DOIS modelos
lado a lado — o comentário do primeiro caso não avisa sobre o segundo.

**Fix:** campo de INSTANTE com fuso pede formatador PRÓPRIO — `new Date(iso)` direto (que
interpreta o offset corretamente, ao contrário da fatia sem `Date`) e `Intl.DateTimeFormat` com
`hour`/`minute` além de `day`/`month`, no locale de quem está vendo.

**Como discriminar os dois casos ao ler um modelo Python novo:** `DateTime(timezone=True)` no
modelo → o campo carrega fuso, formatador de instante. `DateTime()` sem `timezone=True`, ou um
comentário explícito dizendo "chega sem fuso" → formatador de data de calendário, nunca de
instante (a hora que ele mostraria seria inventada, não medida).

**Relacionado:** o comentário original em `TelaTituloDetalhe.tsx` sobre `EventoTitulo.criado_em`
já registrava a MESMA classe de decisão pro caso naive — este verbete generaliza pro caso oposto
(campo COM fuso), que é onde reusar o formatador errado por analogia falha.
