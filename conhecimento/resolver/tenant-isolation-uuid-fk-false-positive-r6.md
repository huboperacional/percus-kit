## Isolamento multi-tenant por UUID+FK (sem coluna `tenant_id` redundante) gera falso positivo em review automático {#tenant-isolation-uuid-fk-false-positive-r6}

`tags: R6, isolamento por tenant, falso positivo, review automatico, UUID, foreign key, conversation_id`

**Contexto:** tabela auxiliar 1:1 (ex. `session_state`) chaveada só por uma FK pra um recurso pai
(`conversation_id UUID REFERENCES conversations(id)`), sem coluna `tenant_id` própria. Função que
lê/escreve nessa tabela recebe só o id da FK como parâmetro, sem `tenantId` explícito.

**Sintoma:** review automático (DeepSeek ou similar) marca `[SEV: risco]` citando violação de
regra de isolamento por tenant ("query sem tenant_id explícito pode vazar entre tenants"), mesmo
quando a função é segura.

**Causa raiz do falso positivo:** o reviewer aplica a heurística geral (toda query nova deveria
filtrar por `tenant_id`) sem verificar que ESSA tabela específica usa outro mecanismo de
isolamento — o id que chega já nasceu amarrado a um tenant único (resolvido no servidor a partir
de `tenantId` antes de virar `conversationId`, nunca é input direto/adivinhável do usuário externo)
e a FK/UNIQUE garante que não existe caminho pra um id de um tenant apontar pra dado de outro.
Isolamento "por identidade de chave única resolvida upstream" é equivalente em efeito a um filtro
`WHERE tenant_id=`, só que via mecanismo diferente.

**Como confirmar/refutar rápido:** (1) ler o schema da tabela (`CREATE TABLE`/migration) — se a
chave é `UNIQUE`/`PRIMARY KEY` numa coluna UUID com FK pra uma tabela que JÁ é tenant-scoped, é
seguro; (2) confirmar que o id nunca chega como input direto de fora (sempre resolvido
server-side); (3) checar se o MESMO padrão de chamada (função sem `tenantId`) já existe em outros
call-sites pré-existentes no mesmo arquivo — se sim, não é risco introduzido pelo diff sob review,
é padrão estabelecido.

**Ref:** tiatendo, review de marco C13/C16, sessão 2026-08-06 — `_persistDeliveryPref` chamada com
só `conversationId` (`execution/engine/restaurantOrderFlow.py`/`restaurantCommandOrchestrator.py`);
DeepSeek marcou risco R6, Cross-Claude confirmou falso positivo lendo `session_state` (UNIQUE em
`conversation_id`, FK pra `conversations.id`) + achando 5+ call-sites pré-existentes com o mesmo
padrão.
