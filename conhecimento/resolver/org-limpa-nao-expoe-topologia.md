## Org de teste limpa não expõe topologia — só comportamento {#org-limpa-nao-expoe-topologia}

`tags: E2E, org de teste, seed, dado limpo, topologia, grafo, reentrada, hierarquia, ciclo, coleção vazia, item orfao, falso verde, dado adverso`

Uma tela de grafo passou no E2E autenticado (org descartável, dados semeados) e estava **quebrada
na org real do operador**: setas com coordenadas negativas apontando para fora do canvas e a pílula
de taxa por cima do texto do cartão.

Causa: a geometria ligava sempre `from.right → to.left`, assumindo destino à frente. A org real
tinha **reentrada** (item que volta para uma etapa anterior, ou aresta entre dois nós da mesma
coluna); a org de teste não. O backend **já tratava** reentrada — era o desenho que assumia fila.

**Regra:** E2E em org limpa prova **comportamento** (persistiu, transicionou, respondeu), não
**forma do dado**. Feature que depende da topologia (grafo, árvore, ciclo, hierarquia) exige semear
a topologia adversa de propósito, ou olhar uma base real. Verde em org limpa é **falso verde** para
essa classe.

Vale para além de grafo: hierarquia profunda, coleção vazia, item órfão, ciclo — qualquer forma que
a org nova não produz sozinha.

Visto em: Plexco Tasks, s151 (2026-07-27).
