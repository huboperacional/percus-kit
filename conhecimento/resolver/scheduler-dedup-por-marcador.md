## Scheduler novo sobre tabela velha: dedup por MARCADOR, senão a linha fóssil engole o 1º disparo {#scheduler-dedup-por-marcador}

`tags: scheduler, cron, dedup, linha fossil, upsert, marcador, report_meta, catch-up, restart, yaml sexagesimal, HH:MM vira 540, contrato de shape, degrade com warning`

**Sintoma:** você troca um job agendado (ex.: relatório semanal domingo 03:00 UTC fixo) por um scheduler por-tenant com dedup persistente numa tabela que o job ANTIGO também escrevia. Na transição, o job antigo já gravou a linha da semana corrente → o scheduler novo vê "já existe" e **pula o 1º envio novo em silêncio**. Ninguém percebe: não há erro, só ausência.

**Solução:**
1. **Linha nova carrega um marcador** (ex.: chave `report_meta` no JSONB de metrics). O dedup checa o MARCADOR, não a existência da linha: linha fóssil (sem marcador) não bloqueia — o 1º disparo novo sobrescreve por cima (upsert).
2. Dedup em memória (`_lastRun` global) **não sobrevive a restart/redeploy** — se o restart cair no dia do disparo, ou duplica ou engole. Persistir na tabela que já tem unique (tenant, período) sai de graça.
3. Semântica catch-up ("1× por semana A PARTIR do instante agendado", não "== hora agendada") tolera o processo fora do ar no horário; o dedup persistente é o que impede o duplo envio.
4. Config de horário vinda de YAML: `report_time: 09:00` SEM aspas é **sexagesimal no YAML 1.1 → int 540** (9×60). O parser tem que aceitar `str "HH:MM"` E `int minutos`, senão o horário configurado é trocado pelo default em silêncio.

**Bônus da mesma sessão (contrato de shape entre caller e helper):** `sendPersonalAlert(config, msg)` lê `config["specialistPhone"]`; um caller passava o `tenantConfig` INTEIRO (onde o campo é `specialist.personal_whatsapp`) → warning logado e **nenhum envio, durante meses**. Helper de envio que "degrada com warning" quando falta campo esconde erro de contrato pra sempre — teste que trava o SHAPE do argumento (`assert config == {"specialistPhone": ...}`) pega na hora.

**Ref:** tiatendo `0.237.0`, reconstrução do Relatório Semanal (`execution/quality/reportScheduler.py` + `execution/plugins/restaurant/weeklyReport.py`).
