## Arquivo untracked engana toda ferramenta que lê o ÍNDICE do git — quatro ocorrências no mesmo dia {#arquivo-untracked-engana-a-ferramenta-que-le-o-indice}

`tags: untracked, git status --porcelain, git commit por pathspec, git diff, indice do git, arvore de trabalho, review cross-provider, R11, falso negativo, sem teste automatizado, build em checkout limpo, VPS, import sem o arquivo, bug reportado que nao existe, pergunta errada`

**Sintoma:** uma ferramenta de git responde com autoridade que algo **não existe** — o arquivo não
está no commit, o teste não está no diff, o módulo importado não foi criado — e a afirmação é lida
como fato sobre o repositório. Ela é fato sobre o **índice**, e o índice não é a árvore de trabalho.

**Quatro ocorrências no mesmo dia (Paid Media Automation, 2026-08-21), todas a mesma forma:**

| # | Ferramenta | O que ela não viu | Consequência |
|---|---|---|---|
| 1 | `git commit -- <diretório>` | arquivo untracked dentro do diretório | commit saiu **importando `AvisoOrfas.tsx` sem conter o arquivo** |
| 2–4 | `git diff` (contexto da review) | **10 testes**, ainda untracked | **três** revisões cross-provider diferentes reportaram *"sem teste automatizado"* |

O caso 1 é o mais caro porque **o build fica verde na máquina** — o arquivo existe na árvore, o
bundler o resolve, `tsc` passa, o dev server sobe. Ele só quebra em **checkout limpo**, que é
exatamente como a VPS builda. O defeito nasce depois de tudo estar commitado e revisado.

Os casos 2–4 custaram trabalho alheio: uma **sessão parceira chegou a parar de mexer num arquivo**
por causa de um bug reportado que não existia. E note a reincidência — **três** revisores
independentes chegaram à mesma conclusão errada, porque todos os três liam a mesma fonte truncada.
Concordância entre revisores **não** é evidência quando eles compartilham o ponto cego.

**Causa raiz:** `git commit -- <pathspec>` commita o que casa o pathspec **e já está rastreado**;
`git diff` (sem `--cached`) compara árvore contra índice, e o que nunca entrou no índice não tem
lado esquerdo para comparar. As duas ferramentas responderam **com precisão** — sobre o índice. A
pergunta feita era sobre a árvore de trabalho.

### Como resolver

1. **Antes de concluir "não existe" a partir de qualquer ferramenta que leia o índice, rode
   `git status --porcelain`.** Custa uma linha; as linhas `??` são exatamente o que a ferramenta
   não viu. Isso vale para review automatizada, para gate de cobertura, para script de auditoria e
   para você.
2. **Ao commitar por pathspec de diretório, `git add` explícito nos untracked antes.** `git add
   <dir>` (sem `--`) ou `git add` nomeando os arquivos novos. Depois, confira o índice com
   `git diff --cached --name-only` e trate o `N files changed` do output como asserção.
3. **Findings de "não existe" precisam de confirmação na árvore**, não só no diff — e a rejeição
   vai registrada, senão a próxima rodada de review reabre a mesma discussão.

🔑 **A classe, e é maior que git:** *"a ferramenta respondeu com precisão sobre a pergunta errada, e
a resposta foi lida como fato sobre o mundo"*. O sintoma é sempre o mesmo — uma negativa confiante,
específica, com caminho de arquivo correto — e o conserto é sempre o mesmo: perguntar **de qual
recorte** aquela resposta veio antes de agir sobre ela.

**Relacionado:** [review-le-o-diff-arquivo-novo-parece-ausente](review-le-o-diff-arquivo-novo-parece-ausente.md)
(o caso 2–4 isolado, com a receita de `git add` antes do review),
[add-por-caminho-nao-basta-o-wrapper-stageia-depois](add-por-caminho-nao-basta-o-wrapper-stageia-depois.md)
(o mesmo índice, mordendo pelo lado oposto: entra o que você não pediu),
[docs-fora-escopo-task-ficam-nao-commitados](docs-fora-escopo-task-ficam-nao-commitados.md) e
[import-de-arquivo-gitignorado-quebra-build-limpo](import-de-arquivo-gitignorado-quebra-build-limpo.md)
(mesma família do caso 1: o build que só falha onde ninguém testa).

**Ref:** Paid Media Automation, 2026-08-21 — quatro ocorrências numa sessão.
