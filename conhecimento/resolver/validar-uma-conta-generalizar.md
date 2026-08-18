## Validar UMA conta numa API multi-tenant e generalizar o resultado {#validar-uma-conta-generalizar}

`tags: multi-tenant validacao conta amostra generalizar api teste`

**Sintoma:** um probe de validação (ex.: `validateOnly`) passa contra a conta do piloto, você conclui
"o campo X não é obrigatório → sem mudança de código", ship, e no primeiro cliente seguinte o mesmo
payload é **rejeitado**.

**Caso real (Paid Media, 2026-07-16, migração Google Ads → Data Manager API):** a "Fase 0" rodou
`validateOnly` com gclid real na conta do piloto (Uni) **sem** `transactionId` → **200**. Conclusão
registrada: *"transactionId não é exigido quando há gclid → zero mudança no router"*. Ao migrar TODOS
os tenants, o Moper devolveu `events[0].transaction_id | REQUIRED_FIELD_MISSING` — **o requisito
depende da conversion action**, não da API. Titanium e Uni passavam; Moper não. O conselho R11
(DeepSeek + Cross-Claude) tinha marcado exatamente esse campo como **risco de consenso** e o probe de
uma conta deu um **falso all-clear** que calou o alerta deles.

**Why:** APIs multi-tenant validam contra a configuração do *destino* (tipo da conversion action,
categoria, política da conta), não só contra o schema do payload. Um 200 prova "válido **para aquele
destino**", nunca "válido para a API". O viés é forte porque o probe parece autoridade — veio do
próprio Google.

**How to apply:**
1. **Probe de contrato roda em N destinos heterogêneos, não em 1.** Escolha destinos que difiram no
   eixo que importa (aqui: tipo/categoria da conversion action — lead-gen vs ecommerce vs chamada).
   Um único destino só prova o caminho feliz dele.
2. **Se um review/conselho marcou o campo como risco e o seu probe "desmentiu", desconfie do probe,
   não do conselho.** Um all-clear que cancela um risco de consenso merece uma segunda amostra antes
   de virar decisão de arquitetura.
3. **Prefira o fix barato ao "não precisa".** Threadar um id estável custava ~5 linhas; a conclusão
   "não precisa" custou um ciclo de descoberta em produção. Quando o campo é opcional-ou-obrigatório
   *dependendo do destino*, **mande sempre** (se for inofensivo onde é opcional).
4. **O id tem que ser ESTÁVEL, nunca `uuid4()` na hora do envio** — `transactionId`/`orderId` são
   chave de deduplicação: um id novo a cada retry conta a conversão duas vezes. Reuse o id que já
   deduplica em outro canal (aqui: o `event_id` que o Meta/TikTok CAPI já usava) ou derive
   deterministicamente (`wa-lead-{conv_id}`).
5. **Migre em lote cedo, não só o piloto.** Foi o "migra todos" que expôs o erro no mesmo dia; migrar
   só o piloto teria escondido até o próximo cliente entrar — com o sintoma longe da causa.

**Corolário (mesma sessão):** o erro real ficou escondido atrás de um genérico *"There was a problem
with the request."* porque o extrator de erro só conhecia o shape da API antiga
(`error.details[].errors[]`) e a nova usa `google.rpc.BadRequest.fieldViolations`. **Ao trocar de API,
o parser de erro é parte da migração** — senão o primeiro erro real chega ilegível justo quando você
mais precisa dele. Guarde `isinstance` em todo `.get()` do extrator: ele roda no caminho de erro, e uma
exceção ali escapa (o `try/except` costuma cobrir só o `json.loads`) e derruba o request.

**Ref:** Paid Media Automation — cont.105.2 (2026-07-16). Fix `0f545f7` (threading do `event_id` →
`transaction_id`, parser dos 2 shapes) + `d0b567b` (guarda contra corpo malformado). Memória
`project_google_data_manager_migration`.
