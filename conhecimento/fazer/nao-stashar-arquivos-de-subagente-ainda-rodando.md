## Não fazer `git stash` de arquivos que um SUBAGENTE em background ainda está editando {#nao-stashar-arquivos-de-subagente-ainda-rodando}

`tags: subagent, git stash, working tree compartilhado, R11, review isolado, colisao transiente, task-notification`

**Contexto:** ao rodar múltiplos subagentes em paralelo (padrão subagent-driven, R5), cada um edita
arquivos no MESMO working tree do thread principal (sem `isolation: "worktree"`). Quando o thread
principal quer isolar o diff de UM item já concluído pra rodar R11/commit sem contaminação dos
outros itens ainda em progresso, a tentação é usar `git stash push -u -- <arquivos dos outros
itens>` pra "limpar" o working tree temporariamente.

**O problema:** se algum desses "outros itens" ainda tem um subagente RODANDO (sem notificação de
conclusão recebida), o stash remove os arquivos dele do disco NO MEIO da execução. O agente não
sabe disso — continua chamando `Edit`/`Write` nesses arquivos, que ou falham (arquivo sumiu) ou
recriam o arquivo do zero (perdendo o histórico de diff que estava no stash). Um `git stash pop`
posterior tenta merge de 3 vias contra um conteúdo que já divergiu, com risco real de conflito ou
de sobrescrever silenciosamente o trabalho mais recente do agente.

**Sinal de que isso está acontecendo:** o subagente, ao terminar, reporta no seu resumo algo como
"meus edits foram revertidos/deletados colateralmente durante a execução" — ele se recupera sozinho
(detecta via aviso de "arquivo mudou em disco" do próprio harness, reaplica, reverifica), mas é
sorte, não garantia.

**Regra:** antes de stashar arquivos pra isolar review/commit de um item, confirme que TODOS os
subagentes que tocam esses arquivos já mandaram `task-notification` de conclusão. Se um item ainda
está rodando, **espere a notificação** antes de tocar nos arquivos dele — mesmo que isso signifique
commitar os itens já prontos primeiro e voltar depois pro que falta.

**Efeito colateral relacionado:** `git checkout <stash-ref> -- <paths>` com uma mistura de paths
válidos (arquivos rastreados) e inválidos (arquivos untracked, que exigem `<stash-ref>^3`, não a
raiz do stash) **aborta a operação inteira sem aplicar NENHUM path**, mesmo os válidos — não é óbvio
pelo erro, que só reclama dos inválidos. Rode em 2 chamadas separadas: uma só com paths rastreados
(`git checkout <stash> -- <tracked...>`), outra recuperando cada untracked via
`git show <stash>^3:<path> > <path>` (a 3ª parent de um stash `-u` guarda os untracked). Confira com
`git diff --stat HEAD -- <paths>` depois — não assuma que o comando aplicou só porque não deu erro
pros paths válidos.

**Ref:** Plexco Tasks, 2026-09-01 — leva de 6 correções de UI, 3 subagentes em paralelo. Aconteceu
2x (o subagente do filtro por pessoa se recuperou sozinho nas duas). Nenhum dado perdido, mas custou
tempo de diagnóstico que a espera pela notificação teria evitado.
