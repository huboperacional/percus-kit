## Monitor passivo: o erro que você viu no probe ativo pode NÃO existir no pipe {#monitor-passivo-corpo-do-erro}

`tags: monitor passivo, probe ativo, event_log, corpo do erro, no_click_id, validateOnly, skip deliberado, response_ok, vocabulario de skips, gabarito impossivel`

**Sintoma:** o gabarito do smoke exigia que o `INVALID_CONVERSION_ACTION_TYPE` do Moper (achado da auditoria) aparecesse no `detail` do elo entrega. O monitor devolveu `no_click_id`. Parecia bug do monitor — não era: probe `SELECT ... WHERE google_ads_response_body ILIKE '%INVALID%'` → **0 linhas em 60 tentativas**.

**Causa raiz:** o corpo de um erro só existe onde (a) o request realmente FOI feito e (b) o caminho grava a resposta. Os 60 envios do Moper morrem em `no_click_id` ANTES de chegar na API do Google; o `INVALID_CONVERSION_ACTION_TYPE` da auditoria veio do NOSSO `validateOnly` via service-layer — que **não passa pelo event_log**. Prometer detecção passiva de um erro sem checar onde o corpo mora = gabarito impossível.

**Solução (2 regras):**
1. Antes de prometer que um monitor passivo detecta o erro X, probe **onde o corpo mora**: `SELECT COUNT(*) FILTER (WHERE body ILIKE '%X%')` na tabela que o monitor lê. Se 0, o X é detectável só por sonda ATIVA — documentar, não forçar o gabarito.
2. **Skip deliberado ≠ falha, mas o pipe grava igual**: `ga4_sent_by_site` (auto-bridge suprime envio), `no_click_id` (orgânico), `missing_meta_config` — todos ficam com `response_ok=0` e passivamente são indistinguíveis de falha real. A camada que classifica precisa de um vocabulário de skips (espelhar `_CONFIG_SKIPS` do capi_fanout) antes de pintar o elo de vermelho.

**Ref:** Paid Media Automation, cont.107 (fatia 1 do monitor de saúde, 2026-07-19). O item #4 do gabarito virou "conferir → fatia 2" com prova, em vez de um fix errado na regra. Memória: `project_tracking_health_monitor_fatia1`.
