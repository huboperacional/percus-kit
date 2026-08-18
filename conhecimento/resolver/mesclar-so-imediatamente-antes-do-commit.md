## Área de staging compartilhada: mesclar cedo devolve a colisão que a caixa tinha eliminado {#mesclar-so-imediatamente-antes-do-commit}

`tags: caixa de entrada, mesclar-conhecimento, colisao, sessoes concorrentes, staging compartilhado, git add -A, janela de corrida, gate le working tree, checkout compartilhado, COMO_RESOLVER`

**Sintoma:** você escreve o verbete num arquivo próprio (a caixa existe exatamente para não colidir), o mesclador confirma que a árvore está limpa e mescla — e meia hora depois o gate barra seu commit por causa de verbetes **de outra sessão**, incompletos, no mesmo arquivo.

**Causa raiz — duas, e a segunda é a que dói:**

**1. A janela entre mesclar e commitar.** O mesclador checa "o monólito está limpo?" **no instante da mesclagem**. Se você mescla cedo e commita depois, tudo que a outra sessão escrever nesse intervalo cai no mesmo arquivo — e o seu trabalho, que estava num arquivo isolado, agora está no arquivo disputado. A caixa elimina a colisão da **escrita**; ela não elimina a da **janela**, porque mesclar é justamente mover seu texto para o território compartilhado.

**2. `git add -A` num checkout compartilhado stageia o trabalho alheio.** Rodar `git add -A` antes de um review (R11 lê o diff staged) coloca no index **tudo** que estiver na árvore, inclusive o rascunho que a outra sessão está escrevendo naquele momento. A partir daí, qualquer `git commit` — seu ou dela — varre o trabalho incompleto junto.

**Solução:**
1. **Mescle imediatamente antes de commitar**, não quando terminar de escrever. Enquanto o verbete está na caixa ele é seu, isolado e durável; o momento em que ele vira texto do monólito é o momento em que passa a competir.
2. **`git add` por caminho, nunca `-A`, em repo com sessões concorrentes.** Custa uma linha e evita stagear o meio-trabalho de outra pessoa.
3. **Se já colidiu: não conserte o verbete alheio nem descarte o arquivo.** Deixe na árvore e registre no handoff. Quando a outra sessão commitar, o seu vai junto — foi o que aconteceu duas vezes em 2026-08-16.

⚠️ **Não tente "desfazer" a mesclagem removendo seu verbete do monólito.** Verificado no caso real: a outra sessão já tinha criado um link cruzado para o verbete recém-mesclado, e remover teria quebrado o texto dela. Depois de mesclado, o verbete é território compartilhado.

**A causa de fundo, que é decisão de desenho em aberto:** as checagens 2 e 3 do `percus-gate.sh` leem o **working tree**, não o índice — então trabalho de terceiro no mesmo arquivo barra o **seu** commit mesmo que o que você staged esteja íntegro. A checagem 4 já lê do índice, então a assimetria é interna ao próprio gate. Isso já rendeu escapes declarados repetidos, e o próprio gate diz que escape reincidente é sinal de desenho errado — corrigir para ler do índice é decisão do operador, ainda em aberto.

**Desfecho observado, três vezes seguidas:** quem estava com o arquivo commitou primeiro e **levou o trabalho alheio junto**, íntegro. Ou seja, esperar funciona — o que não funciona é tentar separar à força depois de mesclado.

**Ref:** percus-kit 6.36.6, 2026-08-16/17 — colisão observada durante o checkpoint da própria versão que introduziu a caixa.
