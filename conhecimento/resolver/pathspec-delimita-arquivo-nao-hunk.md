## Pathspec delimita arquivo, não hunk — e o limite aparece quando duas sessões editam o mesmo arquivo {#pathspec-delimita-arquivo-nao-hunk}

`tags: arvore compartilhada, pathspec, git commit, duas sessoes, hunk, imports, cirurgia, backup, artefato gerado, openapi, coordenacao entre sessoes, publicar em ordem`

**Contexto:** o protocolo que protege sessões concorrentes numa árvore compartilhada é *"commite
com pathspec explícito, no `commit` e não só no `add`"*. Ele funciona bem — até duas sessões
editarem **o mesmo arquivo**.

**Sintoma:** `git commit -- caminho/arquivo.py` leva a versão do **disco** do arquivo **inteiro**,
com as linhas da outra sessão dentro. Não há conflito, não há aviso: o commit sai verde levando
trabalho alheio junto, com uma mensagem que fala de outra coisa.

**Por que o protocolo não cobre:** pathspec é um filtro de **caminhos**. Não existe pathspec de
hunk nem de linha. Quando a fronteira do trabalho é mais fina que o arquivo, o protocolo acaba.

**E não adianta "quem publica primeiro leva vantagem":** se A publica primeiro, leva as linhas de
B; se B publica primeiro, leva as de A. Pior: se as linhas de A dependem de outro arquivo de A
que **não** foi publicado (uma rota nova cuja declaração de tenancy ficou de fora), quem publicar
primeiro commita um estado **vermelho** que nenhum dos dois queria.

**O que fazer, em ordem de preferência:**

1. **Separar por regiões e combinar a ordem.** Se as edições estão em regiões distintas do
   arquivo, a sessão dona da região de baixo faz a cirurgia: salva cópia integral, remove as
   linhas da outra, confere (`grep` do que saiu, `grep` do que ficou, suíte do próprio recorte),
   publica só o seu, e **restaura a cópia**. É reversível e a outra sessão volta a ter tudo no
   disco.
   ⚠️ **Anuncie antes e peça silêncio na janela** — se a outra sessão escrever no arquivo durante
   a cirurgia, a restauração apaga o que ela escreveu.
2. **Escolher quem vai primeiro por critério de CONTEÚDO, não de chegada.** Reversão de decisão,
   correção urgente ou mudança que outros dependem merecem commit próprio com a justificativa
   delas. Feature nova entra depois, limpa, em cima.
3. **Se as edições se misturam por LINHA** — imports do mesmo bloco, por exemplo — nem separar por
   hunk resolve. Aí é cirurgia por linha, com cópia de segurança, ou esperar.

**Rede de segurança que já existe e ninguém lembra:** os **pacotes de review** montados durante o
trabalho (`git diff` salvo em arquivo para o revisor) contêm o código completo em forma de diff.
Se uma cirurgia falhar no meio, o trabalho é recuperável de lá.
⚠️ Eles costumam viver em diretório **gitignored** — recuperável de `git clean -fdx`, não é.

**Artefato GERADO é o caso mais traiçoeiro deste mesmo problema.** Regenerar `openapi.json`,
tipos de API ou qualquer snapshot a partir do código **vivo** da árvore captura o trabalho
**não-publicado** de todo mundo que estiver editando. O resultado não é conflito de merge: é um
gerado que **descreve um futuro que ainda não foi commitado** — documentação afirmando `404` onde
o `HEAD` ainda responde `422` — e **nenhum teste reclama disso**.

> **Regra:** o artefato gerado vai no **último** commit da leva, quando as mudanças que ele
> descreve já estiverem no `HEAD`. Ficar alguns minutos **defasado** é estritamente melhor que
> ficar **adiantado**.

Ver também [[duas-sessoes-mesmo-working-tree-arquivo-staged-some-e-volta]] e
[[review-em-worktree-compartilhado-revisa-outra-sessao]].
