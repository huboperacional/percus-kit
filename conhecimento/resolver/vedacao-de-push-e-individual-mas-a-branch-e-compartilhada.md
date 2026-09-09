## "Não faça push" não impede o seu trabalho de ir ao remoto — a vedação é individual, a branch é compartilhada {#vedacao-de-push-e-individual-mas-a-branch-e-compartilhada}

`tags: push, remoto, origin, branch compartilhada, sessao paralela, ancestrais, vedacao, R20, devolutiva`

**Sintoma:** o mandato diz **"somente commits locais; não faça push"**. Você cumpre à risca — não
executa `push` nenhum — e declara no relatório final *"nada foi enviado ao remoto"*. **A afirmação
é falsa:** seus commits já estão em `origin/<branch>`.

**Por quê:** `git push` envia a **branch**, não um commit. Ele carrega **toda a cadeia de
ancestrais** do ref que está sendo empurrado. Se outra sessão (ou o operador) empurra a mesma
branch depois de você commitar, **o trabalho dela leva o seu junto** — sem que nada seu tenha sido
executado.

🔑 **A distinção que salva o relatório:** *"não executei push"* é sobre a **sua ação** e continua
verdadeiro. *"nada foi enviado ao remoto"* é sobre o **resultado** e depende de terceiros. São
frases diferentes; só a primeira você pode afirmar sozinho.

**Como verificar antes de declarar (3 comandos, 5 segundos):**
```bash
git fetch --quiet origin
git merge-base --is-ancestor <seu-commit> origin/main && echo "JA ESTA NO REMOTO"
git rev-list --left-right --count origin/main...HEAD   # "0 0" = idênticos
git reflog show refs/remotes/origin/main --date=iso | head   # quem empurrou, e quando
```

**Como resolver de verdade:** se o trabalho **precisa** ficar fora do remoto, a proteção é
**branch própria** (`git switch -c frente/<nome>`), não disciplina. Numa branch compartilhada, a
vedação individual é inaplicável por construção — qualquer sessão que empurre publica o de todas.

⚠️ **Corolário para relatórios de fechamento:** trate *"nada foi ao remoto"* como afirmação
**medida**, não como consequência do seu comportamento. É a mesma classe de erro de declarar um
teste verde sem olhar o exit code: você mediu a sua intenção, não o estado do mundo.

⚠️ **Sessão paralela é a causa mais provável e a menos visível.** Ela não aparece no seu
histórico de comandos; aparece só no `reflog` do ref remoto. Se o `rev-list` der `0 0` e você não
empurrou, procure ali antes de concluir qualquer coisa.

**Não faça:** assumir que "não rodei o comando" equivale a "o efeito não aconteceu"; nem corrigir
só a frase do relatório sem levar o fato a quem definiu a política — a vedação existia por um
motivo, e a descoberta é de que ela não estava sendo garantida.

**Ref:** tiatendo, 2026-09-05 — fechamento do `§00w-onboarding`. O mandato proibia push; cinco
commits da frente foram ao `origin/main` carregados pelo push de uma sessão paralela de marketing,
2 h depois. Achado pela review Cross-Claude sobre a devolutiva final, não pela sessão que escreveu
a frase.
