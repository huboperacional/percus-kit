## [5-T] de mudança no loader/script client-side na página real do cliente sem poluir prod {#loader-5t-sem-poluir-prod}

`tags: loader script client-side 5t teste prod staging validacao query-param`

tags: loader, tracking, pixel, fbq, gtag, ttq, CAPI, pmaTrack, [5-T] client-side, Playwright, GTM não carrega headless, injetar script, CNAME first-party, stub fetch, disparo real polui conversão, dispatchEvent submit, capture-phase

**Contexto:** preciso verificar ([5-T]) uma mudança num loader de tracking (script client-side servido pelo tracking service) rodando na página real do cliente. Dois obstáculos: (a) o loader é injetado via **GTM**, que **não dispara em Playwright headless** (consent/Cloudflare/anti-bot) → `window.__pma_loaded`/`pmaTrack` ausentes; (b) disparar um evento real (Lead) dispara a conversão de verdade — **pior ainda pós-go-live** (após remover o `meta_test_event_code`, cai no stream de PRODUÇÃO e polui os dados do cliente).

**Causa raiz:** GTM gated não carrega o loader; e o caminho de conversão (client-side `fbq`/`gtag`/`ttq` + server-side `/tracker`→CAPI) manda pra prod quando exercido de verdade.

**Solução:**
1. **Injeta o loader deployado direto do CNAME first-party** do cliente (`https://track.<cliente>/scripts/loader.js?t=<tenant_id>`) via `<script>` — o CNAME é first-party (CSP aceita; `tracking.ads4pros.com` como third-party pode ser bloqueado). Espera `__pma_loaded===true` + `typeof pmaTrack==='function'`.
2. **Stuba TODAS as vias de envio** antes de exercer: `window.fetch` (captura o body do `/tracker` e retorna `Response('{}',{status:200})` — nada sai), `window.fbq`, `window.gtag`, `window.ttq.track`. Assim você **captura o payload que o loader MANDARIA** (ex.: `custom_data.value`) sem enviar. **Pré-stuba `window.fbq` ANTES de injetar** → o loader pula o próprio init (`if(f.fbq)return`) e não dispara PageView. O loader sobrescreve `gtag`/`ttq` no init → re-stuba DEPOIS da injeção.
3. **Dispara o evento** com `form.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}))` num form sintético **anexado ao body** (pro handler em capture-phase no `document` pegar via bubbling; `dispatchEvent` sintético **não navega/submete** — `isTrusted=false`). Entre casos (ex.: venda vs locação), limpa a chave de dedup no `sessionStorage` (`pma_lead_<method>`).
4. Pra provar o caminho servidor completo (event_log + CAPI) **quando ainda é seguro** (test stream ativo), NÃO stuba — deixa o `/tracker` passar e faz probe no `event_log` (payload_value, `sent_to_meta`/`meta_response_ok`, e `meta_payload_sent ? 'test_event_code'` pra confirmar que foi no stream de teste). Ordena o teste completo ANTES do go-live (remover test_event_code) pra não poluir prod.

**Ref:** [[project_uni_tracking_conversoes]]; Paid Media cont.103 (loader property_value + gate venda/locação).
