---
name: checkpoint
description: Use ao fim de cada milestone, quando o contexto está ficando grande, ou antes de um /clear ou /compact. Sincroniza PLANO + HANDOFF + mock-audit, registra conhecimento novo (R23), commita com review (R11), e emite um prompt de retomada pronto pra colar. Caminho PRIMÁRIO de gestão de contexto; o hook PreCompact é só backstop.
---

# Percus — Checkpoint de contexto

Snapshot deliberado do estado da sessão para que um `/clear` (ou compactação) não perca nada e a
retomada seja limpa. **Você (agente) roda isto ao fim de cada milestone** — não espere o contexto
estourar. O hook `PreCompact` existe só como rede de segurança se você esquecer.

## Quando rodar

- **Fim de um milestone / fase** do plano (momento natural de checkpoint).
- **Contexto ficando grande** (resposta lenta, muita coisa acumulada) — antes de pedir `/clear`.
- Antes de um `/compact` manual.
- Quando o hook `PreCompact` avisar que a compactação vai acontecer (rode antes dela).

## Passos

### 1. Sincronizar os arquivos de estado
- `docs/PLANO.md` — cada feature tocada reflete o status real (R2; não arredonde).
- `HANDOFF.md` — campos obrigatórios atualizados (`templates/HANDOFF.template.md`): funcionando E2E,
  só-UI/mock, quebrado, **último passo concluído**, **próximo passo imediato** (sem ambiguidade),
  tabela de status espelhando o PLANO.
- `docs/mock-audit.md` — se tem frontend e alguma tela mudou de estado.

> `PLANO` e `HANDOFF` na **mesma leva de edits** — o hook `state-drift-check` (on-stop) bloqueia o
> encerramento se divergirem.

### 2. Capturar conhecimento novo (R23)
Resolveu algo não-trivial nesta sessão? Escreva **um arquivo por verbete na caixa de entrada**:
`${env:PERCUS_CANON_DIR}/conhecimento/entrada/resolver/<slug>.md` (ou `entrada/fazer/<slug>.md` se for
procedimento). O nome do arquivo tem de ser exatamente o slug da âncora. **Não edite o monólito direto.**
Aqui a captura fica amarrada a um gate que **sempre roda** — não depende de lembrar no fim.

### 2b. Mesclar a caixa no monólito
```powershell
pwsh -File "${env:PERCUS_CANON_DIR}\scripts\mesclar-conhecimento.ps1"
```
Anexa cada verbete no `COMO_RESOLVER.md`/`COMO_FAZER.md` e insere a linha de índice sozinho.

Se ele disser **ADIA**, está certo: o monólito está modificado na árvore porque **outra sessão está
mexendo nele**, e as entradas ficam na caixa pro próximo checkpoint. Não force, não edite o monólito à
mão para "resolver" — adiar é de graça justamente porque a caixa é durável, e foi para acabar com essa
colisão que ela existe. Se sair com código diferente de zero, há entrada **inválida**: ela ficou na
caixa e a mensagem diz o quê corrigir (slug ≠ nome do arquivo, `tags:` ausente, fence aberto).

### 3. Commit (com review R11)
Se há mudança de código: rode `pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"`
antes do commit (R11). Trate findings. Commit com mensagem que referencia o status.

### 4. Emitir o prompt de retomada
Preencha `${env:PERCUS_CANON_DIR}/templates/RESUME_PROMPT.template.md` com o estado atual e **mostre o
bloco pro operador** — é o que ele cola na sessão nova após o `/clear`. Aponte os 2-3 arquivos-chave a
reler (HANDOFF, PLANO, e o arquivo do próximo passo).

## Saída esperada (mostre ao operador)

```
[checkpoint] {projeto} — {milestone}
Arquivos sincronizados: PLANO ✓ HANDOFF ✓ mock-audit {✓/N/A}
Conhecimento novo: {entrada em COMO_RESOLVER, ou "nenhum"}
Commit: {hash + msg curta, ou "sem mudança de código"}

═══ PROMPT DE RETOMADA (cole após /clear) ═══
{bloco preenchido do RESUME_PROMPT.template.md}
═════════════════════════════════════════════
```

## Anti-padrões

- ❌ Esperar o contexto estourar pra fazer checkpoint — faça no milestone, proativo.
- ❌ Atualizar só HANDOFF e não PLANO (ou vice-versa) — `state-drift-check` bloqueia.
- ❌ Emitir resume prompt vago ("continuar a feature X") — o próximo passo tem que ser literal.
- ❌ Confiar só no hook `PreCompact` — ele é backstop e não escreve HANDOFF semântico (é um script).

## Referências

- Template: `${env:PERCUS_CANON_DIR}/templates/RESUME_PROMPT.template.md`, `templates/HANDOFF.template.md`.
- Gate irmão: `checklists/CHECKLIST_ENCERRAR_SESSAO.md` (encerramento completo de sessão).
- Backstop: hook `PreCompact` (`hooks/pre-compact-checkpoint.{ps1,sh}`).
- Captura de conhecimento: R23, skill `percus-review:consult-knowledge`.
