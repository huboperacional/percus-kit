## `Promise.all` de fetch composto sobrescreve append otimista de criação inline feita em paralelo {#promise-all-fetch-sobrescreve-append-otimista}

tags: race condition optimistic update, stale closure overwrite state, promise all overwrites
optimistic append, item created disappears from ui, fetchData race with inline create, item some
da tela mas existe no banco

**Sintoma:** um item criado inline (ex.: categoria criada dentro do modal de outra entidade) some
da lista/select na hora, mesmo o `POST` tendo retornado sucesso e o item existindo no banco —
confirmado porque um teardown/limpeza posterior encontra e remove o registro. Reproduz de forma
intermitente (não determinístico a cada rodada) dependendo só de timing de rede.

**Causa raiz:** a tela tem um `fetchData()` que faz `Promise.all` de N endpoints (ex.: lista
principal + categorias + centros de custo + formas de pagamento) e no fim faz
`setEstado(resFetch.data)` pra cada um. Se o usuário criar um item da MESMA lista (via um fluxo
inline com append otimista, `setEstado(prev => [...prev, novoItem])`) enquanto esse `Promise.all`
ainda está em voo, e QUALQUER UMA das outras N-1 chamadas for mais lenta que o `POST` de criação, o
`setEstado(resFetch.data)` do fetch original resolve DEPOIS do append otimista — o snapshot do GET
foi tirado (no servidor) ANTES do POST committar, então sobrescreve o item recém-criado. Testes e2e
automatizados disparam esse timing com muito mais frequência que humanos (cliques em milissegundos
vs. segundos).

**Solução:** não é useEffect/dependência faltando — é substituição cega de estado por um fetch
concorrente. Fix: merge em vez de substituição, mas ESCOPADO — nunca "mantenha tudo que falta no
fetch" (isso mascara deleção real de itens antigos por outra via). Use um `Map<id, timestampDeCriacao>`
de itens "recém-criados via fluxo inline" com TTL curto (dezenas de segundos bastam). No handler de
criação: registra o id+timestamp. No merge do fetch: remove do map qualquer id que já apareceu no
fetch novo OU que passou do TTL; o que sobrar no map e não estiver no fetch novo, mantém no
resultado final. Duas versões mais simples foram tentadas e descartadas por review: merge cego de
tudo ausente do fetch (mascara deleção pra sempre) e Set sem TTL (mascara deleção até o item ser
deletado por fora sem nenhum fetch subsequente refletir isso — fantasma permanente).

**Ref:** Família Milionária, sessão 2026-08-08 — `familia-frontend/src/app/lancamentos/page.tsx`,
categoria criada inline no modal de lançamento sumindo do select ~50% das vezes (achado rodando
`categorias.spec.ts` repetidamente contra prod, confirmado via diagnóstico de timing de rede
custom). Ver também memória local `gotcha_promise_all_fetch_race_overwrites_optimistic_append`.
