## Colei o código no agendador de terceiro e "não funcionou" — ele DISPARA, só que como `PageView`, sem cookie e sem click id {#tracking-em-agendador-de-terceiro-dispara-mas-nao-conta}

tags: tracking, pixel, agendador de terceiro, iframe, pageview, click id, fbclid, gclid, cookie de origem, atribuicao, conversao

**Sintoma.** O cliente instala o snippet de tracking no agendador externo (Acuity, Calendly,
similar), a campanha segue gastando e o painel de anúncios continua marcando **0 conversões**. A
leitura fácil — "não instalou" ou "a campanha não converte" — está errada nas duas pontas.

**Como confirmar em 1 query, sem acesso ao painel do cliente.** Procure evento **seu** cujo
`event_source_url` seja de um **domínio que não é do cliente**:

```sql
SELECT created_at, event_name, session_id, google_ads_dispatches, left(event_source_url,120)
FROM tracking.event_log
WHERE tenant_id = :t AND event_source_url ILIKE '%<dominio-do-agendador>%'
ORDER BY created_at DESC;
```

Se voltar linha, **está instalado**. E dá pra auditar *o que exatamente* foi colado sem entrar no
painel dele: o Acuity carrega o código num frame cuja URL leva o próprio snippet em base64 no
parâmetro `c=` — decodificar devolve a tag literal que o cliente colou.

**Causa — três camadas independentes, e passar na primeira não diz nada sobre as outras.**

1. **O loader genérico só sabe emitir `PageView`**, e `PageView` normalmente tem guarda de servidor
   pra nunca despachar (reemitir PageView move régua que não é sua). O próprio registro de despacho
   confessa: `"skipped: pageview nunca despacha"`.
2. **Não há cookie nem sessão.** O cookie de visitante é first-party do domínio do cliente; no
   domínio do agendador é **cross-site** e não viaja. Sem sessão, **sem click id** — e isso é
   permanente, não um bug a consertar.
3. **A página de conversão não recebe a query string da reserva.** Mesmo que o `gclid` tenha chegado
   à página de agendamento, o frame de conversão é outra URL e não o carrega.

**Conserto — pare de perseguir o click id e vá por IDENTIDADE.** Esses agendadores expõem variáveis
que eles mesmos preenchem (no Acuity: `%email%`, `%price%`, `%id%`, `%appointmentType%`, …) e
**nenhuma delas é `gclid`/`utm`/moeda**. O e-mail é a matéria-prima de *enhanced conversions for
leads* (o Google casa o hash de volta no clique) e de *advanced matching* da CAPI. Três cuidados que
só aparecem depois:

- **Moeda não vem.** Só o número. Tirar a moeda de um default embutido manda valor errado por um
  fator de câmbio — pior que mandar sem valor. A fonte certa é a moeda registrada **na conta de
  anúncios**.
- **A variável pode chegar literal.** Se o agendador não substituir, você recebe a string
  `%email%` — hashear isso cria um identificador estável e falso, que casa com nada e polui todo
  tenant. Valide forma de e-mail **antes** de hashear.
- **O frame recarrega.** Sem chave de idempotência (o `%id%` da reserva) a mesma reserva conta duas
  vezes.

**A lição de leitura, que custou 2 dias.** O primeiro disparo apareceu no `event_log` e foi
arquivado como *"curiosidade: nosso loader rodando em domínio de terceiro"*, enquanto o HANDOFF
seguia dizendo "falta instalar no agendador". **Evento seu num domínio que não é do cliente é sinal
de instalação, não esquisitice** — trate como achado, não como ruído.
