## Autorização R20 sem `timestamp_unix` bloqueia em silêncio {#autorizacao-r20-sem-timestamp-unix-bloqueia-em-silencio}

`tags: r20, external-action-guard, hooks, autorizacao, acao-externa, json, timestamp-unix, epoch, R23`

**Sintoma:** o agente escreve `.percus/acao-externa-autorizada.json` com `id`, `motivo` e
`autorizado_em` (string ISO 8601) preenchidos, na raiz correta, com `consumido: false` — e
a primeira ação externa (`ssh vps-auto ...`) é bloqueada do mesmo jeito que se o arquivo não
existisse: `"acao externa publica requer aprovacao explicita do operador (R20)"`. Não há
menção a JSON inválido nem a campo faltando na mensagem de bloqueio — o guard simplesmente
cai no ramo "sem autorização".

**Causa:** `external-action-guard.ps1` calcula a idade da autorização em **epoch puro**:

```powershell
$agoraUnix = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
$idadeSeg = $agoraUnix - $auth.timestamp_unix
if ($idadeSeg -ge 0 -and $idadeSeg -lt 3600) { ...libera... }
```

Ele lê `$auth.timestamp_unix` — **não** `autorizado_em`. Se o campo não existe no JSON,
`$auth.timestamp_unix` é `$null`; em PowerShell, `$agoraUnix - $null` avalia para
`$agoraUnix` (não lança erro, não vira `$null` — vira o próprio timestamp atual), então
`$idadeSeg` fica na casa dos **bilhões de segundos**, falha a checagem `-lt 3600`, e o
fluxo cai pro bloqueio padrão — sem nunca entrar no `catch` que logaria "falha ao processar
autorização em lote". O comentário do próprio script (linhas 203-206) até explica por que
epoch é usado em vez de `DateTime` local, mas não avisa que os DOIS campos são obrigatórios
— a string ISO por si só não é lida em lugar nenhum do fluxo de decisão.

**Solução:** todo arquivo de autorização R20 precisa dos dois campos, e o epoch é o que
importa de verdade:

```json
{
  "id": "...",
  "consumido": false,
  "autorizado_em": "2026-09-12T19:13:04Z",
  "timestamp_unix": 1789240384,
  "motivo": "..."
}
```

Gere o par junto: `date -u +%s` (epoch) e `date -u +"%Y-%m-%dT%H:%M:%SZ"` (ISO, só para
leitura humana) na mesma chamada, e escreva os dois no arquivo antes da primeira tentativa
de ação guardada — testar sem `timestamp_unix` e só depois descobrir por leitura do hook
`.ps1` custa uma rodada de bloqueio evitável.

Aparentado: `guard-r20-bloqueia-a-gravacao-da-propria-autorizacao` (a gravação em si sendo
bloqueada) — este verbete cobre o caso em que a gravação passa, mas a autorização gravada
não é reconhecida pelo hook por faltar o campo que ele de fato lê.
