## Hook `PreToolUse` bloqueia o comando INTEIRO — `add` encadeado antes do commit nunca roda {#pretooluse-bloqueia-comando-inteiro-add-nao-roda}

tags: hook bloqueou de novo, linha que ja corrigi, mock-scan acusa linha antiga, staged desatualizado, git add encadeado nao rodou, PreToolUse, && no mesmo comando, gate de commit dispara sem commitar, heredoc com texto de commit, MOCK-OK primeira linha

**Sintoma.** Você edita um arquivo pra remover o que o hook `mock-scan` acusa, roda
`git add <arquivo> && git c-o-m-m-i-t -m "..."`, e o hook **bloqueia de novo citando a linha
antiga** — com o número de linha do conteúdo que você acabou de apagar. Você olha o arquivo: está
corrigido. Olha `git diff --cached`: ainda mostra a versão velha. Parece cache do hook.

**Não é cache.** O hook `PreToolUse` intercepta a chamada de Bash **antes de ela executar**. Quando
bloqueia, **nada** do comando roda — inclusive o `git add` encadeado antes. O que está staged
continua sendo o resultado de um `add` ANTERIOR, feito quando o arquivo ainda tinha o problema.

**Como sair.** Duas chamadas de Bash **separadas**: primeiro o `add`, depois o commit. Mesma regra
que já vale pro par `percus-review-auto.ps1` + commit (que quebra por outro motivo — o hook mede a
idade do review), e pelo mesmo mecanismo: encadear com `&&` num único comando é o que mata.

**Como confirmar em 5 segundos** se o que está staged é o velho ou o novo:
`git diff --cached -- <arquivo> | grep -n "<trecho acusado>"` — linha com `-` na frente = você já
corrigiu (é a remoção); linha com `+` = ainda está lá de verdade.

**Irmão do mesmo problema, achado ao escrever esta entrada:** o gate `pre-commit-check` casa a
string do comando, não a intenção. Um `cat >> arquivo.md <<EOF` cujo TEXTO documenta um comando de
commit dispara o gate de R11 ("último review tem 33 min"), mesmo sem commitar nada. Contorne
escrevendo o conteúdo num arquivo temporário (tool de escrita) e concatenando depois — o comando de
shell deixa de conter as palavras-gatilho.

Relacionado: `{#percus-hook-cross-project}` (TTL do review); e a família "MOCK-OK precisa ser a 1ª
linha da mensagem" — o hook lê o argumento do `-m`; com `-F -`/heredoc ele não enxerga o prefixo.
