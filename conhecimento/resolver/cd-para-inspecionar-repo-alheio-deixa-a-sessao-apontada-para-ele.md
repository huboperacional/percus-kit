## `cd` para inspecionar repo alheio deixa a sessão apontada pra ele — e o próximo commit sai na árvore errada {#cd-para-inspecionar-repo-alheio-deixa-a-sessao-apontada-para-ele}

`tags: cwd, cd, git -C, Bash tool, diretorio de trabalho, sessao paralela, arvore compartilhada, commit sem pathspec, contaminacao, pathspec, percus-kit, coordenacao entre janelas`

**Sintoma:** você trabalha a noite inteira num projeto, responde uma pergunta sobre **outro**
repositório, e algumas chamadas depois o seu `git commit` sai na árvore errada. Nada avisou, porque
o comando de commit estava correto — o que mudou foi de onde ele rodou.

**Causa.** O diretório de trabalho da ferramenta Bash **persiste entre chamadas**. Um `cd` escrito
para uma inspeção pontual não volta sozinho:

```bash
ls algo ; cd "/d/Claud Automations/percus-kit" && git status --short   # inspeção pontual
# ... três chamadas depois, ainda no percus-kit
git commit -m "..."                                                   # sai na árvore errada
```

Não é acidente de ferramenta: a descrição da própria Bash diz *"Working directory persists between
calls, prefer absolute paths"*. O que engana é o **motivo** do `cd` — ele foi digitado para
responder uma pergunta com evidência em vez de memória, que é o comportamento certo. A
contaminação vem junto com o cuidado.

**Conserto, de uma linha:** `-C` não move a sessão.

```bash
git -C "/d/Claud Automations/percus-kit" status --short     # em vez de cd ... && git status
```

Vale para `log`, `show`, `diff`, `status`, `ls-files` — tudo. Para inspecionar arquivo sem git, use
caminho absoluto direto (`cat "/d/.../arquivo"`), nunca `cd` seguido de `cat`.

**Detecção, quando já aconteceu:** se o harness anunciar mudança de *"Primary working directory"*,
você **já está** na árvore errada. Volte com um `cd` explícito antes do próximo comando de git — não
confie em que a próxima chamada "volta sozinha".

**Por que isto é pior em árvore compartilhada.** Numa máquina com várias janelas, o repo alheio pode
ter **índice populado por outra sessão**. Foi o caso medido em 2026-09-12 no `percus-kit`: 16
arquivos estagiados por uma janela que estava prestes a commitar, incluindo `plugin.json`,
`marketplace.json`, `.percus-version` e `CANON_VERSION.md` com um bump de versão. Uma sessão que
entrasse ali por engano e rodasse `git commit` sem pathspec **publicaria a versão nova assinada como
sua** — e trocaria a fonte única da versão do canon. O `cd` esquecido é a porta; o índice alheio é o
que está do outro lado dela.

**Discriminante:** você vai rodar comando de git num caminho que **não é o do seu projeto**? Então
use `-C`. A pergunta não é "eu pretendo mexer nesse repo?" — é "esse comando pode deixar minha
sessão apontando pra lá?". Inspecionar é motivo suficiente para contaminar.

**Quem reportou foi quem caiu no buraco**, o que torna a lição mais fácil de lembrar: a janela
descobriu o problema **enquanto conferia um arquivo para responder uma pergunta sobre contaminação
de árvore compartilhada**. Percebeu o desvio, voltou na hora, e avisou.

Ver [[nome-de-sessao-muda-a-cada-reconexao-e-anunciar-nao-basta]] para a outra metade da
coordenação entre janelas, e [[paridade-testada-no-caso-facil-nao-e-paridade]] para a família
"o que você não exercitou, você não verificou".
