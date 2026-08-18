## Guard `PreToolUse` não se autoriza de DENTRO da própria chamada: a variável tem que preexistir no processo {#guard-pretooluse-nao-se-autoriza-de-dentro-da-chamada}

`tags: PreToolUse, hook, guard, R20, acao externa, override, variavel de ambiente, env inline, settings.json, watcher, deploy bloqueado, autorizacao do operador, falso positivo por texto`

**Sintoma:** o guard bloqueia e a própria mensagem ensina como autorizar — *"setar `VAR=1`"*. Você
seta e continua bloqueado, nas duas formas óbvias:

    VAR=1 <comando>                    # prefixo inline no bash
    $env:VAR = '1'; <comando>          # atribuição no PowerShell

**Causa.** O hook é **`PreToolUse`**: ele roda *antes* do comando e lê a variável do **ambiente do
processo** que o harness já criou. Uma atribuição que vive **dentro do comando** só passa a existir
quando o comando roda — e ele nunca roda. A instrução do guard é dirigida a **uma pessoa**, não ao
agente que a leu.

⚠️ **E a saída "vou escrever no `settings.json` do projeto" tem dois furos:**

1. O watcher de settings costuma observar apenas diretórios que **já tinham arquivo de settings quando
   a sessão começou**. Criar um `settings.local.json` do zero no meio da sessão pode não ter efeito
   nenhum até reiniciar — você acha que destravou e não destravou.
2. Se o `.gitignore` não cobre esse arquivo, você acaba de **criar dentro do repositório, e
   versionável, um artefato cuja única função é desligar um guard de ação externa**. É pior que o
   problema que resolve, e sobrevive à sessão.

**Solução.** Pare e devolva ao operador a linha exata para rodar **no terminal dele**, antes de
reinvocar a ação. Autorização dada em chat não alcança um hook — e é exatamente esse o desenho: quem
arma o override é uma pessoa, num processo que o agente não controla.

⚠️ **Não fique tentando variações** (`export`, `set`, wrapper, subshell). Duas tentativas já provam a
classe; a terceira é o agente procurando contorno para um controle que o operador instalou de propósito.

### O falso-positivo que fecha o círculo, e ele é útil

**Escrever ESTE verbete por heredoc no bash foi bloqueado pelo mesmo guard.** Ele casa o **texto cru do
comando**, e o corpo do arquivo citava o nome da variável e um comando de publicação. Ou seja: a
tentativa de *documentar* a ação dispara a guarda da *ação*.

Consequência prática, e vale para qualquer guard que case payload como texto: **conteúdo não é
intenção.** Escrever um `.md` que fala sobre publicar não publica nada. Quando o bloqueio for
claramente de conteúdo e não de ato, use uma ferramenta de arquivo em vez do shell — não é contornar o
guard, é não pedir ao shell uma coisa que ele não precisa fazer. O que **não** se faz é reescrever o
texto para escapar do padrão: aí você degradou a documentação para agradar um matcher.

**Vizinhos:** [#guarda-muda-sem-a-ferramenta-que-usa-pra-falar](guarda-muda-sem-a-ferramenta-que-usa-pra-falar.md)
— lá a guarda perde a voz; aqui ela fala, e o que ela pede não está ao alcance de quem leu.

**Ref:** Empresa Milionária, 2026-08-17/18, com 8 commits prontos e o deploy autorizado em chat — e
parado pelo R20, que não lê chat.
