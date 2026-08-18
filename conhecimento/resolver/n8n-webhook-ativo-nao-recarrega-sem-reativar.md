## n8n workflow já ATIVO não recarrega código de node só com update via API — precisa desativar→reativar (vale pra QUALQUER trigger, não só webhook) {#n8n-webhook-ativo-nao-recarrega-sem-reativar}

`tags: n8n, webhook, schedule trigger, workflow ativo, update via api, PATCH workflow, code node, versionId, activate, deactivate, versao antiga, cache, node code stale, deploy nao pega`

> **Correção 2026-08-12:** a versão original desta entrada dizia "workflow **webhook**" e supunha que
> schedule trigger provavelmente não precisava. **A suposição foi REFUTADA com prova direta:** o
> mesmo cache atinge **schedule trigger** igual. Não restrinja o ciclo de reload ao tipo de trigger —
> aplique a todo workflow ATIVO que receber update via API. Ver "Como provar" abaixo.

**Sintoma:** você corrige o `jsCode`/parâmetros de um node num workflow **já ATIVO** via
`PATCH /rest/workflows/{id}` (script de deploy, não o editor visual), confirma que o JSON salvo no
n8n bate byte-a-byte com o arquivo local corrigido — e mesmo assim, executar de verdade continua
exibindo o comportamento ANTIGO (o bug que você acabou de corrigir ainda acontece).

**Como provar em 30 segundos, sem adivinhar:** o objeto de erro da execução carrega a expressão
**como o runtime a avaliou**, no campo `cause`. Decodifique `execution.data` (formato `flatted`) e
leia `resultData.error.cause` — se ele mostra uma expressão que **não existe mais** no JSON em
produção, está provado que o handler roda código velho. Foi assim que o caso de 2026-08-12 fechou:
o `cause` exibia `=https://{{ $env.KOMMO_SUBDOMAIN }}.kommo.com/...` enquanto o JSON deployado já
tinha a URL literal, sem nenhum `$env`.

**Causa raiz:** o handler HTTP registrado pra um webhook trigger é montado/cacheado no momento da
**ativação** do workflow. Atualizar o conteúdo via API muda o registro no banco, mas não força o
handler já registrado a recarregar — ele continua servindo a versão compilada de quando foi ativado
pela última vez. Isso é diferente de editar pelo editor visual do n8n, que internamente já dispara
esse refresh como parte do próprio fluxo de salvar.

**Solução:** depois de TODO `--apply`/update num workflow webhook que já está ativo, rodar um ciclo
`deactivate` → `activate` (via API, `POST /rest/workflows/{id}/deactivate` e `/activate`, cada um
precisa do `versionId` atual no corpo — ver achado irmão sobre o bug do `activate`/`deactivate`
nesse mesmo projeto) antes de considerar o fix "no ar". Sem isso, o dry-run/diff mostra tudo certo e
o comportamento ao vivo continua errado — falso positivo perigoso.

**Sinal de alerta:** "o JSON deployado é idêntico ao local, testei a mesma lógica isolada e funciona,
mas ao vivo continua com o bug antigo" — isso não é "deploy não pegou o arquivo", é "o handler nunca
recarregou".

**Faça o deploy fazer isso sozinho.** Enquanto o reload for um passo manual "que você lembra de
rodar", ele vai ser esquecido no dia em que importar. Ponha o ciclo dentro do próprio comando de
apply, e faça ele **falhar alto** se o `activate` quebrar depois do `deactivate` ter passado — senão
o workflow fica DESATIVADO em silêncio, que é fail-safe pro usuário final e fail-SILENT pro produto
(a fila congela sem erro nenhum aparecer).

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-11/12 — confirmado repetidas vezes no `01-enfileirar.json`
(webhook) durante uma sequência de ~8 fixes em cadeia. Em 2026-08-12 o MESMO cache foi confirmado em
`02-dispatch-worker` e `04-recovery`, ambos **schedule trigger**: o `04` falhava 100% das execuções
a cada 5min, por horas, com `access to env vars denied` num `$env` que o JSON em produção não tinha
mais. Virou código (`reload_active_workflow()` chamado pelo próprio `--apply`).
