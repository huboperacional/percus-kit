## Resgatar linhas órfãs de migration aditiva (coluna nova NULL) via backfill + path real do coletor {#linhas-orfas-migration-aditiva}

`tags: migration aditiva, coluna nova, NULL, backfill, reaper, IS NOT NULL, linha orfa, docker exec, asyncio.run, dispatch sem persistir, scan cross-tenant`

**Sintoma:** um reaper filtra `WHERE col IS NOT NULL AND col < cutoff` (fail-safe: não age no que não
sabe datar). Linhas criadas ANTES da migration que adicionou `col` ficam `col=NULL` → nunca são pegas
(presas pra sempre). Caso tiatendo: conversa pausada antes da mig 100 (`bot_paused_at` NULL) ficava
muda; o reaper horário exige `IS NOT NULL`.

**Solução:**
- **Backfill** com proxy defensável (`col = updated_at`) SÓ nas linhas-alvo, guardado
  (`WHERE ... AND col IS NULL AND id = ...`); depois deixe o **loop de produção do próprio serviço**
  agir — ele traz o efeito colateral (notificação) junto, uma vez.
- **NÃO** invoque o path do reaper num `docker exec` bare achando que envia: efeitos que dependem do
  runtime (cliente de canal, tasks com delay) são cortados quando o `asyncio.run` fecha o loop — o
  UPDATE de estado funciona, o dispatch pode não. Invocar manual + disparar direto = risco de 2 cópias.
- Gotcha de inspeção via exec: `from mod import _cache` captura o dict ANTES do rebind — use o RETORNO
  da função de load; rode com cwd/-w correto (relativo a `TENANTS_DIR`/`/app`). E `dispatchResponse`
  (tiatendo) NÃO grava em `messages` (só no canal) — ausência lá ≠ não-enviado.
- Depois: **scan cross-tenant** do mesmo padrão órfão pra saber se é sistêmico.

**Ref:** tiatendo Fabiula (2026-07-17). Memória `project-vitrine-e3-e6-loja-2026-07-17`.
