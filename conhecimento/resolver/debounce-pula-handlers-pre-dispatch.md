## Fix deployado, correto e mutation-testado — e prod segue com o comportamento velho: o caminho debounced pula os handlers pré-dispatch {#debounce-pula-handlers-pre-dispatch}

tags: debounce, processBatch, cmdHandler, _dispatchInboundText, _processMessage, paridade, fail-open, handler nunca roda, smoke 2/5, codigo no container mas comportamento velho, dois caminhos de pipeline, flush, sweeper, isComando, bypass

**Contexto:** fix no handler pré-dispatch (ex.: `recorrencia_handler` via `cmdHandler.handle`)
passa suíte + mutation, deploy FULL verificado (símbolos grepados DENTRO do container, task única
com a imagem nova) — e o smoke ao vivo reproduz o comportamento ANTIGO byte a byte, sem NENHUM log
do handler.

**Causa raiz:** o pipeline tem DOIS caminhos de entrada e o fix só é alcançável por um. O flush do
debounce (`processBatch`) despachava direto pro `_dispatchInboundText`, pulando tudo que
`_processMessage` roda antes (cmdHandler → recorrencia/parcelamento handlers, desfazer). O gate de
debounce elege exatamente usuário conhecido + onboarded + sessão **idle** — o caminho DOMINANTE de
prod. Mitigação antiga (`isComando` bypassa debounce) cobria só comando explícito; frase natural
furava. Agravante: testes de unidade chamam o handler direto e transcripts entram pelo caminho
não-debounced — a rede inteira era verde com o fix inalcançável.

**Diagnóstico em dois passos:** (1) confirme que o tráfego bateu no container novo
(`docker logs ... | grep -c <numero>` > 0); (2) grep pelos logs que o fix emite
(`grep -E 'recorrencia_|classify_manage'`) — tráfego presente + zero logs do handler = o caminho
executado não passa pelo sítio do fix. Aí procure o segundo caminho de entrada
(`rg "dispatchInboundText\(" -n` e veja quem chama sem passar pelo prelúdio).

**Solução:** paridade — o flush roda os MESMOOS handlers pré-dispatch do caminho normal
(`respostaCmd = await cmdHandler.handle(combinado, ...)` + send/commit/return se respondeu), com
teste que entra PELO CAMINHO DEBOUNCED (fakeredis + tryFlush com clock-fudge + `_sweepDebounceOnce`)
e asserts POSITIVOS no conteúdo enviado (assert negativo passa verde com bot mudo).

**Armadilha associada:** ao achar um buraco desses, enumere o que MAIS o caminho pula — aqui
"desfaz" (`_tryDesfazerUltimo`) tem o mesmo buraco e virou `[0]` separado, não conserto embutido.

**Ref:** Família Milionária, 2026-08-12, spec objeto-sem-rótulo. 1ª rodada do smoke 2/5 com o Fix 1
deployado; paridade em `1550c03`; a rede local inteira (2750 testes) era verde com o bug vivo.
