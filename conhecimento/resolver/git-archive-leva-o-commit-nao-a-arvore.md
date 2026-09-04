## `git archive` leva o COMMIT, não a árvore — e você prova o código errado {#git-archive-leva-o-commit-nao-a-arvore}

`tags: git archive, arvore de trabalho, working tree, nao commitado, enviar codigo para VPS, provar conserto, falso verde, teste remoto, tar-pipe`

**Contexto:** você aplicou um conserto, ainda não commitou, e vai enviar o código para outra
máquina (VPS, container, ambiente de teste) para **provar que o conserto funciona**. O caminho
canônico para isso é `git archive HEAD | ssh host tar -x` — recomendado inclusive por
`conhecimento/fazer/sync-para-diretorio-de-deploy-que-nao-e-repo-git.md`, onde é a escolha certa.

**O que acontece:** `git archive HEAD` empacota o **commit** `HEAD`, não o diretório de trabalho.
As suas edições não-commitadas simplesmente **não vão junto**. O comando não avisa, não falha, não
deixa rastro — o pacote chega completo e correto, só que da versão anterior.

**Por que é pior que um erro comum:** o experimento roda, produz número e o número é plausível. Se
o conserto for pequeno, o resultado "antes" e "depois" podem até parecer diferentes por variação de
ambiente, e você conclui que provou algo. O caso real (2026-09-04): conserto no teardown de dois
módulos de teste, enviado para a VPS, A/B disparado. O `grep` de conferência devolveu **0
ocorrências** do conserto nos dois arquivos — ele nunca chegou. Sem esse `grep`, o A/B teria
"provado" um código que não estava lá.

### Como não cair

**Confira o conteúdo no destino, não o sucesso do comando.** O `tar -x` retorna 0 alegremente:

```bash
git archive HEAD <caminho> | ssh host "rm -rf /tmp/x && mkdir -p /tmp/x && tar -x -C /tmp/x"
ssh host "grep -c '<marca do seu conserto>' /tmp/x/<arquivo>"   # tem que ser >= 1
```

A marca pode ser qualquer coisa que só exista na sua versão — um comentário, o nome de uma função
nova. O ponto é que a asserção seja sobre o **arquivo que vai rodar**, não sobre o comando que o
enviou.

**Se precisar mesmo enviar não-commitado**, sobreponha os arquivos modificados depois do archive:

```bash
for f in $(git diff --name-only); do cat "$f" | ssh host "cat > /tmp/x/$f"; done
```

Ou commite antes de enviar — que é o certo quando o conserto já está pronto para revisão.

**Família:** mesma classe de [[commit-com-pathspec-leva-o-disco-nao-o-staged]], invertida — ali o
git leva o DISCO quando você esperava o índice; aqui leva o COMMIT quando você esperava o disco. Nos
dois casos a diferença é silenciosa e só aparece se você perguntar ao alvo o que ele recebeu.
