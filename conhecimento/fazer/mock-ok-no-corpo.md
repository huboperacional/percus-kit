## Escapar o mock-scan sem sujar o assunto do commit {#mock-ok-no-corpo}

`tags: mock-scan, MOCK-OK, commit message, git log --oneline, hook pre-commit, escape, assunto limpo`

**Quando:** o hook `mock-scan-pre-commit` bloqueia o commit por achar marcador de mock
(`FIXME `, `XXX `, `HACK `, `MOCK_*`, `localhost:porta`...) no diff staged, e é falso positivo.

**A crença que estava errada (1):** que o escape `MOCK-OK:` precisa ser o **prefixo da 1ª linha**. Isso
levou um projeto a ter assuntos de commit como `MOCK-OK: "TODO turno" e portugues -- fix(x): ...`,
e depois a uma operação de reescrita de 7 assuntos pra limpar.

**A crença que estava errada (2), CORRIGIDA em 2026-09-15 (Fase 2, T10):** que "`-F` nunca passa" e
que só o **primeiro** `-m` com aspas duplas é lido. Isso era verdade até a 6.58.0 e deixou de ser.

**Como o hook decide hoje** (`plugin/percus-review/hooks/mock-scan-pre-commit.ps1` e `.sh`, com
paridade testada em `plugin/percus-review/tests/mock-scan.tests.ps1` sob pwsh, powershell.exe e Git Bash):

- O hook lê a **string do comando** Bash. O escape vale se `MOCK-OK:` (sem caixa, com fronteira de
  palavra antes) aparecer em **qualquer** `-m "..."` ou `-m '...'`, em todas as ocorrências.
- Também vale se aparecer nas **primeiras 64 KB** do arquivo de `-F <arq>`, `--file=<arq>` ou
  `--file <arq>`. O caminho pode vir entre aspas e com espaço (`-F "a b.txt"`). Se for relativo, ele
  resolve contra a raiz que o hook tira do `cd <dir> &&` do comando, não contra o cwd do hook.
- **Sem escape** (o scan segue e bloqueia se houver mock) com `-F -` (stdin), com arquivo inexistente,
  com diretório, com arquivo ilegível (travado por outro processo) e com `MOCK-OK:` depois de 64 KB.
- Mensagem por heredoc/stdin continua invisível: não há `-m` nem arquivo na linha de comando.

**Como fazer — caminho seguro, com `-F`:** grave a mensagem num arquivo (ferramenta Write, não
heredoc) com o `MOCK-OK:` no corpo e passe `-F <arquivo>`. O assunto fica limpo e aspas dentro do
texto deixam de ser problema.

```text
fix(restaurant): evento grava valor literal (C18)

MOCK-OK: o scanner casa FIXME citado em comentario de documentacao. Nao ha mock no diff.

corpo explicando o que o commit faz
```

**Alternativa com `-m`:** um `-m` por parágrafo, com o `MOCK-OK:` em qualquer um deles (não precisa
mais ser o 1º nem ter aspas duplas). Aspas simples no `-m` seguem sendo a regra de commit (contrato 3 do
despacho). Motivo em ASCII, sem aspas do mesmo tipo dentro do parágrafo (o `[^']+`/`[^"]+` para na
primeira).

⚠️ **`PERCUS_SKIP_MOCK_SCAN=1` prefixado no seu comando também não resolve:** o hook roda em
processo separado, e o env do seu Bash não chega nele. Só serve exportado no ambiente do agente.

⚠️ **Hook antigo instalado:** projeto com o plugin anterior à versão da T10 ainda lê só o 1º `-m` e
ignora `-F`. Se o `-F` com `MOCK-OK:` for bloqueado, confira a versão instalada antes de investigar.

🪤 **Ao EDITAR esta entrada:** escrever a receita via heredoc no Bash tool dispara o hook
`pre-commit-check`, porque o texto contém a string `git commit` e a guarda casa a MENSAGEM, não a
ação (ver [guarda-casa-a-mensagem-nao-a-acao](../resolver/guarda-casa-a-mensagem-nao-a-acao.md)). Use a ferramenta de edição de
arquivo, não `cat`/heredoc.

**Ref:** tiatendo, frente C18 (2026-08-11) e correção na frente C20 (mesmo dia, plugin v6.35.0);
percus-kit Fase 2 T10 (2026-09-15), ponto 28 do programa de 32 pontos. R23.
