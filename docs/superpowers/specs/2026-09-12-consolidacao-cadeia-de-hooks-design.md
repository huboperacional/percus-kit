# Consolidação da cadeia de hooks — dispatcher de duas camadas — Design

**Data:** 2026-09-12 · Brainstorm com o operador + conselho 3/3 · **Pré-requisito** da spec
`docs/superpowers/specs/2026-09-12-enforcement-7-regras-comportamentais.md`, que decide a forma de
enforcement das regras comportamentais. Esta spec não redecide nenhuma delas — decide **quanto custa** adicioná-las.

> **Contagem:** o nome daquele arquivo diz "7", mas a tabela de auditoria foi corrigida no mesmo
> dia para **9** comportamentais (R5 e R6 saíram do balde "com enforcement": os hooks que se
> autodeclaram `(R5)`/`(R6)` cobram outra coisa, resto de uma renumeração do canon). O número que
> vale é o do dono: `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md`.
> Renomear/ajustar aquela spec é tarefa dela, declarada como dívida no plano.

## O que este documento decide

A cadeia de hooks Percus deixa de ser N processos `powershell.exe` por evento e passa a ser **um
dispatcher de duas camadas**: uma triagem burra em `cmd.exe` que paga ~61 ms sempre, e um único
processo PowerShell que só sobe quando algum check pode disparar.

## Motivação — a medição que reenquadrou a tarefa

A tarefa 3 do plano ia adicionar 4 hooks novos. Antes de escrever qualquer um, medi o que já custa a
cadeia existente.

Cada hook é um `.cmd` que faz `powershell.exe -NoProfile -File x.ps1` — Windows PowerShell 5.1, um
processo por hook. Medido nesta máquina, **com todos os hooks em no-op**:

| O que | Custo |
|---|---|
| 1 hook, saindo na primeira linha | **~420 ms** |
| a cadeia `PreToolUse:Bash\|PowerShell` (8 hooks), em **todo** comando Bash | **3 357 ms** |
| `context-budget-guard` (`PostToolUse`, matcher `""` = **toda** tool call) | **477 ms** por tool call |

Uma sessão de 200 tool calls paga ~95 s só no `context-budget-guard`, e `echo ola` custa 3,3 s. O
"orçamento de hooks" de que o plano fala — a lição do teto do `CONTEXT.md`, de que gate que dispara
em massa vira escape declarado — não era só atenção do operador: **é tempo de parede já gasto**.

Com isso na mesa, "quais regras comportamentais merecem hook" tem uma resposta se cada hook novo custa 420 ms
na frota inteira e outra bem diferente se custar ~0. O operador decidiu **consolidar antes**, para
que a escolha delas volte a ser por mérito.

## O fato técnico que torna isto barato

`exit` dentro de um `.ps1` chamado com `&` a partir de outro `.ps1` **não mata o chamador**, e
`$LASTEXITCODE` chega intacto. Provado nesta sessão. Logo um dispatcher roda os checks no **mesmo
processo sem reescrever o fluxo de controle de nenhum**.

O único obstáculo é stdin: só pode ser lido uma vez, e todo hook faz `[Console]::In.ReadToEnd()`. O
dispatcher grava o payload num arquivo e cada hook passa a ler `PERCUS_HOOK_STDIN_FILE` se estiver
setado, senão `Console.In` — **mudança de uma linha por hook**, e eles continuam rodáveis
isoladamente, então a suíte de 556 testes não muda.

## Arquitetura — duas camadas, e a de baixo é burra de propósito

**Camada 1 — `cmd.exe`, ~61 ms, paga sempre.** Despeja stdin num temp (`more > %TMPF%`) e roda **um**
`findstr /L /G:gatilhos.txt` — a **união** de todos os gatilhos de todos os checks. Não casou nada:
`exit /b 0`, PowerShell nunca sobe.

**Camada 2 — PowerShell, ~425 ms, paga só quando algo pode disparar.** Um processo. Lê o payload do
temp, decide **com precisão** quais checks rodam, chama cada `.ps1` com `&`.

A assimetria é deliberada: a camada 1 só sabe dizer *"ninguém poderia disparar"*. **Ela nunca é a
fonte de verdade de qual check roda** — isso fica na camada 2, onde é testável e grátis. Um falso
positivo custa 425 ms de vez em quando; um falso negativo seria buraco calado, que é a classe de
falha registrada em `categoria-nova-esquecida-em-lista-de-enumeracao`.

Medido, ponta a ponta: **3 357 ms → 61 ms** no caminho comum; ~425 ms + trabalho real quando casa.

**Agregação do veredito — a camada 2 roda TODOS os checks e só então decide.** Não para no primeiro
`exit` não-zero. Sai `2` se **qualquer** check saiu `2`, e `0` caso contrário; o stderr de todos sai
junto, na ordem de registro. Parar no primeiro bloqueio esconderia os avisos dos checks seguintes —
e quase todo check do kit é warn-only, então o que se perderia é exatamente o sinal que eles existem
para dar. O custo de rodar o resto é desprezível: já estamos dentro do processo, e dia de bloqueio é
raro. Isto é a contrapartida da defesa 2: se avisar não pode ser engolido por exceção, também não
pode ser engolido por curto-circuito.

## As três defesas

O conselho (3/3 na abordagem) apontou dois riscos invisíveis que a proposta original não tratava.

1. **Fallback.** Se o PowerShell não subir, ou com `PERCUS_DISPATCHER_BYPASS=1`, o `.cmd` chama os 8
   `.cmd` antigos em série — que continuam no disco. Lento e correto > rápido e mudo. Trata o risco
   do Cross-Claude: o ciclo `push → auto-update → relaunch` é longo e a máquina do operador já fica
   dessincronizada (6.45.0 instalado, kit em 6.47.0); bug no dispatcher não pode deixar a frota sem
   enforcement até o próximo ciclo.
2. **Check que explode é reportado, nunca engolido.** `try/catch` por check; a exceção vira linha no
   stderr nomeando o check. O `exit 0` universal de hoje protege contra **bloquear** por engano — não
   pode virar proteção contra **avisar**. Trata o risco do DeepSeek: *"o sinal desaparece no mesmo
   lugar onde o gate deveria reportar"*.
3. **Teste de alcance + teste de contenção.** Um por check: *payload que casa o gatilho de X chega em
   X*. E um estrutural: **o conjunto de gatilhos de cada check ⊆ `gatilhos.txt`** — quem adicionar um
   gatilho e esquecer a união deixa a suíte vermelha em vez de o hook sumir calado. Mais: o
   `enforcement-health` (SessionStart) passa a comparar **registro × disco** — `.ps1` presente e não
   registrado vira aviso alto.

A defesa 3 é a que fecha a classe registrada como **não fechada** em
`categoria-nova-esquecida-em-lista-de-enumeracao`: enforcement que enumera e deixa buraco silencioso.

## `PostToolUse` — a opção D primeiro, porque é grátis

Sugestão do DeepSeek que não estava na proposta original: **estreitar o matcher do
`context-budget-guard` de `""` para `Bash|Edit|Write`**, tirando-o do caminho de `Read`/`Grep`/`Glob`.
É mudança **só de registro, zero código** — e ataca os 477 ms antes de o dispatcher existir. Vai
primeiro, isolada.

Só então o dispatcher de `PostToolUse`, com porta por timestamp em `cmd.exe` (só sobe PowerShell a
cada N segundos). **Duas entradas no `hooks.json`, não uma** — eventos diferentes não compartilham
entrada, e isolar as cadeias reduz o raio de explosão, como o Cross-Claude apontou.

## Não-objetivos

- **Redecidir a forma de enforcement das regras comportamentais.** Tem dono:
  `2026-09-12-enforcement-7-regras-comportamentais.md`. Esta spec só remove a restrição de custo.
- **Reescrever os hooks como funções de um módulo** (opção B do brainstorm). Converteria `exit` →
  `return` em 8 arquivos, quebraria os testes que invocam hook isolado e impediria depurar um hook
  sozinho. Ganho marginal sobre o dispatcher, custo alto. Descartada.
- **Daemon residente com socket** (opção D do Llama). Elimina o spawn de vez, mas é processo com
  ciclo de vida pra gerenciar. 61 ms → ~5 ms não paga isso. YAGNI.
- **Promover qualquer coisa a bloqueio.** Este pacote não muda o veredito de nenhum check.
- **Consertar a dívida do `git -C`** em `Resolve-PercusProjectRoot` (Proposta F) — tarefa própria,
  declarada no plano.

## Critério de pronto

1. Caminho comum medido **abaixo de 100 ms** (hoje 3 357), com o número no commit.
2. Fallback provado: com `PERCUS_DISPATCHER_BYPASS=1`, os 8 checks rodam e o comportamento é
   idêntico ao de hoje.
3. Um teste de alcance por check, e o teste de contenção dos gatilhos.
4. Paridade `.ps1`/`.sh` com teste que **roda o `.sh` de verdade** — padrão do `spec-analyze-check`.
   Nota: o custo de 420 ms é de startup do Windows PowerShell; o bash não tem esse custo, então o
   dispatcher `.sh` existe por **paridade de comportamento**, não de performance.
5. `hooks-manifest.json` atualizado, e o `enforcement-health` comparando registro × disco.
6. Suíte inteira verde — **a suíte toda, não só os testes do tema**.

## Ordem de entrega

1. Opção D: estreitar o matcher do `PostToolUse` — grátis, isolada
2. Dispatcher `PreToolUse` + as 3 defesas + paridade `.sh`
3. Dispatcher `PostToolUse` com porta por timestamp
4. *(passa o bastão para a spec das regras comportamentais)*

## Riscos

1. **Mudança de registro.** `hooks.json` só vale depois de push + auto-update + novo launch. Os 7
   commits pendentes já esperam autorização (R20); este pacote aumenta o custo de não publicar.
2. **O dispatcher é ponto único de falha.** Mitigado pelas defesas 1 e 2, não eliminado.
3. **Os números são desta máquina.** 420 ms é startup do Windows PowerShell 5.1 — deve ser estável na
   frota, que é toda Windows, mas nenhuma outra máquina foi medida.
4. **O teste de contenção depende de os checks declararem seus gatilhos.** Check que declara gatilho
   errado passa nos dois testes e continua cego — o teste prova alcance e contenção, não correção do
   gatilho.

## Reenquadramento que esta spec devolve para a spec das regras comportamentais

Dois pontos **em aberto** lá ganham resposta aqui:

- *"Cinco itens no tier 1 é muito?"* — com o dispatcher, o custo marginal de um check deixa de ser
  420 ms e passa a ser o próprio tempo de execução. A pergunta volta a ser sobre **ruído em sessão**,
  que era o eixo certo.
- *"Publicar R10 sozinho ou tudo de uma vez?"* — publicar sozinho custava um ciclo de auto-update por
  hook. Com o dispatcher, os checks entram na tabela da camada 2 sem entrada nova no `hooks.json`:
  dá para publicar o dispatcher uma vez e **ligar cada check por vez**, que era o que a medição
  atribuível exigia sem o custo que a tornava cara.
