# Enforcement das regras do canon que não têm hook — plano

**Origem:** sessão de 2026-09-12. O operador perguntou *"já revisou a spec com o conselho?"* e a
resposta foi não — o canon manda rodar `spec-analyze` sozinho, em três lugares, e **não havia hook
nenhum**. A pergunta seguinte dele define este plano: *"qual o sentido de criar regras que alguém
precisa lembrar para acionar? Se existe a regra e não existe o hook, tá errado — revisa isso para
essa regra e outras e vamos corrigir."*

## A auditoria (medida, não estimada)

Das **25 regras** de `01_REGRAS_INEGOCIAVEIS.md`:

| Situação | Quantas | Quais |
|---|---|---|
| Com enforcement mecânico | 9 | R1, R2, R3, R7, R8, R9, R11, R20, R23 |
| Arquiteturais — o R11 cobre no review de código, hook próprio seria custo sem ganho | 7 | R14, R15, R16, R17, R18, R19, R21 |
| **Comportamentais descobertas** | **9** | **R4, R5, R6, R10, R12, R13, R22, R24, R25** |

> **Fonte da tabela (R25):** `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md`.
> A cópia acima existe para leitura corrida; **o número que vale é o de lá**, e quem recontar atualiza
> lá primeiro. Esta duplicação já provou que diverge: a correção de 9/7/6 → 11/7/7 (que somava 22 e
> omitia R4 e R9, pega pelo R11 no review deste próprio plano) precisou de três edições em três
> arquivos.

A mais constrangedora é a **R12**: *"Se uma regra não tem como você verificar objetivamente que
cumpriu, ela é decoração"* — e R12 não tem verificação nenhuma. É decoração pelo próprio critério.

## Ordem acertada com o operador

1. ~~**Conselho**~~ — 6.46.0 ✅. A perna Cross-Claude morria calada com chave sem crédito; o hook do
   spec dependeria de uma ferramenta que falhava 1/3 das vezes, e isso viraria escape rotineiro.
2. ~~**Hook `spec-analyze-check`**~~ — 6.47.0 ✅. Warn-only, três estados, paridade `.ps1`/`.sh`.
3. **As comportamentais** — R4, R5, R6, R10, R12, R13, R22, R24, R25 (**9**, não 7: ver dívida
   abaixo). Spec escrita
   (`specs/2026-09-12-enforcement-regras-comportamentais.md`): decide a **forma** de cada uma.
4. **Consolidação da cadeia de hooks** — spec
   (`specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md`). **Virou pré-requisito da 3** por
   medição. **Item 2 (dispatcher `PreToolUse`) ENTREGUE e PUBLICADO em 6.49.0.**
   **Item 3 (dispatcher `PostToolUse`) ENTREGUE em 6.50.0** — e um emoji num comentário dele derrubava toda tool call, consertado na 6.51.0. **Paridade `.sh` dos dois dispatchers ENTREGUE em 6.53.0**: o item 4 fechou por inteiro.
5. ~~**Faixa de regras do revisor**~~ — **ENTREGUE** (`0d8a0d0`, 2026-09-12). Não eram 8 sítios:
   eram **36 ocorrências em 17 arquivos**, em três tetos que discordavam entre si, com o canon em
   R25. O verbete tinha varrido só `plugin/percus-review/scripts/` e relatado o número como se
   fosse do repo — ficaram de fora os `commands/`, os três `system-prompt-*.md` dos providers, a
   skill `delegate-impl` e o `percus-review-auto.{ps1,sh}`, que roda a CADA commit da frota.
   Conserto: helper `_faixa-regras.{ps1,sh}` deriva o maior `^## R<N>.` em tempo de execução;
   `.md` carregado por código usa `{{FAIXA_REGRAS}}` substituído no load; prosa estática parou de
   citar faixa. Sem medir o canon, o prompt diz *"faixa não medida"* — nunca chuta teto. 19 testes,
   incluindo prova ponta a ponta por socket local (o corpo HTTP que sai leva `R1-R25` e nenhum
   placeholder cru) e guarda de regressão que impede faixa literal nova. Verbete atualizado.
6. **Gate da R11** — spec escrita (`specs/2026-09-12-r11-gate-negativa-bem-sucedida-design.md`),
   veredito **`BLOQUEADA`** do conselho (2/3). O *diagnóstico* foi confirmado; o *desenho da solução*
   precisa ser refeito a partir da seção "Opções". Findings listados no topo da spec.
7. **Pacote B** — ajustar o spec pelos findings do conselho e implementar `plano-sync`.
8. ~~**Skill `checkpoint`**~~ — **ENTREGUE** (`913668c`, 2026-09-12). O gatilho pedido foi pra
   `description` do frontmatter, que é o que de fato faz o Claude Code disparar a skill: a palavra
   "checkpoint" dita pelo operador virou o gatilho principal. Passo 0 novo (**termine a tarefa
   atual** antes de sincronizar, com saída declarada quando não dá pra terminar) e o limite do
   `/clear` saiu do passo 5 pra porta de entrada. 7 testes. **Enforcement mecânico fica pendente:**
   o certo pela R12 é um hook `UserPromptSubmit`, mas `hooks.json`/`hooks-manifest.json` estão
   sendo reestruturados na outra janela — mexer agora é colisão garantida.
9. **Poda do canon — o que ficou obsoleto e pode ser descartado.** Pedido do operador em 12/09,
   **depois** dos itens 5 e 8. Varrer as 25 regras e perguntar de cada uma *"isto ainda descreve
   como trabalhamos?"*, propondo descarte do que morreu. Três coisas medidas hoje que tornam isto
   oportuno e dizem por onde começar:
   - **R5 e R6 não têm o enforcement que a auditoria dizia ter** — os hooks que se autodeclaram
     `(R5)`/`(R6)` cobram tipos e migration, disciplinas que eram R5/R6 num **canon anterior à
     renumeração**. Se o canon já foi renumerado uma vez, há resíduo dessa renumeração em mais
     lugares. Fonte: `conhecimento/resolver/auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe.md`.
   - **R12 é o critério de poda pronto**: *"regra que você não consegue verificar objetivamente que
     cumpriu é decoração"*. A poda é a aplicação da R12 ao próprio canon — e hoje 9 das 25 não têm
     seção de gate escrita.
   - ~~**O revisor só conhece até R13/R19/R23**~~ — **DESTRAVADO em 2026-09-13 (6.51.0).** Eram
     DOIS bloqueios, não um. O item 5 fechou o primeiro (a faixa curta). O segundo apareceu ao
     consertá-la: os `system-prompt-{review,consult}.md` carregavam uma **cópia inline das 19
     primeiras regras** numa numeração pré-renumeração, com **7 delas (R1, R2, R4, R6, R8, R9,
     R12) trazendo o texto errado debaixo do número certo**. Os dois estão fechados: a faixa e os
     **títulos** vêm do canon em tempo de execução (`{{FAIXA_REGRAS}}` e `{{REGRAS_DO_CANON}}`,
     substituídos no load), com prova ponta a ponta por socket local de que o corpo enviado ao
     modelo leva o título do canon de agora. Verbete:
     `conhecimento/resolver/system-prompt-do-revisor-tem-copia-do-canon-com-texto-de-regra-errado.md`.

     ➡️ **A poda pode começar.** O revisor agora enxerga as 25 regras e as enxerga com o texto
     certo, então *"ninguém cobra esta regra"* voltou a ser uma conclusão medível. Fica valendo o
     aviso abaixo: continua não sendo exercício de contagem.
   ⚠️ **Não é exercício de contagem.** Regra descartada some do prompt do revisor e do critério de
   review de todos os projetos da frota. Cada descarte precisa dizer *o que passa a não ser mais
   verificado por ninguém* — e o descarte só vale com o operador aprovando um a um.

## ESTADO DA EXECUÇÃO

### ✅ Feito (PUBLICADO até 6.52.0; a 6.53.0 está commitada, push pendente de R20)

- **6.45.0** `context-budget-guard` — PostToolUse em todas as tools, mede o contexto vivo pela cauda
  do transcript. Nasceu de uma sessão que foi a 610k tokens com "checkpoint" dito 11 vezes.
  **Publicado** (o cache já tem 6.45.0).
- **6.46.0** conselho — fallback pelo resultado (não pela presença da chave), flag
  `PERCUS_CROSS_CLAUDE=subagent`, `cross_claude_pending` honesto, resumo do F3 com
  `nao-verificado=N`. **Publicado.**
- **6.47.0** `spec-analyze-check` — o gate `[S]` mecânico. **Publicado.**
- **6.48.0** `context-budget-guard` com janela descoberta em vez de suposta (outra sessão).
- **6.49.0** **dispatcher de hooks de duas camadas** — `3 716 ms → 62 ms` em todo comando Bash;
  80,5% dos comandos reais dormem na camada 1 (4 582 s → 164 s, 28x sobre 1 233 comandos de
  transcript). Os 8 checks **não mudaram uma linha** (`[Console]::SetIn`). Campo `registro` novo no
  manifesto. O review cross-provider achou **3 bugs de perda silenciosa de enforcement** (EAP
  herdado, payload não-gravável saindo 0, colisão de `%RANDOM%`), todos consertados e provados por
  mutação. **Publicado** (`ec0d798`).
- **Spec do Pacote B** commitada (`e18abf8`), com veredito `AJUSTAR` do conselho — 10 findings a
  tratar antes de implementar.
- **6.50.0** dispatcher `PostToolUse` com porta por timestamp (outra sessão). **Publicado** (`5cf6304`).
- **6.51.0** **o revisor lê o canon em vez de citar de memória** — três defeitos da mesma família
  ("literal escrito à mão fazendo as vezes de fonte"), fechados com derivação em runtime e guarda:
  1. faixa de regras literal em **36 ocorrências / 17 arquivos** (não 8), três tetos discordando,
     canon em R25 → `scripts/_faixa-regras.{ps1,sh}` deriva o maior `^## R<N>.`;
  2. `system-prompt-{review,consult}.md` carregavam **cópia das 19 primeiras regras com 7 textos
     errados** (numeração pré-renumeração) → `{{REGRAS_DO_CANON}}` substituído no load;
  3. **bug de produção da 6.50.0:** um `⚠️` no `percus-dispatch-post.cmd` fazia o `cmd.exe` comer 4
     caracteres do início das linhas → exit 255 em toda tool call; só na codepage OEM (no Git Bash
     dava verde). Guarda: `cmd-ascii-puro.tests.ps1`.
  O R11 achou 3 defeitos reais no próprio conserto (degradação que matava sob `set -e` fora de
  `$( )`, travessão sem prova no PS 5.1, asserção vazia). **Publicado** (`0d19a31`, `246fd4d`).
- **Skill `checkpoint`** ganha o gatilho pedido: a palavra "checkpoint", passo 0 "termine a tarefa
  atual", e o limite do `/clear` dito na porta (`913668c`, publicado junto da 6.51.0).
- **6.52.0** **hora de parede deixa de ser gatilho do `context-budget-guard`.** Decisão do operador:
  *"o contexto não enche por horas, enche por trabalho"*. Saem o gatilho de 8h, `PERCUS_CTX_HOURS` e
  toda menção a horas nas mensagens; ficam tokens e idade do transcript. **Publicado** (`29ce534`,
  2026-09-13; janela R20 arquivada em `docs/historico/2026-09-13-r20-publicacao-6.52.0-consumida.json`).
- **6.53.0** **paridade `.sh` dos dois dispatchers.** São `percus-dispatch-pre.sh` e
  `percus-dispatch-post.sh`, com 58 testes que rodam o `.cmd` real e o `.sh` lado a lado, contra o
  mesmo payload, exigindo saídas iguais. O teste achou cinco armadilhas que um lado só não veria: o
  `\r` do `jq.exe` nativo zerando a seleção de checks; o `set /p` com BOM válido em 65001 e lixo em
  850; o `chcp` que come stdin; o lançador do Git que devolve `%HOME%\bin` ao PATH; e um `U+001F` que
  chegou ao disco como byte. **Commitado, push pendente de R20.**

### ✅ Tarefa 3 fechada (2026-09-12)

Spec: `docs/superpowers/specs/2026-09-12-enforcement-regras-comportamentais.md`.
Triagem por **shape do observável** (guarda de comando / guarda de caminho / observador de transcript
/ teste do canon). Resultados que mudam o plano:

- **R12 e R25 não viram hook** — o observável delas é o canon, e o canon tem suíte: viram teste.
- **R24 não vira gate** — a exceção legítima da própria regra é o caso mais comum; vira medidor.
- **R13 racha**: só o trailer é mecânico, e está bloqueado por **três** dívidas do wrapper.
- **CRITICAL do conselho:** R5 e R6 **não tinham hook** — `types-check` e `migration-check` citam
  numeração stale. A auditoria inteira foi feita por varredor de número citado (mede rótulo, não
  gate). Tabela dona corrigida 11/7/7 → **9/7/9**; verbete novo
  `conhecimento/resolver/auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe.md`.

**Rodada 2 do `spec-analyze` (2026-09-12 18:02) — veredito `AJUSTAR`, sem CRITICAL.** Saiu de
`BLOQUEADA`. Tratamento integral dos findings na §7 da spec. Três resultados mudam o plano:

1. **A Proposta F (`git -C`) virou pré-requisito do medidor de R24**, não mais dívida paralela. A
   cadência de deploy é métrica *por projeto*, e `Resolve-PercusProjectRoot` resolve raiz errada — o
   que não degrada o número, inverte. Achado da perna Cross-Claude.
2. **Terceira dívida do wrapper `deepseek-impl`:** o `ts` é gravado sem offset de fuso, e a
   comparação de RF12a precisa dele. Sem conserto, o detector de trailer erra pelo tamanho do fuso
   (4h aqui). Soma-se a `apply` (RF13) e raiz do projeto (RF14).
3. **O conselho não cabe mais na spec.** O orquestrador truncou 9329 → ~8000 tokens e a perna Llama
   tem teto próprio de 5000 — ela emitiu `BLOQUEADA` sobre um documento que **não leu inteiro**, e
   o CRITICAL dela foi refutado por medição (0 blocos duplicados envolvendo a spec, de 1051 docs
   varridos). Mitigação usada: dar à perna Cross-Claude o **caminho do arquivo**, não o texto.
   Registrado como risco §6.9 da spec — é defeito do kit, não da spec.

### ⏳ Próximo passo imediato (checkpoint de 2026-09-13)

**A sessão de 12→13/09 fechou os itens 5 e 8 da "Ordem acertada" e destravou o 9.** Antes da fila:

0. ~~**Push da 6.52.0**~~ — **FEITO em 2026-09-13** (`246fd4d..29ce534`), com autorização R20 do
   operador na conversa; janela arquivada em `docs/historico/`. **O passo 0 agora é o push da 6.53.0**,
   e ele pede R20 de novo: a autorização anterior cobria aqueles 4 commits, não commit novo.
1. **Poda do canon (item 9) — DESTRAVADA.** O revisor enxerga as 25 regras, e com o texto certo.
   Decisão do operador: entra antes ou depois da fila abaixo. Descarte só com aprovação um a um.

**Pendências novas, descobertas nesta sessão (fora da fila abaixo):**
- **Hook `UserPromptSubmit` para o gatilho "checkpoint"** — o enforcement mecânico que a R12 pede.
  Esperava a reestruturação de `hooks.json`/`hooks-manifest.json`, que aterrissou na 6.50.0: livre.
- **`canon-version-check` avisa SEMPRE** — compara a data do frontmatter com semver, e o comentário
  diz que é de propósito. Aviso que nunca fica verde é aviso desligado; foi por isso que a cópia
  stale do canon sobreviveu quatro meses. Consertar a comparação ou apagar o aviso.
- **R10 não tem hook nenhum.** O operador achava que R10 pedia autorização; quem pede é só a R20
  (`external-action-guard`). R10 segue entre as comportamentais sem enforcement (item 4 da fila).

**FILA, na ordem, autorizada pelo operador para execução autônoma:**

1. ~~**Dispatcher `PostToolUse`** com porta por timestamp~~ — **ENTREGUE em 6.50.0**, suíte
   625/625. 684 ms → 320 ms ponderado por tráfego real (63% das chamadas nem sobem o PowerShell).
   A porta não cria cegueira nova: o maior salto de contexto de um passo (104 664 tokens) já
   excede o maior crescimento não observado sob qualquer porta testada. Medições e os dois
   achados fora de escopo (`registro` nomeando o dispatcher; escopo do `registrar-hooks`) estão
   na seção de estado da spec de consolidação.
2. ~~**Paridade `.sh`**~~ — **ENTREGUE em 6.53.0**: `percus-dispatch-{pre,post}.sh` e 58 testes que
   rodam o `.cmd` e o `.sh` lado a lado. As cinco armadilhas que ela achou estão na seção de estado da
   paridade `.sh`, na spec de consolidação. **O próximo da fila é o item 3, Pacote B.**
3. **Pacote B** — `AJUSTAR` com 10 findings do conselho a tratar antes de implementar `plano-sync`.
4. **Os hooks das comportamentais**, na ordem que a spec manda: **R5 primeiro e sozinho** (único
   bloqueante; operador autorizou publicar em vigor), depois medir, depois R10 sozinho, depois o
   resto.
5. **Proposta F** (`git -C` em `Resolve-PercusProjectRoot`) — pré-requisito do medidor de R24.
6. **As três dívidas do wrapper `deepseek-impl`** — pré-requisito do hook de trailer da R13.

> **A ordem 1→2 inverte o que a spec de consolidação diz**, e de propósito: a "opção D" (item 1 de
> lá) foi **descartada por medição** — economizava 19% dos spawns ao preço de até **130 chamadas
> consecutivas** sem medir contexto. Ver a seção própria naquela spec.

**Estado da árvore:** kit em **6.53.0**, com o commit da paridade `.sh` aguardando push (R20). O
cache desta máquina está em **6.51.0**: o `installed_plugins.json` foi relido em 13/09, e o "6.49.0"
que este parágrafo dizia já estava vencido. A 6.52.0 está publicada e chega por auto-update. A 6.53.0
não muda registro (`hooks.json` intocado); ela só acrescenta os `.sh` e os testes.

**Por que isto entrou na frente.** A tarefa 3 ia adicionar 4 hooks; medi a cadeia antes e ela já
custa **3 357 ms em todo comando Bash** (8 hooks × ~420 ms de startup do PowerShell, mesmo em
no-op), mais **477 ms em toda tool call** no `context-budget-guard`. Verbete:
`conhecimento/resolver/cadeia-de-hooks-cobra-420ms-por-hook-mesmo-em-no-op.md`. Conselho 3/3 na
abordagem do dispatcher. Com ele, **3 357 ms → 61 ms** e o custo marginal de um check novo vira o
próprio tempo de execução — que é o que devolve a decisão das 7 para o mérito.

**A decisão de *quais merecem* já está tomada**, em
`specs/2026-09-12-enforcement-regras-comportamentais.md` (triagem por shape do observável: R12 e
R25 viram teste de suíte; R22, R13, R4, R10 viram hook warn-only; R24 vira **medidor**, não gate). A
tabela abaixo é a versão rascunho que originou aquela spec — mantida por registro histórico; **o que
vale é a spec**.

| Regra | O que é | Enforcement plausível |
|---|---|---|
| **R10** | design por gatilho lexical | é literalmente um gatilho de texto — o caso mais fácil |
| **R22** | `PERCUS_PORT_BASE` obrigatório | grep por porta hardcoded no staged |
| **R24** | cadência de deploy | detectar deploy fora de milestone |
| **R25** | single-source-of-truth | detectar bloco duplicado entre docs |
| **R4** | parar em vez de contornar credencial | difícil: o sintoma é o agente *não* ter parado |
| **R13** | roteamento de modelos | difícil: exige julgar a tarefa |
| **R12** | meta-regra | provavelmente não é hook, e sim um teste que varre as regras e cobra a coluna "como verificar" — o que tornaria esta auditoria permanente em vez de pontual |

### 🔻 Dívidas declaradas (não escondidas)

- **`git -C <dir>` não resolve a raiz** em `Resolve-PercusProjectRoot` (`_helpers.ps1`) — buraco
  comum aos **8 hooks de comando**. O `pre-commit-check` resolve, com lógica própria (Proposta F,
  v6.7.x) que nunca foi promovida ao helper. Portar cobre os oito de uma vez; pede teste próprio.
  ⚠️ **Deixou de ser só dívida:** virou **pré-requisito** do medidor de R24 (RF26b) — ver rodada 2.
- **O wrapper `deepseek-impl` tem TRÊS dívidas**, todas pré-requisito do hook de trailer do R13:
  não grava `apply` no log (RF13); grava em `(Get-Location)` em vez da raiz (RF14); e grava `ts`
  **sem offset de fuso** (RF12a1), o que torna impossível a comparação com `%cI` do git.
- **O `spec-analyze` trunca specs grandes** e o log não registra quanto cada perna viu. Uma perna
  emitiu `BLOQUEADA` sobre documento incompleto nesta sessão. Conserto plausível: passar arquivo em
  vez de texto quando o alvo é arquivo, **ou** marcar no log o tamanho visto por perna. Enquanto não
  houver, a mitigação é dar à perna Cross-Claude o caminho do arquivo.
- **O `context-budget-guard` erra o DENOMINADOR na frota inteira, não em caso raro.** Medido em
  2026-09-12: dos 40 transcripts, **nenhum** declara o marcador `[1m]`/`-1m` no campo `model`, então
  a perna 2 da descoberta de janela nunca dispara e o hook cai no piso de 200k. Observado ao vivo
  nesta sessão: com 181k numa janela de 1M ele anunciou "LIMITE DURO cruzado / resume impossível".
  A perna 3 (falsificação) só cobre **acima** de 200k. Consertos plausíveis: ler a janela de uma
  fonte que o harness declare, ou parar de afirmar limiar enquanto a janela for suposta. Este é
  também o motivo de a porta do dispatcher `PostToolUse` ser fixa e não adaptativa.
- **A idade do transcript ainda usa o relógio.** Na 6.52.0 a hora de parede saiu do gatilho, mas a
  condição de DIAS continua sendo `(agora − 1º timestamp) / 24` — não distingue "retomou um
  transcript de 2 dias atrás" (o incidente real) de "trabalhou 48h seguidas". O sinal certo para
  resume velho é o **intervalo desde a última entrada** do transcript, não a idade da primeira.
- **8 `It` de paridade `.sh` viram `Skipped` quando a suíte roda de um pwsh sem `bash` no PATH.** São
  3 em `council-fallback-cross-claude.tests.ps1` e 5 em `spec-analyze-check.tests.ps1`, que resolvem o
  bash só por `Get-Command`. E o `rodar-suite` só sai ≠ 0 com falha: o skip aparece apenas como um
  `passou/total` menor. O conserto é barato: o fallback `Git\bin\bash.exe` que
  `context-budget-guard.tests.ps1` já usa, e o `rodar-suite` passar a imprimir `Skipped`. Verbete:
  `conhecimento/resolver/teste-de-hook-no-windows-mede-o-ambiente-do-runner-e-nao-o-do-harness.md`.
- **`dispatch-pre.tests.ps1` e `dispatch-post.tests.ps1` rodam o `.cmd` com `-NoNewWindow`**, isto é, na
  codepage do console que os chamou (65001 no terminal do agente, OEM pela suíte). Nenhum caso deles
  depende disso hoje, mas é a mesma armadilha que a paridade `.sh` pegou com o BOM do `porta-post.txt`.
- **`.sh` do kit sem garantia de LF.** Medido em 2026-09-13: `core.autocrlf=true` nesta máquina e
  nenhum `.gitattributes` no repo; o `git add` dos dois dispatchers `.sh` avisou "LF will be replaced
  by CRLF the next time Git touches it". A cópia de trabalho está em LF (os testes rodam), mas um
  checkout que o git reescreva pode entregar `.sh` com CRLF, e bash com CRLF quebra. Vale para
  **todos** os `.sh` do kit, não só os novos, e o verbete `health-check-versao-vence-autoupdate` já
  mediu CRLF no cache do plugin. Não medido ainda: se algum `.sh` do cache roda de fato em algum
  lugar. Conserto plausível: `.gitattributes` com `*.sh text eol=lf`, depois de medir.
- **`spec-analyze-check` é warn-only** por desenho. Promover a bloqueio é decisão separada, depois
  de medir quanto a frota reclama.
- **`pre-commit-check` casa `git`…`commit` como texto** — barrou dois comandos de *teste* nesta
  sessão. Guarda conservadora funcionando; o falso positivo é o lado seguro.
- ~~**A spec das comportamentais está desatualizada na contagem.**~~ **Quitada (2026-09-12).** O
  arquivo foi renomeado para `...-enforcement-regras-comportamentais.md` — **sem número**, que era a
  fonte do defeito: contagem no título é uma segunda cópia do número que só o verbete dono deveria
  ter. R5 e R6 entraram na triagem como descobertas (RF20a) e o que falta delas — **o shape de cada
  uma** — está declarado em aberto na §6.8 da spec, não escondido. Dono do número:
  `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md`.
- **Pacote B**: `AJUSTAR` com 10 findings (6 DeepSeek, 2 Llama, 2 Cross-Claude), incluindo uma
  afirmação minha no spec que citava `153 linhas` como prova de que um teto de `150` funciona.

### Publicação

`PERCUS_CANON_DIR` aponta para este repo, então **scripts** (`medir-baseline-boot`, `plano-sync`
futuro) valem no instante em que são salvos. **Hooks e skills** só chegam aos projetos por
publicação: push → auto-update (≤10 min) → novo launch. Cache desta máquina: **6.51.0**; kit em **6.53.0**; `origin/main` em `29ce534` (6.52.0).
O commit da 6.53.0 aguarda push, pendente de autorização do operador (R20).
