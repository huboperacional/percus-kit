## Autorizar uma ação externa (git push, vps_exec) bloqueada pelo R20 no MEIO da sessão {#autorizar-acao-externa-bloqueada-no-meio-da-sessao}

`tags: R20, external-action-guard, git push, PERCUS_EXTERNAL_OVERRIDE, autorizar-acao-externa, janela 60 minutos, .percus, acao-externa-autorizada.json`

**Sintoma:** um `git push origin master` (ou outro comando que o `external-action-guard` reconhece
como "ação externa pública") é bloqueado pelo hook com a mensagem `BLOCK (R20): acao externa publica
requer aprovacao explicita do operador`, **mesmo tendo funcionado sem bloqueio várias vezes antes na
MESMA sessão**, com o comando idêntico. Setar a variável de ambiente inline no próprio comando
(`PERCUS_EXTERNAL_OVERRIDE=1 git push ...`) **não resolve** — o hook continua bloqueando.

**Por que a variável de ambiente inline não funciona:** o guard não lê uma env var do processo que
ele intercepta. Ele lê um ARQUIVO: `.percus/acao-externa-autorizada.json`, na raiz do projeto, com
`id`, `motivo` e `timestamp_unix`, válido por **60 minutos** a partir da criação. `PERCUS_EXTERNAL_
OVERRIDE=1` é a variável que o script criador do arquivo aceita como parâmetro conceitual na
mensagem de erro — não é ela mesma o mecanismo de autorização.

**Como resolver — depois de confirmação explícita do operador NA CONVERSA (não antes):**
```powershell
& "D:\Claud Automations\percus-kit\scripts\autorizar-acao-externa.ps1" -Motivo "<frase que resume o que o operador aprovou>"
```
Isso cria `.percus/acao-externa-autorizada.json` no diretório atual (ou em `-ProjetoRoot` se
passado). Depois disso, o comando bloqueado passa a funcionar normalmente por 60 minutos. Registre o
uso (auditoria, opcional mas recomendado quando a ação é sensível):
```powershell
& "D:\Claud Automations\percus-kit\scripts\registrar-uso-autorizacao.ps1" -Comando "git push origin master"
```
que grava em `.percus/autorizacoes-usadas.jsonl` (mascarando credenciais no comando logado).

**Por que o bloqueio pode aparecer NO MEIO da sessão, depois de pushes que já passaram:** não
investigado a fundo nesta ocorrência — o padrão observado bate com o já documentado pra
`vps_exec.py` (`r20_guard_agora_barra_vps_exec` / bloqueio "intermitente"): o matcher do guard pode
ter uma janela própria, ou o estado que ele consulta (algo em `.percus/` ou no ambiente do processo
hook) pode expirar/mudar sem relação óbvia com o histórico de comandos já aprovados na conversa.
**Não assuma que "já passou antes nesta sessão" significa que vai passar de novo** — se bloquear,
trate como um bloqueio novo e siga o procedimento acima.

**Não faça:** setar a env var inline esperando que resolva (não resolve, e mascara o diagnóstico
real); nem assumir que o bloqueio é um bug e tentar formas de contornar o hook (`--no-verify`, editar
o hook, etc.) — R20 existe pra exigir que uma ação pública tenha aprovação explícita do operador
registrada em algum lugar auditável, e o arquivo de autorização É esse registro.

**Ref:** Paid Media Automation, sessão TAGS & TEMAS 2026-08-25 — push do commit de checkpoint
`docs/STATUS.md` (ADENDO 137) bloqueado depois de 4 pushes anteriores na mesma sessão terem passado
sem bloqueio nenhum.
