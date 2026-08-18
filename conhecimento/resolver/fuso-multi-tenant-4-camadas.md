## Bug de fuso multi-tenant tem 4 camadas — e a mais traiçoeira é o YAML, não o código {#fuso-multi-tenant-4-camadas}

`tags: timezone, fuso, multi-tenant, yaml do tenant, cadeia de fallback, AT TIME ZONE, date_trunc, timestamptz, EXTRACT EPOCH, toBrasilia, rename nao shim, scp yaml prod, teste-lint`

**Sintoma:** relatório mostra dado no dia/hora errados pra tenant fora do fuso "padrão" da equipe.
No caso real (tiatendo, cliente em Dourados/MS = UTC−4): pedido às 20:00 **locais** virava 00:00 UTC
do dia seguinte → **o jantar inteiro**, pico de faturamento do restaurante, caía no dia da semana errado.

**As 4 camadas — corrigir só uma NÃO resolve:**
1. **Config (YAML do tenant)** — o fuso declarado está errado, ou mora num bloco que a cadeia de
   resolução não lê. **É a mais traiçoeira: com o YAML errado, o código corrigido devolve hora errada
   OBEDIENTEMENTE.** Ninguém desconfia porque o código "está certo".
2. **Cadeia de fallback** — o resolvedor só olha alguns elos e cai no default **em silêncio**.
3. **SQL** — `EXTRACT(DOW/WEEK/YEAR/HOUR ...)`, `date_trunc('day', ...)`, `::date` sobre coluna
   `timestamptz` roda no fuso da SESSÃO do banco (UTC), não do tenant.
4. **Render** — helper de formatação com fuso cravado (`toBrasilia`, `BRT = -03:00`).

**⚠️ A armadilha que quase me pegou: consertar a cadeia SOZINHA pode PIORAR tenants.**
Dois tenants declaravam `America/New_York` num bloco que a cadeia quebrada nunca lia — resolviam o
default (BRT) **por acidente, e por acaso certo**. Consertar a cadeia os faria resolver New_York **de
verdade**, deslocando 5h. Fix da cadeia e correção dos YAMLs têm que ir no **MESMO commit**.

**Detalhes de SQL que custam caro:**
- **Round-trip DUPLO** pro "hoje" do tenant:
  `date_trunc('day', now() AT TIME ZONE $tz) AT TIME ZONE $tz`. A 1ª conversão leva pro relógio local
  (naive), o `date_trunc` acha a meia-noite local, a 2ª volta pra `timestamptz` comparável com a
  coluna. **Aplicar só a 1ª produz OUTRO resultado errado, não o certo.**
- **`AT TIME ZONE` depende do TIPO da coluna**: sobre `timestamptz` devolve naive; sobre `timestamp`
  naive devolve `timestamptz` — e aí a dupla aplicação **inverte o sinal**. Pré-voo obrigatório em
  `information_schema.columns` antes de aplicar.
- **`EXTRACT(EPOCH FROM (a - b))` é IMUNE a fuso** (subtração = intervalo). "Corrigir" quebra a métrica
  de duração.

**Migração do render: RENAME, não shim.** Trocar `toBrasilia` → `toTenantTime(dt, tz, fmt)` com tz
obrigatório e **apagando o nome antigo** faz call site esquecido quebrar **no import**, não em produção.
Um shim com default preserva exatamente o modo silencioso pelo qual o bug sobreviveu.

**⚠️ NUNCA `scp` um YAML de tenant por cima do de produção.** Os arquivos de prod divergem do repo
(chaves, flags, campos operacionais). Faça `diff` primeiro e edite **só a linha do fuso**, in-place
(`sed`). No caso real, o arquivo de prod tinha 179 linhas contra 163 do repo.

**Fechar com trava, não com documentação.** O bug reapareceu **3× em um único dia** com a regra já
escrita na memória do projeto. Um teste-lint que varre o código atrás do padrão errado é o que segura.
Dois critérios de aceite: (a) tem que pegar as **instâncias históricas reais** — se alguma escapar, o
desenho está errado e **não se ajusta o corpus pra passar**; (b) **não pode acusar os casos corretos**
(os `EPOCH` de duração), senão vira ruído e alguém desliga na primeira semana.

**Ref:** tiatendo `0.229.0`→`0.231.0` (2026-07-19), spec `2026-07-18-fuso-do-tenant-sweep-design.md`.
