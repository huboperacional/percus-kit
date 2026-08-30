## Hook PreToolUse mata o comando INTEIRO, não só o commit {#hook-pretooluse-mata-o-comando-inteiro-nao-so-o-commit}

`tags: hook, pretooluse, git add, indice, staging, r11, gate, commit, falso sucesso, working tree`

**Sintoma:** o gate R11 bloqueia um commit; você corrige o que ele pediu, roda tudo verde, commita
de novo — e o commit sai com **os arquivos antigos**. Correções, testes novos e mutações novas
ficaram só no working tree. O `git status` mostra `MM` (staged **e** unstaged) sem gritar.

**Causa raiz:** o hook `PreToolUse` intercepta a chamada da ferramenta Bash **antes de qualquer
coisa executar**. Num comando encadeado — `git add X && git commit -m ...` — não é o `git commit`
que falha no meio da cadeia: **o comando inteiro nunca começa**, e o `git add` também não roda. O
`&&` dá a impressão contrária, porque o `add` vem primeiro na linha.

Efeito colateral: a partir daí o índice fica congelado no estado de antes do bloqueio, e todo
commit seguinte carrega essa defasagem — até alguém comparar índice × árvore.

**O caso (tiatendo, N23, 2026-08-30):** depois de um bloqueio do gate, foram corrigidos o texto de
uma resposta ao cliente, adicionado um teste e uma mutação. O commit seguinte teria ido com o texto
errado e sem os dois. Quem pegou foi uma revisão que leu o **blob do índice**
(`git show :arquivo`), não o diff nem a árvore.

**Como evitar:**

1. `git add` em **chamada separada** do `git commit`, sempre que houver hook de pré-commit.
2. Antes de commitar, provar que **staged == working tree**:
   `git diff --stat -- <paths>` tem que sair **vazio**.
3. Na dúvida sobre o que vai no commit, ler o **índice**, não a árvore:
   `git show :caminho/arquivo.py | grep <marcador>`.

**Gotcha irmão, mesma família:** o hook casa a *string* do comando, não a ação. Um comando que
apenas **contém** o texto `git commit` — por exemplo escrevendo documentação sobre commits via
heredoc — dispara o bloqueio. Nesses casos, escreva o arquivo pela ferramenta de arquivo em vez do
shell.
