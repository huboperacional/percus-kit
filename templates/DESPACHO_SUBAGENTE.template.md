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
1. Testes e suíte em PRIMEIRO PLANO. Nunca `run_in_background` nem Monitor: subagente não é
   acordado por notificação de tarefa em background, e a suíte morre com ele.
2. Use caminhos absolutos. Não mude o cwd da sessão com `cd`; processo filho recebe
   `WorkingDirectory` explícito (Push-Location não muda o cwd do filho).
3. Commit: `-m` em ASPAS SIMPLES; nunca crase nem `$nome` em `-m` com aspas duplas.
   Depois de commitar, confira `git log -1 --format=%B`. Amend é barrado pelo hook.
4. R11 uma vez sobre o diff staged final (o hook aceita a review pelo hash de `git diff HEAD`).
   Mudou arquivo depois da review → review de novo.
5. Não dispare subagentes. Não faça merge nem push.
6. Grave o relatório completo em {caminho absoluto}\{tarefa}-report.md ANTES de responder
   (limite de API já derrubou agente na mensagem final). Inclua tempo de parede.
7. Se for retomado, execute o pedido MAIS RECENTE; ignore notificação antiga de tarefa em background.

Responda só com (até 15 linhas): Status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT),
commits (sha + assunto), resumo de testes em 1 linha, preocupações, caminho do relatório.
```

## Revisor (variação)

- Troque "Contratos 3, 4 e 6" por: **só leitura** (não altera árvore, índice, HEAD nem branch); leia o
  `review-package` uma vez; não rode a suíte; resposta em até 40 linhas começando pelo veredito.
- Revisão escopada de conserto pequeno (até ~200 linhas): `model: haiku` nos trilhos P e M.
