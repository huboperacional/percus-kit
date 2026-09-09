## Autorização R20 válida fica INVISÍVEL quando o cwd da sessão entra num subdiretório {#autorizacao-r20-invisivel-quando-o-cwd-da-sessao-entra-em-subdiretorio}

`tags: R20, external-action-guard, .percus, acao-externa-autorizada.json, cwd, PreToolUse, subdiretorio, repo aninhado, ssh, scp, bloqueio intermitente`

**Sintoma.** Uma sequência de ações externas passa pelo guard sem problema — três, quatro comandos
`ssh` seguidos, todos autorizados e registrados em `.percus/autorizacoes-usadas.jsonl`. Aí **um**
comando é bloqueado com a mensagem genérica ("acao externa publica requer aprovacao explicita do
operador"), sem nada ter mudado: mesma janela de 60min, mesma autorização, mesmo destino. Repetir o
comando bloqueia de novo; o log de uso não ganha linha nenhuma.

**Causa raiz.** O guard resolve o arquivo com `$cwd = (Get-Location).Path` e
`Join-Path $cwd ".percus/acao-externa-autorizada.json"`. Esse `cwd` é o da **sessão**, e o hook é
`PreToolUse` — ele roda **antes** do comando, então o `cd` que está *dentro* do comando bloqueado
ainda não aconteceu. Quem decide o `cwd` é o comando **anterior**.

Em projeto cujo repositório git é um subdiretório da raiz (`<projeto>/app/` com o `.percus/` em
`<projeto>/`), basta o comando anterior ter feito `cd <projeto>/app` — para rodar `git archive`,
`npx tsc`, `vitest` — e o próximo comando externo procura `<projeto>/app/.percus/`, que não existe.
`Test-Path` dá falso, a checagem cai fora sem estourar exceção, e o fluxo segue para o BLOCK
genérico. **A autorização continua perfeitamente válida; ela só não foi procurada onde está.**

O sinal que separa este caso dos outros: o BLOCK vem com a mensagem **genérica** de "requer
aprovação" e **não** aparece linha nova em `.percus/autorizacoes-usadas.jsonl`. Quando a autorização
é encontrada e o problema é outro, o guard usa mensagem **própria** ("autorizacao VALIDA (id: ...),
mas nao consegui registrar o uso").

**Diagnóstico em 1 comando** — rode sozinho, sem `cd`, e veja onde a sessão está:

```sh
pwd && ls -d .percus 2>&1
```

Se o `pwd` não for a raiz que contém `.percus/`, é isto.

**Correção.** Reposicione o `cwd` da sessão **num comando separado**, antes do comando externo:

```sh
cd /caminho/da/raiz-do-projeto && pwd && ls -d .percus    # comando 1, isolado
scp -i chave pacote.tar.gz root@host:/opt/                # comando 2, ja com cwd certo
```

Não adianta prefixar `cd` no mesmo comando: o hook já leu o `cwd` quando esse `cd` for executado.

**Armadilha de método.** É tentador tratar o bloqueio como "a autorização expirou" e criar outra.
Isso mascara o defeito, gasta a confirmação do operador de novo e mantém o bug — que volta no
próximo comando que rodar depois de um `cd` para subdiretório. Confira o `pwd` antes de reautorizar.

**Família:** mesma raiz de [Agente isolado em worktree não vê a autorização R20 do
projeto](../fazer/agente-isolado-em-worktree-nao-ve-autorizacao-r20-do-projeto.md) — lá o `cwd`
diverge por isolamento de worktree, aqui por um `cd` comum no comando anterior. Nos dois casos o
guard lê `.percus/` **relativo ao processo**, não ao repositório lógico. Distinto de
[o guard casa o motivo, não a ação](guard-de-acao-externa-casa-o-motivo-nao-a-acao.md), onde a
autorização É lida e o bloqueio vem do texto do comando.

**Ref:** Liliflow, deploy dos 4 commits (2026-09-08). Quatro `ssh` seguidos passaram; o `scp`
seguinte foi bloqueado porque o comando anterior tinha feito `cd CL_Liliflow/app` para montar o
`git archive`, e o `.percus/` mora em `CL_Liliflow/`. Um `cd` isolado para a raiz destravou, com a
mesma autorização e sem tocar no arquivo.
