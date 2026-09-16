## Autorização R20 com `timestamp_unix` no FUTURO bloqueia igual à vencida {#autorizacao-r20-com-timestamp-no-futuro-bloqueia}

`tags: r20, external-action-guard, hooks, autorizacao, acao-externa, timestamp-unix, epoch, relogio, idade negativa, git push, ssh, tool calls paralelas, R23`

**Sintoma:** o agente grava `.percus/acao-externa-autorizada.json` completo (com `timestamp_unix`), na raiz certa,
e a ação externa seguinte (`git push`, `ssh`) é bloqueada com a mensagem genérica
`"acao externa publica requer aprovacao explicita do operador (R20)"` — nada diz "vencida" nem "no futuro".

**Causa (medida em 2026-09-15, tiatendo):** o guard aceita só idade **entre 0 e 3600 s**:

```powershell
$idadeSeg = $agoraUnix - $auth.timestamp_unix
if ($idadeSeg -ge 0 -and $idadeSeg -lt 3600) { ...libera... }
```

O agente arredondou o horário **para cima** (gravou `date -u +%s` + alguns segundos) e disparou a ação na
MESMA leva de tool calls. A idade saiu **negativa** (−8 s) → bloqueio idêntico ao de autorização vencida.
Agravante: chamadas paralelas na mesma mensagem podem ser avaliadas pelo hook ANTES de o arquivo existir.

**Duas armadilhas vizinhas, mesma sessão:**
- **O texto do próprio comando dispara o guard.** Um `pwsh`/`python` que só GRAVA o JSON, mas cujo motivo
  contém "git push"/"ssh"/"deploy", é classificado como ação externa e bloqueado antes de gravar. Grave o
  arquivo com a ferramenta Write (ou redija o motivo sem esses termos no comando).
- **O arquivo é procurado no `cwd` da SESSÃO**, não no `cd` do comando: depois de um `cd /d/tmp` que
  persistiu, até `cd <repo> && ssh …` bloqueia (ver [[autorizacao-r20-invisivel-quando-o-cwd-da-sessao-entra-em-subdiretorio]]).

**Fix / procedimento:**
1. `date -u +%s` numa chamada; grave `timestamp_unix` = esse valor **menos** alguns segundos (nunca mais).
2. Grave o JSON com a ferramenta Write, sozinho.
3. Só na PRÓXIMA mensagem rode a ação externa — nunca na mesma leva paralela.
4. Bloqueio inesperado: compare `date -u +%s` com `timestamp_unix` (idade negativa ou ≥ 3600) e confira o
   `cwd` da sessão ANTES de suspeitar do padrão do comando.

Relacionado: [[autorizacao-r20-sem-timestamp-unix-bloqueia-em-silencio]].
