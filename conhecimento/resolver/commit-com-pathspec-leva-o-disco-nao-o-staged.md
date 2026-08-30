## `git commit -- <pathspec>` commita o DISCO, não o que você stageou — e leva a edição alheia junto {#commit-com-pathspec-leva-o-disco-nao-o-staged}

`tags: git, commit, pathspec, staged, index, arvore compartilhada, multi-sessao, autoria, R23`

**Sintoma:** em árvore compartilhada por duas sessões, você faz `git add` dos seus arquivos,
outra sessão edita um DELES no disco (ex.: `HANDOFF.md`), e o seu
`git commit -m ... -- <pathspec>` sai com as linhas DELA dentro do SEU commit — sem aviso,
sem conflito. No caso inverso, a sua edição pega carona no commit dela e o arquivo "some" do
`git status` sem nunca ter aparecido num commit seu.

**Causa raiz:** com pathspec, o `git commit` **ignora o índice** para os caminhos citados e
commita **o conteúdo do working tree** deles (documentado no man: *"commit the contents of
the files that match the pathspec without recording the changes already added to the
index"*). O `git add` anterior vira ruído: o snapshot que você conferiu no `diff --cached`
não é o que entra. Medido 2× no mesmo dia (Empresa Milionária, 2026-08-30): o HANDOFF da
sessão de billing entrou no commit do ADR-0015 da sessão da faixa V2, e o tracking de PLANO
da faixa V2 entrou no commit de docs da sessão de billing.

**Solução:**
1. **`git status` imediatamente antes do commit**, não antes do `add` — o intervalo entre os
   dois é onde a edição alheia entra.
2. Em arquivo COMPARTILHADO (HANDOFF/PLANO), aceite o comportamento e **avise a outra
   sessão** ("suas linhas entraram no meu `<hash>`, nada a refazer") — conteúdo preservado
   vale mais que autoria pura; o que não pode é a outra sessão recommitar por cima achando
   que perdeu.
3. Se autoria separada IMPORTA (código de outra frente), **não use pathspec nesse commit**:
   stagee tudo que é seu, confira `git diff --cached`, e commite SEM `--` (o índice é
   respeitado); ou combine janela de escrita no arquivo.

**Como detectar:** `git show <hash> --stat` logo após o commit — arquivo com mais mudança do
que você fez é a assinatura; o par da outra sessão some do `git status` no mesmo instante.

**Relacionado:** o padrão da casa "pathspec no commit, não só no add" continua valendo para
NÃO levar arquivo alheio inteiro — este verbete é o refinamento: pathspec limita QUAIS
arquivos entram, mas não QUAL VERSÃO deles entra.
