---
name: checkpoint
description: Use SÓ quando o operador pedir — quando ele disser a palavra checkpoint, em qualquer forma (faz um checkpoint, checkpoint e clear, hora do checkpoint, bora checkpointar), ou pedir explicitamente pra fechar ou limpar a sessão. O agente NUNCA inicia checkpoint por conta própria nem manda abrir sessão nova sem o operador pedir (decisão do operador, 2026-09-14). Ordem obrigatória — TERMINE a tarefa atual primeiro, depois sincronize PLANO + HANDOFF + mock-audit, registre conhecimento novo (R23), commite com review (R11) e emita o prompt de retomada pronto pra colar. O agente NÃO executa o /clear — não existe ferramenta pra isso e slash command não funciona no VSCode do operador; quem dá o reset é o operador, e a skill termina no bloco de retomada. Checkpoint é persistência — quem gere contexto é o reset; o hook PreCompact é só backstop.
---

# Percus — Checkpoint de contexto

Snapshot deliberado do estado da sessão para que um `/clear` (ou compactação) não perca nada e a
retomada seja limpa. **Só o operador inicia isto** — dizendo checkpoint, ou pedindo pra fechar ou
limpar a sessão. O hook `PreCompact` existe só como rede de segurança.

> **Checkpoint escreve arquivos; só o reset salva contexto.** Medido em 2026-09-12: uma sessão de
> 14h foi de 69k a 610k tokens com a palavra "checkpoint" aparecendo 11 vezes — os arquivos ficaram
> em dia e o contexto continuou morrendo. Retomada dois dias depois, a compactação falhou e a sessão
> acabou em "Prompt is too long".
>
> **E resetar é decisão do operador, não do agente.** Medido em 2026-09-14: uma sessão com 244k
> tokens (26% de uma janela de 1M) fez checkpoint e mandou o operador abrir sessão nova sem ele
> pedir. O hook `context-budget-guard` não sabia a janela e mandava "rode checkpoint e encerre em
> RESET". O operador vê o contexto no painel do VSCode, e é ele quem decide.

## Quando rodar

Só quando o operador pede. São dois gatilhos e não há outro:

- **O operador disse "checkpoint"** — em qualquer forma ("faz um checkpoint", "checkpoint e clear",
  "hora do checkpoint"). A palavra basta.
- **O operador pediu pra fechar ou limpar a sessão** — "fecha a sessão", "vou dar clear", "prepara
  pra sessão nova", "antes do compact".

## O que o agente NÃO faz

**Não inicia checkpoint por conta própria.** Nem ao fim de milestone, nem porque o hook
`context-budget-guard` informou o tamanho do contexto, nem porque a sessão parece grande. O hook só
informa. Se o operador ainda não sabe o número, mencione-o **uma vez** e siga o trabalho.

**Não manda abrir sessão nova** sem o operador pedir, nem depois de um checkpoint que ele pediu só
como "checkpoint".

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

### 5. Sessão nova — só se o operador pediu
Se o pedido do operador incluiu fechar ou limpar a sessão ("checkpoint e clear", "fecha a sessão",
"vou abrir outra"), termine dizendo, literalmente:

> "Checkpoint feito e commitado. Pode abrir a **sessão nova** (botão de nova conversa no VSCode, ou
> `/clear` no terminal) e colar o bloco acima."

Se ele pediu só "checkpoint", a skill termina no bloco de retomada e o trabalho continua nesta sessão
quando ele quiser. Não sugira sessão nova por conta própria. O aviso do `context-budget-guard` não é
motivo, porque ele só informa o tamanho. Horas de sessão também não são: o contexto enche por
trabalho, não por relógio.

## Saída esperada (mostre ao operador)

```
[checkpoint] {projeto} — {milestone}
Tarefa atual: {terminada | PARADA em <arquivo:linha> — próximo passo: <literal>}
Arquivos sincronizados: PLANO ✓ HANDOFF ✓ mock-audit {✓/N/A}
Conhecimento novo: {slug do verbete escrito em conhecimento/resolver/, ou "nenhum"}
Commit: {hash + msg curta, ou "sem mudança de código"}
Contexto: ~{N}k tokens (informativo) — {sessão nova: pedida pelo operador | não pedida, segue nesta sessão}

═══ PROMPT DE RETOMADA (cole na sessão nova) ═══
{bloco preenchido do RESUME_PROMPT.template.md}
═════════════════════════════════════════════
```

## Anti-padrões

- ❌ **Largar a tarefa no meio ao ouvir "checkpoint"** — o passo 0 existe por isso. Fecha o que dá,
  declara o que não deu.
- ❌ **Dizer que vai dar o `/clear`, ou esperar por ele.** O agente não executa clear. Entregue o
  bloco e encerre — o reset é do operador.
- ❌ **Iniciar checkpoint por conta própria**, seja ao fim de milestone, por aviso do hook ou porque o
  contexto cresceu. Checkpoint é do operador (2026-09-14).
- ❌ **Mandar o operador abrir sessão nova sem ele pedir.** Em 2026-09-14 uma sessão a 26% de uma
  janela de 1M fez isso, obedecendo a um hook que não sabia a janela.
- ❌ Tratar a idade do transcript como ordem. O hook informa quando a sessão foi retomada de dias
  atrás; se o operador não sabe, diga uma vez, e a decisão é dele.
- ❌ Atualizar só HANDOFF e não PLANO (ou vice-versa) — `state-drift-check` bloqueia.
- ❌ Emitir resume prompt vago ("continuar a feature X") — o próximo passo tem que ser literal.
- ❌ Confiar só no hook `PreCompact` — ele é backstop e não escreve HANDOFF semântico (é um script).

## Referências

- Template: `${env:PERCUS_CANON_DIR}/templates/RESUME_PROMPT.template.md`, `templates/HANDOFF.template.md`.
- Gate irmão: `checklists/CHECKLIST_ENCERRAR_SESSAO.md` (encerramento completo de sessão).
- Backstop: hook `PreCompact` (`hooks/pre-compact-checkpoint.{ps1,sh}`).
- Captura de conhecimento: R23, skill `percus-review:consult-knowledge`.
