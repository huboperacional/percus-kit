## Verificação pós-deploy mente por cache de borda — e o corpo do erro desmente o status {#verificacao-pos-deploy-mente-por-cache-de-borda}

`tags: cloudflare, cache de borda, CF-Cache-Status, pos-deploy, falso negativo, rollback precipitado, grep -c vs grep -o, wrangler deployments list, 9106`

**Sintoma:** segundos depois de promover uma versão, o domínio ainda serve o HTML **antigo** e uma rota nova da API responde **404**. Parece deploy falhado, e a tentação imediata é rodar rollback.

**Causa raiz — são DUAS coisas somadas, e só uma delas é cache:**
1. O HTML vem do cache de borda (`CF-Cache-Status: HIT`), então o corpo é o de antes.
2. A propagação da versão leva alguns segundos, então uma medição feita no primeiro instante pega o estado antigo.

🔑 **O que separa "não deployou" de "ainda não propagou/cacheou" é o CORPO, não o status.** Medido em 2026-08-18: a rota respondia `404`, mas o corpo era `{"error":"unauthenticated"}` — que **só o handler novo sabe produzir**. Ou seja, o código já estava no ar e a leitura é que estava velha. Ler só `%{http_code}` teria motivado um rollback desnecessário de um deploy que estava correto.

**Solução:**
1. Furar o cache antes de concluir qualquer coisa: `Cache-Control: no-cache` **e** um parâmetro único (`?cb=$(date +%s)`) — os dois, porque o parâmetro sozinho pode não bastar e o header sozinho pode ser ignorado por camadas intermediárias.
2. Comparar o corpo, não o status.
3. Só então decidir. O cache converge sozinho quando o HTML sai com `public, max-age=0, must-revalidate` (medido: minutos).

⚠️ **Armadilha de medição que se soma a esta, e quase produziu um relatório falso:** `grep -c` conta **linhas que casam**, `grep -o | wc -l` conta **ocorrências**. Comparar um com o outro entre dois estados do mesmo arquivo produz uma "divergência" que não existe. Ao medir antes/depois, use a MESMA contagem dos dois lados — e desconfie de qualquer diferença que apareça só quando os comandos são diferentes.

⚠️ **`wrangler deployments list` não serve pra descobrir a versão viva em conta com token account-owned** — ele bate em `/memberships` e devolve 9106. A lista sai pela API, e ter esse id ANTES de promover é o que torna o rollback uma linha: `GET /accounts/<id>/workers/scripts/<script>/deployments`.

Relacionado: [deploy-worker-cloudflare-conta-de-cliente](deploy-worker-cloudflare-conta-de-cliente.md).
