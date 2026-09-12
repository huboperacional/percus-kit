## Guarda que casa o comando por texto barra o próprio payload de teste — e o changelog que a descreve {#guarda-que-casa-comando-por-texto-barra-o-payload-de-teste}

`tags: hook, PreToolUse, pre-commit-check, R11, falso positivo, payload de teste, heredoc, changelog, testar hook, sequencia vigiada`

**Sintoma:** você roda um comando que **não** publica nada — monta um payload JSON para testar um
hook, ou escreve um changelog por heredoc — e o `pre-commit-check` (R11) bloqueia:

```
[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em .deepseek/reviews/ do repo target
```

**Causa:** a guarda casa a sequência `git`…`commit` **no texto do comando**, sem distinguir *"vou
publicar"* de *"estou passando um texto que contém essas palavras"*. Três casos reais na mesma
sessão (2026-09-12):

1. um `printf` montando o payload `{"tool_input":{"command":"cd X && <a sequencia vigiada>"}}` e
   mandando pro hook sob teste. (O exemplo aqui vai com a sequencia elidida de proposito: este
   arquivo e indexado e circula como fonte de copy-paste -- escrever o literal faria o proprio
   verbete disparar a guarda que ele descreve.)
2. Um heredoc de changelog cuja prosa citava a sequencia vigiada ao descrever o proprio hook.
3. Um texto explicando a limitacao da forma `git -C <dir>` — e ai a guarda **parseou o `<dir>` de
   dentro da prosa** e foi procurar review num diretorio que nao existe.

O caso 3 é o mais instrutivo: a guarda não só disparou, ela **parseou o alvo de dentro da prosa** e
apontou para um diretório que não existe.

**Isto não é bug.** Guarda de ação externa prefere falso positivo a falso negativo: deixar passar um
commit sem review é caro; barrar um comando inocente custa uma reescrita. O comportamento está certo
— o que falta é você saber disso ao escrever o comando.

**Como contornar, sem tocar no hook:**

- **Monte a sequência em runtime**, nunca literal: em Python, `'git ' + 'commit'`; em PowerShell,
  `'git ' + 'commit -m x'`. O texto final é idêntico; a string no *comando* não é.
- **Escreva o arquivo pela ferramenta de edição**, não por heredoc no shell — o conteúdo não passa
  pelo PreToolUse de comando.
- **Nunca** use `PERCUS_HOOKS_DISABLED=1` para isso: desliga *todas* as guardas para rodar um teste,
  e o hábito sobrevive ao teste.

**Ao escrever teste de hook, o cuidado vira regra:** o payload que você passa para o hook sob teste
é lido pela guarda do hook irmão. Um arquivo de teste que monta a sequencia vigiada literalmente falha na
máquina de quem tem o enforcement ligado — e passa na de quem não tem. Teste que só roda em ambiente
sem guarda é teste que não protege ninguém.

**Discriminante:** a guarda examina o **texto** do comando, não a intenção nem o efeito. Se a string
que ela procura aparece por qualquer motivo — dado, documentação, payload — ela dispara. Ao escrever
qualquer comando que *fale sobre* a ação vigiada, monte a string em runtime.
