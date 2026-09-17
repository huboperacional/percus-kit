## Next standalone comprime as páginas mas não as rotas de API: tela lenta por download, não por banco {#next-standalone-nao-comprime-rota-de-api}

`tags: next.js, standalone, gzip, compress, traefik, lentidao, route handler, resource timing, rede, R23`

**Sintoma:** uma tela que chama uma rota de API grande demora 1,5–3 s, mas o servidor e o banco estão
rápidos. EXPLAIN dá dezenas de milissegundos, a montagem em JS também, e a otimização de SQL não
muda nada.

**Medido** (Paid Media Automation, 2026-09-17): a aba Timeline do D4U em 90 dias tinha p50 de 1,6 s.
No navegador, `performance.getEntriesByType('resource')` mostrou TTFB de 330–550 ms e **download de
2,2–3,7 s**, com `encodedBodySize === decodedBodySize` (495 KB crus). As páginas do mesmo host saíam
com `Content-Encoding: gzip`; **nenhuma** Route Handler (`/api/**`) saía — `/api/clients` 44 KB e
`ads-summary` 115 KB também viajavam crus até a VPS (~250 ms de ida e volta, janela TCP inicial
pequena: cada ~14 KB extra custa mais uma volta).

**Correção:** comprimir no proxy. No Traefik (labels do serviço, e no compose para sobreviver ao
próximo `stack deploy`):

```yaml
- traefik.http.middlewares.<nome>-gzip.compress=true
- traefik.http.routers.<router>.middlewares=<nome>-gzip
```

Resposta já comprimida pelo Next não é recomprimida. Resultado: 495 KB → 26 KB; p50 1,63 s → 0,56 s,
p95 0,70 s. Label só de roteamento não reinicia a task (o `UpdateStatus` fica nulo) — o Traefik lê ao vivo.

**Como evitar o diagnóstico errado:** antes de otimizar consulta, meça no navegador TTFB × download e
encoded × decoded. TTFB baixo + download alto + tamanhos iguais = falta compressão.

**Armadilha:** a label `routers.<router>.middlewares` é a lista inteira; um segundo middleware precisa
entrar na mesma linha, separado por vírgula, ou substitui o primeiro calado.
