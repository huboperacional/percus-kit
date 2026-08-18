## Codei o fix que o spec/HANDOFF mandava, mas mirava o alvo errado (target stale) {#alvo-do-spec-stale}

`tags: spec stale, handoff stale, alvo errado, reproduzir antes, persona, fixture, teste evoluiu, medir antes de codar, convosim`

**Contexto:** um spec/plano/HANDOFF diz "o próximo passo é X pra resolver o problema Y" (ex.: "echo-confirm
pra consertar D2/D3/D4 do convoSim"). Você quase implementa X direto porque veio autorizado/priorizado.

**Causa raiz:** o alvo declarado no doc estava **stale**. Entre a escrita do spec e agora, o que o
identificador aponta MUDOU — no caso real, as personas de teste (`scripts/convoPersonas.py`) foram
renumeradas/redefinidas: o spec descrevia "D2/D3/D4 = declaração incompleta/pronome/inexistente" e mirava
echo-confirm na persona de **declaração**, mas essa persona (agora D1) **já passava**; os FAILs reais
(D2 imagem / D3 link / D4 incremental) tinham OUTRAS causas. Construir echo-confirm não moveria nada.
Docs descrevem o mundo no momento em que foram escritos; fixtures/IDs/nomes derivam com o tempo.

**Solução:** antes de codar pro alvo que um doc aponta, **reproduza e meça o alvo AGORA** — rode o teste/
persona/repro e confirme que o sintoma descrito ainda é o sintoma real, com os mesmos nomes. Se for
conversa/LLM, **leia o transcript real, não confie na nota** (juiz LLM é ruidoso — o mesmo caso dá PASS
numa run e FAIL noutra). Casa com [#reproduzir-antes-de-fixar](reproduzir-antes-de-fixar.md), mas um passo
antes: aqui a hipótese nem é sua, é herdada do doc — e docs envelhecem.

**Gotcha operacional junto:** ao rodar um harness in-container num container throwaway (`docker run`),
lembre que **configs bind-montadas em prod NÃO estão na imagem** — ex.: `docker run ... -v /opt/tiatendo/tenants:/app/tenants:ro`,
senão a flag do tenant fica off e o caminho que você quer testar (CALM) nem executa, mascarando tudo.

**Ref:** Ondas 2+3 tiatendo (commits `4c05c5c`+`21b463f`, PROD 0.193.0). Memória:
`project-conversa-rotina-dono-llm-first-2026-07-08`. 4 causas-raiz reais achadas nos transcripts, não a do spec.

---

> ## <sintoma curto> {#ancora-kebab}
> `tags: termo1, termo2, classe-de-erro, componente`
> **Contexto:** quando/onde aparece.
> **Causa raiz:** o porquê real (não o sintoma).
> **Solução:** o que fazer, com comando se aplicável.
> **Ref:** commit / memória / arquivo.
> ```
