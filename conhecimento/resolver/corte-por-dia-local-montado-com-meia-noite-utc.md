## Contagem "há mais de N dias" com dia LOCAL e meia-noite UTC erra a fronteira em 3 ou 4 horas — e o teste em UTC puro não vê {#corte-por-dia-local-montado-com-meia-noite-utc}

`tags: fuso, timezone, ZoneInfo, dia local, claim, scheduler, job diario, contagem, fronteira, meia-noite, UTC, teste que nao discrimina, R11`

**Contexto:** Empresa Milionária, 17/09/2026, V2.3 Task 14 — alerta diário de entregas. O job roda por empresa, no fuso
dela: a janela de hora e o claim do dia usam `agoraUtc.astimezone(ZoneInfo(empresa.fuso))`, decisão escrita na FR
("dia LOCAL no fuso da empresa, nunca o dia UTC"). A contagem "entregas pendentes **sem data** criadas há mais de N
dias" montava o corte assim:

```python
corte = dt.datetime.combine(hoje - dt.timedelta(days=N), dt.time.min, tzinfo=dt.timezone.utc)
```

**O defeito:** `hoje` é o dia **local**; `time.min` com `tzinfo=utc` é meia-noite **UTC**. Em São Paulo (−03) a
meia-noite local do dia do corte é **03h UTC**; em Manaus (−04), **04h UTC**. Tudo o que foi criado nessas 3 a 4 horas
— que, em fuso negativo, é o **fim da noite do dia anterior**, justamente quando a oficina fecha o dia — cai do lado
errado da fronteira e some da contagem por um dia inteiro.

**Por que nenhum teste pegou:** os testes de contagem chamavam a função com `hoje` e `criadoEm` **ambos em UTC puro**,
sem fuso real no cenário. Nessa configuração, meia-noite local e meia-noite UTC coincidem, e o defeito é invisível. A
sabotagem irmã (`<` virando `<=`) também ficou verde por outro motivo: o dado de fronteira nascia **ao meio-dia**, e
nessa hora os dois operadores dão o mesmo resultado.

**Conserto:** monte a meia-noite **no fuso da empresa** e converta:

```python
corte = dt.datetime.combine(hoje - dt.timedelta(days=N), dt.time.min,
                            tzinfo=ZoneInfo(fuso)).astimezone(dt.timezone.utc)
```

A função de contagem passa a **receber o fuso** — se ela recebe `hoje` já local, ela precisa do fuso para saber o que
"meia-noite daquele dia" significa. Data local sem fuso ao lado é meia informação.

**Como testar de verdade (as duas lições juntas):**

1. **Um caso por lado da fronteira, com fuso real.** Em SP: criado às 01h UTC (= 22h do dia anterior local) **conta**;
   às 04h UTC (= 01h local do dia do corte) **não conta**. Repita num segundo fuso (Manaus, −04) para o número 3 não
   virar constante escondida.
2. **O caso-limite tem de nascer no INSTANTE do corte**, não numa hora qualquer: é ali que `<` e `<=` divergem. Depois
   da correção, esse instante é 03h UTC em SP — e não meia-noite UTC, como era antes.
3. **Sabote a mistura, não só o operador:** trocar `ZoneInfo(fuso)` por `timezone.utc` tem de ficar vermelho. Se ficar
   verde, o cenário do teste está em UTC puro e a guarda é falsa.

⚠️ **A janela de hora pode mascarar o claim.** No mesmo job, a decisão "já enviei hoje?" comparava `ultimoEnvio` com o
dia local, então a sabotagem "gravar o dia UTC no claim" passava: o teste só via o `False` da janela. Para discriminar,
**afirme a data GRAVADA** num instante em que os dois dias divergem (01h UTC = 21h do dia anterior em Manaus).

**Relacionados:** `suite-entre-23h-e-meia-noite-da-falso-vermelho-de-fuso.md` (o mesmo assunto pelo lado do relógio da
suíte), `sabotagem-prova-uma-assercao-nao-o-teste.md`.
