# Consolidação da cadeia de hooks — dispatcher de duas camadas — Design

**Data:** 2026-09-12 · Brainstorm com o operador + conselho 3/3 · **Pré-requisito** da spec
`docs/superpowers/specs/2026-09-12-enforcement-regras-comportamentais.md`, que decide a forma de
enforcement das regras comportamentais. Esta spec não redecide nenhuma delas — decide **quanto custa** adicioná-las.

> **Contagem:** esta spec não carrega o número. O dono é
> `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md`, e a spec das
> comportamentais foi renomeada justamente para tirar a contagem do título — que é onde ela
> envelhecia.

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

O obstáculo aparente é stdin: só pode ser lido uma vez, e todo hook faz `[Console]::In.ReadToEnd()`.
A proposta original resolvia com um contrato novo — o dispatcher grava o payload num arquivo e cada
hook passa a ler `PERCUS_HOOK_STDIN_FILE` se estiver setado, senão `Console.In` — **uma linha por
hook**, em 8 hooks.

> **Substituído por algo mais simples, provado em 2026-09-12 antes de escrever qualquer código:**
> **`[Console]::SetIn([IO.StringReader]$payload)`**. O dispatcher lê o payload uma vez e
> **reposiciona `Console.In` antes de chamar cada check**. Os hooks seguem fazendo
> `[Console]::In.ReadToEnd()` e recebem o payload inteiro, **sem uma linha de mudança em nenhum dos
> 8**. Provado em três chamadas consecutivas, todas lendo o mesmo `tool_input.command`.
>
> Por que é melhor que o contrato de arquivo, e não só mais curto:
> 1. **Zero mudança nos 8 hooks** — a suíte não muda porque não há o que mudar, em vez de não mudar
>    porque tomamos cuidado.
> 2. **Nenhum contrato novo para documentar, testar e alguém esquecer.** `PERCUS_HOOK_STDIN_FILE`
>    seria mais uma convenção que um hook futuro pode não implementar — e o sintoma seria um hook
>    lendo stdin vazio e saindo 0 **em silêncio**, que é a classe de falha que a defesa 3 existe
>    para fechar. O contrato que não existe não pode ser esquecido.
> 3. Dois dos oito (`pre-commit-check`, `external-action-guard`) **não carregam `_helpers.ps1`** —
>    são auto-contidos de propósito. O contrato de arquivo os obrigaria a duplicar a leitura inline
>    ou a ganhar uma dependência que hoje não têm.
>
> Medido junto, no mesmo experimento: um check que sai `2` **não mata o dispatcher**,
> `$LASTEXITCODE` chega intacto, e **os checks seguintes continuam rodando** — que é exatamente a
> agregação de veredito que a seção abaixo exige.

## Arquitetura — duas camadas, e a de baixo é burra de propósito

**Camada 1 — `cmd.exe`, ~61 ms, paga sempre.** Despeja stdin num temp e roda **um**
`findstr /L /G:gatilhos.txt` — a **união** de todos os gatilhos de todos os checks. Não casou nada:
`exit /b 0`, PowerShell nunca sobe.

> **A captura de stdin não é `more`, e o motivo foi medido (2026-09-12).** O design dizia
> `more > %TMPF%`. Medindo os dois idiomas de `cmd.exe` contra payloads reais:
>
> | payload | `more` | `findstr "^"` |
> |---|---|---|
> | 3 KB, linha única, acentos UTF-8 | exato | exato |
> | 80 KB | **corrompe** (80 055 ≠ 80 053) | exato |
> | 200 KB | — | **trunca para 73 781** |
> | 1 MB | — | **trunca para 53** |
>
> **Os dois truncam, e o pior é que truncam saindo `0`.** Payload cortado é JSON inválido; cada
> check cai no próprio `catch`, sai `0`, e a cadeia inteira **passa calada** — perda total de
> enforcement, justamente no comando maior, que é o mais provável de estar fazendo algo sério. É a
> classe de falha que a defesa 2 existe para impedir, entrando pela porta da defesa 1.
>
> **Decisões que saem daí:**
> 1. A captura é **`findstr "^"`**, não `more` — exato até ~80 KB, enquanto `more` já corrompe lá.
> 2. **A camada 2 DEVE validar que o payload capturado parseia como JSON.** Se não parseia, ela
>    **falha alto** (`exit 2` nomeando a causa e o contorno `PERCUS_DISPATCHER_BYPASS=1`), nunca
>    `exit 0`. Não há recuperação possível — stdin já foi consumido e é irreproduzível —, então a
>    única escolha honesta é entre *barrar avisando* e *passar calado*.
> 3. O limite de ~80 KB entra no `hooks-manifest.json` como limite conhecido, com o número medido.
>    Comando de shell acima disso é raro a ponto de nunca ter aparecido; **raro e alto** é aceitável,
>    **raro e mudo** não é.

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

## ~~`PostToolUse` — a opção D primeiro, porque é grátis~~ — **DESCARTADA por medição (2026-09-12)**

A proposta era: **estreitar o matcher do `context-budget-guard` de `""` para `Bash|Edit|Write`**,
tirando-o do caminho de `Read`/`Grep`/`Glob`. Sugestão do DeepSeek, aceita no design como "mudança
só de registro, zero código" — e chamada de **grátis**.

**Não é grátis, e o preço foi medido antes de executar.** Varri 12 transcripts reais (2464 tool
calls):

| | |
|---|---|
| cobertas por `Bash\|Edit\|Write` | 1991 (**80,8 %**) |
| puladas pela opção D | 473 (**19,2 %**) |
| **maior rajada consecutiva de tools puladas** | **130 chamadas** |
| rajadas ≥ 10 | 4 ocorrências (mediana das rajadas: 1) |

Duas conclusões, e as duas contra:

1. **A economia é pequena** — 19 % dos spawns, não os 477 ms por tool call que a motivação promete.
2. **O custo é a cegueira, e ela cai onde mais dói.** A rajada de 130 veio de uma sessão pesada de
   Playwright; as tools puladas são `Read` e snapshots de browser, que estão entre **as que mais
   inflam contexto**. O guard não perde a medição — ele a **atrasa** —, mas atrasar em até 130
   chamadas um aviso que existe para chegar *antes* de a janela estourar é perder o aviso.

O manifesto já dizia isso, e eu ia contra ele sem notar: a nota da entrada registra *"matcher VAZIO
de propósito: contexto cresce com Edit/Write/Read tanto quanto com Bash — guarda que só vê shell é a
classe de furo já registrada (`hooks-percus-so-cobrem-tool-bash`)"*. Estreitar o matcher é reabrir,
em menor escala, um furo que o kit já fechou uma vez.

**E é redundante.** O dispatcher de `PostToolUse` com porta por timestamp em `cmd.exe` entrega a
economia **inteira** (477 ms → ~61 ms em toda tool call) **sem perder cobertura nenhuma**: a porta
limita quantas vezes o PowerShell sobe, e não *quais tools* são observadas. Fazer a opção D antes
seria pagar uma cegueira permanente no registro por um ganho que o passo seguinte entrega de graça.

**Decisão: pular a opção D. O `PostToolUse` vai direto para o dispatcher com porta por timestamp.**
**Duas entradas no `hooks.json`, não uma** — eventos diferentes não compartilham entrada, e isolar as
cadeias reduz o raio de explosão, como o Cross-Claude apontou.

## Não-objetivos

- **Redecidir a forma de enforcement das regras comportamentais.** Tem dono:
  `2026-09-12-enforcement-regras-comportamentais.md`. Esta spec só remove a restrição de custo.
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

## ESTADO DA ENTREGA (2026-09-12, 6.49.0)

**Item 2 ENTREGUE** — dispatcher `PreToolUse` com as 3 defesas, registrado no `hooks.json`.

| critério de pronto | estado |
|---|---|
| 1. caminho comum < 100 ms | ✅ **62 ms** (era 3 716 ms; o design previa ~61) |
| 2. fallback provado com `PERCUS_DISPATCHER_BYPASS=1` | ✅ teste comportamental |
| 3. teste de alcance por check + contenção dos gatilhos | ✅ nos dois sentidos (falta e órfão) |
| 4. paridade `.ps1`/`.sh` rodando o `.sh` de verdade | ⏳ **pendente** — item próprio |
| 5. `hooks-manifest.json` + `enforcement-health` registro × disco | ✅ campo `registro` novo |
| 6. suíte inteira verde | ✅ 580/0 |

Validação contra tráfego real (1 233 comandos de transcript): **80,5% dormem** na camada 1;
4 582 s → 164 s (**28x**).

**Os 8 hooks não mudaram uma linha** — ver a nota do `[Console]::SetIn` acima. Os `.cmd` antigos
continuam em disco: são a rota de fallback da defesa 1, não resíduo.

**Item 3 (dispatcher `PostToolUse` com porta por timestamp) é o próximo.** Ele carrega sozinho o
ganho que a opção D descartada prometia — sem a cegueira de 130 chamadas.

## Ordem de entrega

1. ~~Opção D: estreitar o matcher do `PostToolUse`~~ — **descartada por medição**, ver seção acima.
   Economia de 19 % dos spawns ao preço de até 130 chamadas consecutivas sem medir, e redundante
   com o item 3.
2. Dispatcher `PreToolUse` + as 3 defesas + paridade `.sh` ← **primeiro passo real**
3. Dispatcher `PostToolUse` com porta por timestamp (entrega o ganho do `context-budget-guard`
   **sem** perder cobertura, que é o que a opção D não fazia)
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
