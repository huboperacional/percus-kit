## Hook de pre-commit que lê o working tree em vez do índice afere o que não vai ser commitado {#gate-le-working-tree-nao-o-indice}

tags: pre-commit, git hook, working tree vs index, git show dois-pontos arquivo, staged, add esquecido, gate furado, validacao antes de gravar, husky, lint-staged

**Sintoma:** o gate passa, a gravação entra, e o conteúdo gravado viola exatamente a regra que o
gate acabou de aprovar.

**Causa raiz:** o hook leu o arquivo do **disco** (`cat arquivo`, `[ -f arquivo ]`, `Get-Content`)
e não da **área de staging**. São coisas diferentes durante a operação: você pode ter corrigido o
arquivo no editor e não ter dado `git add`, ou ter passado um caminho específico e enviado só parte
do que está sujo. O gate aprova a versão boa que ficou no disco; o git grava a versão velha que
estava no índice.

**O caso que dói mais:** o arquivo que o gate usa como *referência* (versão, config, manifesto) foi
corrigido no disco mas não staged. O gate lê "está tudo certo" e libera uma gravação cujo conteúdo é
o estado antigo — e o histórico fica com a violação.

**Solução:** leia do índice, sempre.

```sh
conteudo=$(git show :caminho/arquivo 2>/dev/null)   # o dois-pontos e a area de staging
```

E trate **falha** dessa leitura como violação, não como "pule a checagem": se o arquivo saiu do
índice ou do disco, o `git show :` falha calado, a variável fica vazia, e um `if [ -n "$valor" ]`
transforma isso em gate desligado sem aviso.

**Regra geral:** hook de pre-commit valida a **gravação**, não a pasta. Toda leitura que decide o
veredito sai de `git show :`, `git diff --cached` ou `git ls-files`. `cat` e `[ -f ]` só servem pra
decidir se a checagem **se aplica** — nunca pra decidir se ela **passa**.

**Ref:** percus-kit v6.36.0, 2026-08-13, checagem 4 do `v2/gates/percus-gate.sh`. Achado pelo
revisor cross-provider (R11) na primeira versão do gate, que lia `< CANON_VERSION.md` do disco.
