## Escapar o mock-scan sem sujar o assunto do commit {#mock-ok-no-corpo}

`tags: mock-scan, MOCK-OK, commit message, git log --oneline, hook pre-commit, escape, assunto limpo`

**Quando:** o hook `mock-scan-pre-commit` bloqueia o commit por achar `TODO`/`todo` no diff, e é
falso positivo — em português "todo/toda" é palavra comum ("roda em TODO turno", "toda linha").

**A crença que estava errada:** que o escape `MOCK-OK:` precisa ser o **prefixo da 1ª linha**. Isso
levou um projeto a ter assuntos de commit como `MOCK-OK: "TODO turno" e portugues -- fix(x): ...`,
e depois a uma operação de reescrita de 7 assuntos pra limpar.

🔴 **CORRIGIDO em 2026-08-11 (plugin v6.35.0) — o escape só é visto DENTRO de um argumento `-m`.**
A versão anterior desta entrada dizia que o hook casa `(?i)\bMOCK-OK:` "sem âncora, em qualquer
linha", e que isso fora verificado passando a mensagem por stdin. **Medido de novo: bloqueia.** O
hook lê a **string do comando Bash** e procura `MOCK-OK:` apenas dentro de `-m "..."` ou `-m '...'`
(`mock-scan-pre-commit.ps1`, as duas linhas de `[regex]::Match($command, '-m\s+…')`). Consequência
prática: mensagem por **stdin/heredoc ou por arquivo (`-F`) NUNCA passa** — não há `-m` na linha de
comando, então o escape é invisível por melhor que esteja escrito.

⚠️ **`PERCUS_SKIP_MOCK_SCAN=1` prefixado no seu comando também não resolve:** o hook roda em
processo separado, e o env do seu Bash não chega nele. Só serve exportado no ambiente do agente.

**Como fazer:** um `-m` por parágrafo, com o **MOCK-OK no segundo** — assim ele vira a 1ª linha do
CORPO e o assunto (`git log --oneline`) continua limpo. Aspas SIMPLES nos parágrafos e aspas DUPLAS
só no do MOCK-OK: o regex casa a **primeira** ocorrência com aspas duplas, então a alternância
garante que ele leia o parágrafo certo.

```bash
git commit \
 -m 'fix(restaurant): evento grava valor literal (C18)' \
 -m "MOCK-OK: o scanner casa TODO turno em portugues (every/all) como placeholder de mock. Nao ha mock no diff." \
 -m 'corpo explicando o que o commit faz' \
 -m 'Co-Authored-By: ...'
```

Motivo em ASCII (o regex mangia acento). Sem aspas simples DENTRO dos parágrafos (bash não deixa) e
sem aspas duplas dentro do parágrafo do MOCK-OK (o `[^"]+` para na primeira).

🪤 **Ao EDITAR esta entrada:** escrever a receita via heredoc no Bash tool dispara o hook
`pre-commit-check`, porque o texto contém a string `git commit` e a guarda casa a MENSAGEM, não a
ação (ver [guarda-casa-a-mensagem-nao-a-acao](../resolver/guarda-casa-a-mensagem-nao-a-acao.md)). Use a ferramenta de edição de
arquivo, não `cat`/heredoc.

**Ref:** tiatendo, frente C18 (2026-08-11) e correção na frente C20 (mesmo dia, plugin v6.35.0). R23.
