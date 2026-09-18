## Repo git aninhado vira gitlink e o clone não traz o conteúdo {#repo-git-aninhado-vira-gitlink-e-o-clone-nao-traz-o-conteudo}

`tags: git, repositorio aninhado, embedded repository, gitlink, submodulo, versionamento, reconstruivel, pasta nao rastreada, Codex, outro usuario do Windows, dubious ownership, safe.directory, backup de .git`

**Sintoma:** uma pasta aparece como "não rastreada" (`?? pasta/`) no repo do projeto, e a conclusão
natural é "falta versionar". Mas `git add pasta` responde
`warning: adding embedded git repository` — e se você seguir em frente, o commit grava só um
**gitlink** (ponteiro modo 160000). Quem clonar o repo recebe uma pasta **vazia**: nada ali é
reconstruível a partir do commit. Medido no tIAtendo em 17/09 (portal comercial): a pasta tinha
`.git` próprio, criado por outro agente, com remoto em outro servidor.

**Como diagnosticar sem mexer em config:** `git add --dry-run -- pasta` mostra o aviso sem gravar
nada. Se o `.git` aninhado pertence a outro usuário do Windows, o `git -C pasta log` falha com
*dubious ownership* — não resolva com `safe.directory` global só para olhar: leia os arquivos do
`.git` direto (`HEAD`, `config`, `refs/heads/*`, `logs/HEAD`), que dão branch, remoto e último commit.

**Escolha (é do operador — mexe no trabalho de outro):** (1) tirar o `.git` de dentro e versionar os
arquivos no repo de fora; (2) submódulo, só se o remoto for durável e acessível à equipe; (3) cópia
em outro caminho — duplica código que diverge. Só a (1) deixa a entrega reconstruível pelo clone.

**Como fazer a (1) sem perder nada:** copiar o `.git` inteiro para FORA da árvore e **conferir a
cópia antes de apagar** (número de arquivos igual e o mesmo sha em `refs/heads/main`). A cópia vira
propriedade do seu usuário, então dá para consultar com `git --git-dir=<cópia>` depois — foi assim
que se provou que o repo aninhado rastreava exatamente os mesmos arquivos. O `.gitignore` que já
existia dentro da pasta passa a valer para o repo de fora (ele se aplica à subárvore): prove as
exclusões com `git check-ignore -v`, não com a lista de arquivos.
