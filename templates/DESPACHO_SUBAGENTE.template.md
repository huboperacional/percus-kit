---
tipo: template
quando-usar: ao despachar implementador ou revisor (SDD, R9) em projeto Percus
leitura: 1 min
---

# Template — despacho de subagente

> Cada contrato abaixo existe por um incidente medido em 2026-09-14. Copie o bloco e preencha os `{...}`.
> O despacho inteiro cabe em **até 40 linhas**; o resto vai por arquivo (brief, review-package, regras).

```text
Tarefa: {id e título curto}. Trilho: {P|M|G}. Modelo: {haiku|sonnet|opus} (declarado no despacho).

Leia primeiro (são os requisitos, com valores exatos):
- Brief: {caminho absoluto do brief}
- Regras de ambiente: {caminho absoluto}

Onde: worktree {caminho absoluto}. BASE = {sha}. Antes de tocar em arquivo:
`git rev-parse --short HEAD` = {sha} e `git status --porcelain` vazio; senão, pare e reporte.

Decisões do controlador que o brief não sabe: {até 5 linhas}

Contratos:
1. Testes em PRIMEIRO PLANO. Nunca `run_in_background` nem Monitor: subagente não é
   acordado por notificação de tarefa em background, e a suíte morre com ele. Nenhuma chamada
   passa de 10 min (limite da ferramenta): na tarefa, `scripts/rodar-suite.ps1 -Afetados` com
   timeout 600000. Suíte inteira é do controlador (ou repartida, cada chamada abaixo de 10 min).
2. Use caminhos absolutos. Não mude o cwd da sessão com `cd`; processo filho recebe
   `WorkingDirectory` explícito (Push-Location não muda o cwd do filho).
3. Commit: `-m` em ASPAS SIMPLES; nunca crase nem `$nome` em `-m` com aspas duplas.
   Depois de commitar, confira `git log -1 --format=%B`. Amend é barrado pelo hook.
4. R11 uma vez sobre o diff staged final (o hook aceita a review pelo hash de `git diff HEAD`);
   trilhos P e M: wrapper com `-NoFactCheck` (`.sh`: `--no-fact-check`) — esse switch é do wrapper
   `scripts/percus-review-auto.ps1`/`.sh`; o cliente `plugin/percus-review/scripts/deepseek-review.ps1`
   não tem esse switch (chame-o sem ele). Mudou arquivo depois da
   review → review de novo. Se o wrapper emitir `__PERCUS_NEEDS_CROSS_CLAUDE__` ou reportar
   exit 4 do cliente (DeepSeek indisponível): PARE, não commite, reporte NEEDS_CONTEXT com o caminho do
   diff — o controlador faz a review Cross-Claude e registra com `registrar-review`.
   Achado crítico/importante aberto depois de 2 rodadas (P/M): pare e reporte; nunca commite.
5. NUNCA dispare subagentes. Não faça merge nem push.
6. Grave o relatório em {caminho absoluto}\{tarefa}-report.md ANTES de responder (limite de API
   já derrubou agente na mensagem final). Até ~150 linhas; evidência bruta (log de suíte, diff)
   em arquivo à parte, citado pelo caminho. Inclua tempo de parede.
7. Se for retomado, execute o pedido MAIS RECENTE; ignore notificação antiga de tarefa em background.

Responda só com (até 15 linhas): Status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT),
commits (sha + assunto), resumo de testes em 1 linha, preocupações, caminho do relatório.
```

> Ação do controlador, fora do despacho ao implementador — PASSO OBRIGATÓRIO, antes de mandar revisar
> ou integrar: ao receber DONE, rode `scripts/sdd-conferir.ps1 -Base <BASE da tarefa> -Head <commit>
> -Repo <worktree>` e leia o `RESUMO`. `FALHA` → devolve ao implementador antes da revisão (revisão
> não é lugar de achar encoding). `AVISO r11-marcador` em worktree irmão é esperado (a checagem só vê
> o marcador do próprio worktree) — não é falha.

## Revisor (variação)

- Troque só os "Contratos 3 e 4" por: **só leitura** (não altera árvore, índice, HEAD nem branch); leia o
  `review-package` uma vez; não rode a suíte. **O contrato 6 continua valendo:** grave o relatório
  (até ~150 linhas) antes de responder. Resposta em até 40 linhas começando pelo veredito.
- O revisor recebe o RESUMO do `sdd-conferir` junto do review-package e não gasta tempo com
  encoding/fim de linha.
- Revisão escopada de conserto pequeno (até ~200 linhas): `model: haiku` nos trilhos P e M.
