---
name: checkpoint
description: Use SEMPRE que o operador disser a palavra checkpoint, em qualquer forma (faz um checkpoint, checkpoint e clear, hora do checkpoint, bora checkpointar) — esse é o gatilho principal. Também ao fim de cada milestone, quando o hook context-budget-guard avisar que o contexto cresceu, ou antes de um /clear ou /compact. Ordem obrigatória — TERMINE a tarefa atual primeiro, depois sincronize PLANO + HANDOFF + mock-audit, registre conhecimento novo (R23), commite com review (R11) e emita o prompt de retomada pronto pra colar. O agente NÃO executa o /clear — não existe ferramenta pra isso e slash command não funciona no VSCode do operador; quem dá o reset é o operador, e a skill termina no bloco de retomada. Checkpoint é persistência — quem gere contexto é o reset; o hook PreCompact é só backstop.
---

# Percus — Checkpoint de contexto

Snapshot deliberado do estado da sessão para que um `/clear` (ou compactação) não perca nada e a
retomada seja limpa. **Você (agente) roda isto ao fim de cada milestone** — não espere o contexto
estourar. O hook `PreCompact` existe só como rede de segurança se você esquecer.

> **Checkpoint escreve arquivos; só o reset salva contexto.** Medido em 2026-09-12: uma sessão de
> 14h foi de 69k a 610k tokens com a palavra "checkpoint" aparecendo 11 vezes — os arquivos ficaram
> em dia e o contexto continuou morrendo. Retomada dois dias depois, a compactação falhou e a sessão
> acabou em "Prompt is too long". Por isso o passo 5 existe e não é opcional.

## Quando rodar

- **O operador disse "checkpoint"** — em qualquer forma ("faz um checkpoint", "checkpoint e clear",
  "hora do checkpoint"). Este é o gatilho principal e não precisa de mais nada: a palavra basta.
- **Fim de um milestone / fase** do plano (momento natural de checkpoint).
- **Contexto ficando grande** (resposta lenta, muita coisa acumulada) — antes de pedir `/clear`.
- Antes de um `/compact` manual.
- Quando o hook `PreCompact` avisar que a compactação vai acontecer (rode antes dela).

## O que o agente NÃO faz

**O `/clear` é do operador.** O agente não tem ferramenta para limpar contexto, e slash command não
funciona no VSCode dele — então a skill vai **até o bloco de retomada** e para ali. Prometer o clear
(ou ficar esperando que ele aconteça sozinho) deixa a sessão inteira pendurada. Diga o que ele
precisa fazer, com o bloco pronto pra colar, e encerre.

## Passos

### 0. Termine a tarefa atual

Pedido literal do operador (2026-09-12): *"quando eu falar checkpoint: termine a tarefa atual,
atualize todos os arquivos, e façamos o clear"*. A ordem importa — checkpoint que interrompe uma
tarefa pela metade sincroniza `PLANO`/`HANDOFF` descrevendo um estado que **ainda vai mudar**, e a
sessão nova retoma sobre um retrato falso.

**"Terminar" aqui é o mínimo coerente, não o escopo inteiro:** o teste que faltava rodando, o
arquivo que estava meio-escrito fechado, o commit da coisa que já está pronta. Não é hora de
começar nada novo.

**Se não dá pra terminar** — a tarefa é grande, depende de decisão do operador, ou está bloqueada —
**não force e não finja**. Pare no ponto seguro mais próximo e declare, no `HANDOFF` e no bloco de
retomada, três coisas: o que ficou pela metade, **onde exatamente** (arquivo:linha), e qual é o
próximo passo literal. Tarefa interrompida e declarada é retomável; tarefa interrompida e silenciada
vira o bug que a sessão nova vai caçar sem saber que existe.

### 1. Sincronizar os arquivos de estado
- `docs/PLANO.md` — cada feature tocada reflete o status real (R2; não arredonde).
- `HANDOFF.md` — campos obrigatórios atualizados (`templates/HANDOFF.template.md`): funcionando E2E,
  só-UI/mock, quebrado, **último passo concluído**, **próximo passo imediato** (sem ambiguidade),
  tabela de status espelhando o PLANO.
- `docs/mock-audit.md` — se tem frontend e alguma tela mudou de estado.

> `PLANO` e `HANDOFF` na **mesma leva de edits** — o hook `state-drift-check` (on-stop) bloqueia o
> encerramento se divergirem.

### 2. Capturar conhecimento novo (R23)
Resolveu algo não-trivial nesta sessão? Escreva **um arquivo por verbete**, direto na base:
`${env:PERCUS_CANON_DIR}/conhecimento/resolver/<slug>.md` (ou `conhecimento/fazer/<slug>.md` se for
procedimento). **O nome do arquivo é o slug da âncora** — `## Título {#slug}`.

Não há passo de merge, não há caixa de entrada, não há espera. Isso deixou de ser necessário quando
o monólito morreu: arquivos diferentes não colidem no git, então duas sessões escrevendo ao mesmo
tempo simplesmente não se veem.

O gate barra no commit: `##` sem âncora fechando a linha, slug ≠ nome do arquivo, `tags:` ausente,
fence aberto, ou link para verbete inexistente.

### 2b. Regerar o índice
```powershell
pwsh -File "${env:PERCUS_CANON_DIR}\scripts\gerar-indice-conhecimento.ps1"
```
Reescreve `INDICE.md` de cada área a partir dos arquivos. **Nunca edite o `INDICE.md` à mão** — a
próxima geração sobrescreve, e índice divergente do conteúdo foi o que produziu 14 verbetes
invisíveis (2026-08-18).

### 3. Commit (com review R11)
Se há mudança de código: rode `pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"`
antes do commit (R11). Trate findings. Commit com mensagem que referencia o status.

### 4. Emitir o prompt de retomada
Preencha `${env:PERCUS_CANON_DIR}/templates/RESUME_PROMPT.template.md` com o estado atual e **mostre o
bloco pro operador** — é o que ele cola na sessão nova. Aponte os 2-3 arquivos-chave a reler (HANDOFF,
PLANO, e o arquivo do próximo passo). O bloco é **ponteiro + estado mínimo** (≤15 linhas), não cópia
do HANDOFF: os arquivos são a fonte; o bloco só diz por onde recomeçar.

### 5. Reset — encerrar a sessão
Se o hook `context-budget-guard` avisou nesta sessão (contexto acima de ~150k, ou 8h+ de parede, ou
transcript retomado com dias de idade), **o checkpoint não termina no commit: termina no reset.** Diga
ao operador, literalmente:

> "Checkpoint feito e commitado. Esta sessão está com ~{N}k tokens de contexto — continuar nela custa
> mais a cada passo e um resume futuro falha. Abra uma **sessão nova** (botão de nova conversa no VSCode,
> ou `/clear` no terminal) e cole o bloco acima."

Não retome o trabalho na sessão atual depois disso. Sem aviso do hook, o reset é opcional — mas ao fim
de milestone continua sendo a hora natural de fazê-lo.

## Saída esperada (mostre ao operador)

```
[checkpoint] {projeto} — {milestone}
Tarefa atual: {terminada | PARADA em <arquivo:linha> — próximo passo: <literal>}
Arquivos sincronizados: PLANO ✓ HANDOFF ✓ mock-audit {✓/N/A}
Conhecimento novo: {slug do verbete escrito em conhecimento/resolver/, ou "nenhum"}
Commit: {hash + msg curta, ou "sem mudança de código"}
Contexto: ~{N}k tokens / {H}h — {RESET OBRIGATÓRIO: abra sessão nova | reset opcional}

═══ PROMPT DE RETOMADA (cole na sessão nova) ═══
{bloco preenchido do RESUME_PROMPT.template.md}
═════════════════════════════════════════════
```

## Anti-padrões

- ❌ **Largar a tarefa no meio ao ouvir "checkpoint"** — o passo 0 existe por isso. Fecha o que dá,
  declara o que não deu.
- ❌ **Dizer que vai dar o `/clear`, ou esperar por ele.** O agente não executa clear. Entregue o
  bloco e encerre — o reset é do operador.
- ❌ Esperar o contexto estourar pra fazer checkpoint — faça no milestone, proativo.
- ❌ **Checkpoint sem reset em sessão avisada pelo hook** — o arquivo salva, o contexto continua
  morrendo (sessão de 610k tokens, Empresa-Milionaria, 2026-09-10).
- ❌ Retomar (`--resume` / "retomar") um transcript de dias ou de centenas de k — abra sessão nova e
  cole o bloco; o hook avisa na primeira tool se você fizer isso mesmo assim.
- ❌ Atualizar só HANDOFF e não PLANO (ou vice-versa) — `state-drift-check` bloqueia.
- ❌ Emitir resume prompt vago ("continuar a feature X") — o próximo passo tem que ser literal.
- ❌ Confiar só no hook `PreCompact` — ele é backstop e não escreve HANDOFF semântico (é um script).

## Referências

- Template: `${env:PERCUS_CANON_DIR}/templates/RESUME_PROMPT.template.md`, `templates/HANDOFF.template.md`.
- Gate irmão: `checklists/CHECKLIST_ENCERRAR_SESSAO.md` (encerramento completo de sessão).
- Backstop: hook `PreCompact` (`hooks/pre-compact-checkpoint.{ps1,sh}`).
- Captura de conhecimento: R23, skill `percus-review:consult-knowledge`.
