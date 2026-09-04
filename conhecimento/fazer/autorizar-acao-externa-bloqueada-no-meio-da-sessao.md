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

**Por que o bloqueio aparece NO MEIO da sessão — medido em 2026-09-04 (Empresa Milionária,
sessão `-7b`), fechando o "não investigado" que esta seção trazia antes. São DUAS causas, e
confundi-las custa tempo:**

**Causa 1 — o CWD do PROCESSO (a mais comum).** O guard procura
`.percus/acao-externa-autorizada.json` **relativo ao diretório atual da sessão**, e o cwd
**persiste entre chamadas**. Um `cd <subpasta>` numa chamada anterior faz o guard passar a
procurar em `<subpasta>/.percus/...` — e ele recusa **tudo**, com a autorização da raiz
perfeitamente válida e fresca. Corrigir exige mover o cwd **numa chamada separada**: o hook é
`PreToolUse`, então um `cd` dentro do próprio comando roda DEPOIS da checagem e não alcança.
Detalhe completo em `guard-r20-le-o-cwd-do-processo`.

> 🔴 **SEGUNDO SABOR DA CAUSA 1, medido em 04/09:** a subpasta pode ter um `.percus/`
> **ANINHADO**, não versionado (`.gitignore`), sobrado de uma sessão antiga. Aí o guard não
> falha por "arquivo ausente" — ele **acha um arquivo, lê, e recusa por idade**. O bloqueio é o
> mesmo `BLOCK (R20)` genérico dos dois sabores, então a mensagem não distingue.
>
> **Por que atrapalha a depuração:** você abre o arquivo da RAIZ, vê `consumido:false`, escopo
> certo e timestamp fresco, e conclui "é frescor". Não é o arquivo que o hook leu — ele lê
> `(Get-Location).Path + .percus/`. A checagem que parece confirmar não toca no que decidiu.
>
> **Não confie no caminho nem no id que este verbete citar** — eles apodrecem. Numa mesma tarde
> um aninhado em `empresa-api/` foi visto por duas sessões independentes e **desapareceu** ~20
> min depois (alguém limpou), enquanto outro em `empresa-frontend/` (id `e3d8f957`, 27/08) seguia
> de pé e ninguém tinha notado. **Varra antes de concluir:** liste TODOS os `.percus/` da árvore
> (busca recursiva incluindo ocultos) e compare o `id` de cada um com o da raiz. Aninhado
> abandonado é lixo ativo — proponha a remoção em vez de conviver.
>
> ⚠️ A correção é a mesma dos dois sabores (mover o cwd em chamada separada), então o valor deste
> parágrafo é só encurtar a depuração e apagar o lixo — não muda o que fazer.

**Causa 2 — frescor do timestamp.** O guard compara o `timestamp_unix` com o relógio no momento
da ação. O arquivo continua `consumido: false`, com id e escopo certos, e mesmo assim recusa
porque envelheceu. Num bloco longo e legítimo (subir container efêmero → migrar → rodar a suíte
→ rodar os R1 → derrubar tudo), a autorização gravada no início **envelhece antes do bloco
terminar**.

🔑 **O teste que DISCRIMINA as duas, e é barato:** antes de regravar qualquer coisa, rode um
comando externo **trivial** (ex.: `ssh <alias> "echo teste"`). Se ele também for recusado, é
**cwd** — regravar timestamp não vai resolver e você vai regravar três vezes achando que é
frescor. Se ele passar, é **frescor**. Foi exatamente essa a confusão na sessão que produziu
este registro: as recusas foram atribuídas a frescor, o timestamp foi regravado três vezes sem
efeito, e a causa era o cwd deixado por um `cd empresa-api` de uma chamada anterior.

🔴 **O caso que custa caro é o TEARDOWN — e vale para as DUAS causas.** Uma das recusas caiu
exatamente no `docker rm -f <container-efêmero>`. Recusar o teardown é **o único caminho pelo
qual uma janela R20 deixa container órfão na VPS** — e o modo de falha é silencioso na direção
pior: quem não perceber encerra a sessão achando que limpou, e a infra fica de pé consumindo
recurso, fora de qualquer inventário.

**Regra prática:** trate a autorização como combustível, não como crachá. **Antes do teardown,
confirme o cwd na raiz do projeto (em chamada separada) E regrave o timestamp** — nunca confie
na autorização que abriu a janela para fechá-la.

**Não assuma que "já passou antes nesta sessão" significa que vai passar de novo** — se bloquear,
trate como um bloqueio novo e siga o procedimento acima.

**Não faça:** setar a env var inline esperando que resolva (não resolve, e mascara o diagnóstico
real); nem assumir que o bloqueio é um bug e tentar formas de contornar o hook (`--no-verify`, editar
o hook, etc.) — R20 existe pra exigir que uma ação pública tenha aprovação explícita do operador
registrada em algum lugar auditável, e o arquivo de autorização É esse registro.

**Ref:** Paid Media Automation, sessão TAGS & TEMAS 2026-08-25 — push do commit de checkpoint
`docs/STATUS.md` (ADENDO 137) bloqueado depois de 4 pushes anteriores na mesma sessão terem passado
sem bloqueio nenhum.
