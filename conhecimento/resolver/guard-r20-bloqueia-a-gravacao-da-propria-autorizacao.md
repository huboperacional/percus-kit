## Guard R20 bloqueia a gravação da própria autorização {#guard-r20-bloqueia-a-gravacao-da-propria-autorizacao}

`tags: r20, external-action-guard, hooks, autorizacao, acao-externa, pretooluse, cwd, stdin, segredo, R23`

**Sintoma:** o operador autorizou a ação externa na conversa, o agente tenta gravar
`.percus/acao-externa-autorizada.json` por PowerShell/Bash — e o `external-action-guard`
bloqueia **a própria gravação**, antes de qualquer ação externa acontecer.

**Causa:** o hook varre o TEXTO do comando por padrão de ação externa (deploy, ssh,
env de produção…), e o campo `motivo` do JSON cita exatamente essas palavras. O comando
que só escreve o arquivo é indistinguível, para o hook, de um comando que age.

**Solução:** gravar o JSON pela **ferramenta Write** (que não passa pelos hooks de
shell), em chamada separada, e usar a autorização nas chamadas seguintes. Dois detalhes
que mordem na sequência:

1. O guard resolve `.percus/` pelo **cwd do processo** (`Get-Location` no PreToolUse).
   O cwd persistente do shell pode ter ficado numa SUBPASTA por um `cd` de chamada
   anterior — e o `cd` para a raiz DENTRO do comando novo não ajuda, porque o hook roda
   ANTES do comando. Reposicione o cwd na raiz numa chamada própria e inerte
   (`cd <raiz> && pwd`), depois rode a ação.
2. Segredo em trânsito: para copiar credencial a um `.env` remoto, monte o valor por
   `grep` local e envie por **stdin via pipe** (`grep '^CHAVE=' .env | ssh host 'cat >>
   …'`) — o texto do comando (que o hook lê e loga) carrega só o NOME da chave.

Aparentado: todo PreToolUse avalia o mundo ANTES da ação (a mesma classe do
review-e-commit em chamadas separadas). Este verbete cobre o caso-limite em que até a
ESCRITA da autorização é bloqueada.
