## `TypeError: fetch failed` com `other side closed` num harness Node contra uvicorn: é o keep-alive de 5 s {#uvicorn-keep-alive-de-5s-fecha-o-socket-que-o-fetch-do-node-reaproveita}

`tags: uvicorn, keep-alive, timeout-keep-alive, node, fetch, undici, SocketError, other side closed, fetch failed, playwright, harness, R1, tunel ssh, flake`

**Medido (Empresa Milionária, 2026-09-14, harness R1 do Playwright contra backend FastAPI/uvicorn na VPS, por
túnel `ssh -L`).** Dois specs falhavam de forma reprodutível — sempre os mesmos dois, os outros seis do
mesmo par de arquivos verdes — com:

```
TypeError: fetch failed
[cause]: SocketError: other side closed
```

O mapa de saúde da suíte os tinha registrado como "`fetch failed` sem causa", com a pista de que falhavam
rápido (menos de 4 s): não era timeout.

**O que NÃO era, medido antes de mudar qualquer coisa:**

- **O túnel SSH recusando canal** (`MaxSessions`): a saída do processo `ssh -N -L` ficou com 0 linhas — a
  recusa de canal sai ali como `channel N: open failed`.
- **O backend quebrando:** o log do uvicorn não tinha `Traceback`, `500` nem exceção durante os testes.

**A causa:** o uvicorn fecha conexão ociosa depois de **5 s** (`--timeout-keep-alive`, padrão). O `fetch` do
Node (undici) mantém um pool e **reaproveita** sockets. Quando o spec passa mais de ~5 s na tela entre duas
chamadas de API do próprio harness (semeadura, conferência no servidor), a chamada seguinte cai num socket
que o servidor acabou de fechar — e o cliente lê `other side closed`. Por túnel o fechamento chega com
atraso, o que alarga a janela da corrida.

**A prova, com uma variável só:** o mesmo par de arquivos, a mesma infra, o uvicorn relançado com
`--timeout-keep-alive 75` — **6 passed + 2 failed → 8 passed**, e `other side closed` 0 vezes no log (a mesma
busca achava 2 na rodada anterior).

**Como aplicar:**

- Backend de TESTE que um harness Node chama com pausas humanas no meio: suba com
  `uvicorn ... --timeout-keep-alive 75` (maior que o maior intervalo realista entre chamadas).
- Se não puder mexer no servidor, o outro lado resolve igual: cliente com `keepAlive` menor que o do servidor,
  ou `Connection: close` nas chamadas do harness.
- Antes de caçar defeito de produto num `fetch failed` rápido, leia o `[cause]` — `other side closed` aponta
  para o servidor fechando o socket, não para rede recusando.

Primos: [uvicorn-root-logger-mudo](uvicorn-root-logger-mudo.md) (o log que deveria mostrar o problema pode
estar mudo por outro motivo — confira que ele registra requisição antes de concluir "sem erro").
