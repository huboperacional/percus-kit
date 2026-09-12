# Spec — enforcement das regras comportamentais do canon

**Tarefa 3** do plano `docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md`.
Entrega desta spec: **decidir quais delas merecem hook e qual o shape de cada uma** — não escrever
hook. A lição que governa a decisão: gate que dispara em massa no primeiro dia vira escape
declarado.

> **Sem número no título, de propósito.** A versão anterior se chamava *"as 7 regras
> comportamentais"* e o arquivo, `...-enforcement-7-regras-comportamentais.md`. O número envelheceu
> em menos de um dia — a correção de premissa de §1 levou o balde de 7 para 9 — e um título com
> contagem vira uma segunda cópia do número que só o
> `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md` deveria ter (R25).
> **Em escopo:** R4, R5, R6, R10, R12, R13, R22, R24, R25 — a lista vive na tabela de §2, e quem
> recontar atualiza o verbete dono primeiro.

## 1. Problema

A auditoria de 2026-09-12 achou 7 regras que o canon declara e nada verifica. **Fonte da tabela
(R25):** `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md` — esta spec não
recopia a contagem; o número que vale é o de lá.

A evidência que originou tudo: uma spec foi escrita, commitada e apresentada **sem** `spec-analyze`,
com a regra escrita em três lugares. Só o operador perguntando revelou.

### Medição nova (desta sessão, sem dono anterior)

Cruzando as 25 regras contra a presença de uma seção `**Gate de verificação:**` em
`01_REGRAS_INEGOCIAVEIS.md`:

- **9 regras não têm gate escrito:** R4, R5, R6, R7, R9, R10, R11, R12, R20.
- Dessas 9, **4 têm hook de verdade** (R7, R9, R11, R20) — a dívida ali é **documental**.
- **R4, R5, R6, R10 e R12** estão sem hook *e* sem gate escrito.

> **Correção de premissa (conselho, CRITICAL, veredito `BLOQUEADA` — Cross-Claude).** A primeira
> versão desta spec dizia "6 têm hook", contando **R5** e **R6**. Falso, e verificado 1:1:
> `types-check-pre-commit` se autodeclara `(R5)` e cobra `mypy --strict`/`tsc`, mas **R5 hoje é
> confirmação antes de operação irreversível**; `migration-check-pre-commit` se autodeclara `(R6)` e
> cobra migration junto com model change, mas **R6 hoje é banco novo por projeto**. Os hooks citam
> uma numeração que o canon já renumerou. A auditoria inteira foi levantada por um varredor que casa
> `R<N>` no comentário do hook — mede **rótulo, não gate**. Isso corrigiu a tabela dona de 11/7/7
> para **9/7/9** e gerou o verbete
> `conhecimento/resolver/auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe.md`.

**O detector precisou ser ancorado no cabeçalho.** Por substring (`grep "Gate de verificação"`) o
resultado foi 8; ancorado em `^\*\*Gate de verifica` foi 9. As duas que flipam — R11 e R12 — são
exatamente as que *falam sobre* gates no corpo do texto. Um detector de gate que casa prosa aprova a
regra que discute gates e reprova nenhuma. (Mesma classe de
`gotcha_trava_por_texto_reprova_por_prosa_e_o_comentario_e_codigo`.)

## 2. A decisão: triagem por shape do observável

O discriminante do verbete responde *se* a regra precisa de enforcement. Ele não responde *se dá pra
fazer*. Esse é o eixo que faltava: **toda guarda precisa de um observável**. Os shapes de hook são os
quatro valores que o campo `alvo` de `hooks-manifest.json` de fato aceita hoje — e o quinto shape
desta tabela **não é hook nenhum**, é a suíte:

| Shape | Evento | O que lê | Exemplo vivo | `alvo` |
|---|---|---|---|---|
| guarda de comando | PreToolUse Bash\|PowerShell | `tool_input.command` | `pre-commit-check` | `comando` |
| guarda de caminho | PreToolUse Edit\|Write | `tool_input.file_path` | `knowledge-write-guard` | `caminho` |
| guarda de plano | ExitPlanMode | o plano submetido | `pre-plan-exit` | `plano` |
| observador de transcript | PostToolUse | `transcript_path` | `context-budget-guard` | `transcript` |
| **teste do canon** | suíte Pester | os arquivos do canon | `gate-conhecimento.tests.ps1` | **— (não é hook)** |

> **Correção factual (conselho rodada 2, Cross-Claude).** A versão anterior desta tabela dizia que os
> quatro shapes estavam "declarados no campo `alvo`", contando `teste do canon` como um deles e
> omitindo `plano`. Errado nas duas pontas: Pester não é hook e não tem campo `alvo`; e `plano`
> existe, é usado pelo `pre-plan-exit`, e tinha sumido da tabela. A afirmação foi verificada contra
> `hooks-manifest.json`, não contra a memória — que é a mesma disciplina que §1 cobra.

**Regra que não tem observável em nenhum shape não vira hook** — vira skill, review, ou nada.

| Regra | Observável | Shape | Veredito | Tier |
|---|---|---|---|---|
| **R10** design | prompt do usuário | **UserPromptSubmit** (novo) | hook warn-only | 1 |
| **R22** porta | arquivos staged | guarda de comando | hook warn-only | 1 |
| **R13** trailer | msg do commit + `.deepseek/runs/` | guarda de comando | hook warn-only | 1 |
| **R12** meta | o próprio canon | teste do canon | teste + allowlist | 1 |
| **R25** ref efêmera | o próprio canon | teste do canon | teste | 1 |
| **R4** credencial | caminho + conteúdo escrito | guarda de caminho | hook warn-only | 2 |
| **R24** cadência | comando de deploy | guarda de comando | **medidor, não gate** | 2 |
| **R25** bloco duplicado | o próprio canon | teste do canon | teste | 2 |

Três consequências da triagem, que são a resposta a *"quais merecem"*:

1. **R12 e R25 não são hook.** O observável delas é o documento do canon, e o canon tem suíte. Vira
   teste: **ruído zero em sessão** e a auditoria deixa de ser pontual e passa a ser permanente.
2. **R24 não vira gate.** A exceção legítima da própria regra — *"sob solicitação direta do
   operador"* — é o caso mais comum, e um PreToolUse não consegue vê-la. Gate ali dispararia
   majoritariamente em deploy legítimo: escape declarado no primeiro dia. Vira **registro
   silencioso** — mesmo movimento do `context-budget-guard`, que mediu antes de qualquer um gatear
   contexto.
3. **R13 racha em duas.** A metade mecânica (o trailer) é detectável; a metade de julgamento
   (*"devia ter delegado?"*) fica com a skill `delegate-impl`, que já existe e já pontua heurística.

## 3. Não-objetivos

- Hook para as 7 arquiteturais (R14–R19, R21) — o R11 cobre no review de diff.
- Julgar se uma task **devia** ter sido delegada (R13) ou se um deploy caiu no gatilho certo (R24).
- **Promover qualquer coisa a bloqueio.** Todo hook novo nasce warn-only; promoção é decisão
  separada, depois de medir quanto a frota reclama.
- Consertar a dívida do `git -C` nos 8 hooks de comando (Proposta F) — é tarefa própria, declarada no
  plano. Os hooks novos nascem com ela.
- Alocar `port_base` para projetos que não têm (R22 avisa, não aloca).

## 4. Requisitos funcionais

> **Convenção WHAT/HOW desta spec (resposta a um finding de 2 pernas do conselho).** Duas coisas que
> parecem HOW ficam aqui de propósito, porque **são a decisão**, não a implementação dela:
>
> 1. **Nome de escape** (`PERCUS_SKIP_*`). Um escape sem nome não é um escape decidido — é uma
>    promessa. O nome é o contrato com o operador: é o que ele digita às 2h da manhã quando o gate
>    dispara errado. Deixar para o plano significa que a spec aprovou "vai ter uma saída" sem dizer
>    qual.
> 2. **Âncora de detecção** quando a âncora *é* o requisito. RF17 (`^\*\*Gate de verifica`) não é
>    escolha de regex: §1 mediu que a versão por substring aprova justamente as regras que *falam
>    sobre* gates. A ancoragem é o comportamento decidido; o dialeto de regex não é.
>
> O que **não** é vinculante: os regex literais de RF7 e RF23, marcados `(ilustrativo)`. Eles
> mostram a forma do sinal; o plano escolhe a expressão exata e a testa.

### R10 — gate de design por gatilho lexical

- **RF1.** QUANDO o prompt do usuário contém um **substantivo-gatilho** (lista fechada em RF1a) **E**
  um verbo de criação/redesenho (RF4) **E** nenhum marcador de exceção (RF3), O SISTEMA DEVE injetar
  no contexto um aviso nomeando o gatilho casado e a bifurcação (componente isolado → shadcn MCP;
  tela/fluxo → v0.dev).
- **RF1a.** A lista de substantivos-gatilho DEVE ser **exatamente** a enumerada na R10 de
  `01_REGRAS_INEGOCIAVEIS.md`, copiada aqui como contrato de teste e não como fonte (dono: a R10):

  > `landing page` · `página inicial` · `home` · `redesign` · `redesenhar` · `refazer tela` ·
  > `hero section` · `seção de X` · `banner` · `CTA` · `dashboard` · `painel` · `tela de métricas` ·
  > `fluxo de onboarding` · `fluxo de cadastro` · `fluxo de checkout` · `pitch deck` ·
  > `apresentação` · `one-pager` · `melhorar UI/UX` · `deixar mais bonito` · `modernizar visual`

  Um teste da suíte DEVE reprovar se a lista do hook divergir da lista da R10 — sem isso esta cópia
  é a duplicação que a própria R25 proíbe.
- **RF1b.** O último gatilho da R10 — *"qualquer pedido que envolva mais de 1 tela nova"* — **não é
  lexical e fica FORA** do hook: exige julgar o pedido, que é o que §2 chama de "sem observável".
  Declarado aqui para que a diferença entre a regra e o gate seja explícita, não descoberta depois.
- **RF2.** QUANDO o prompt contém o gatilho mas nenhum verbo de criação (`"o dashboard tá com erro
  500"`, `"corrige o painel"`), O SISTEMA DEVE ficar em silêncio.
- **RF3.** QUANDO o prompt contém marcador de exceção da própria regra (bug fix, ajuste de copy,
  troca de cor, `"sem mockup"`), O SISTEMA DEVE ficar em silêncio.
- **RF4.** O casamento de verbo DEVE ser por radical, nunca por lista de conjugações — marcador por
  conjugação nasce cego (`gotcha_trava_de_copy_so_ve_exemplo_delimitado`). "Radical" aqui tem
  definição operacional fechada, em três passos:
  1. **Normalizar:** minúsculas + remoção de diacríticos (`refaço` → `refaco`), sobre o texto do
     prompt.
  2. **Tokenizar** por não-alfanumérico.
  3. **Casar por PREFIXO de token**, nunca por substring de frase: o token casa se **começa** com um
     dos radicais. Prefixo é o que separa `criar` (casa `cri`) de `discriminar` (não casa) — por
     substring os dois casariam.
- **RF4a.** Radicais (lista fechada): `cri`, `refaz`, `refac`, `redesenh`, `moderniz`, `melhor`,
  `constr`, `monta`, `desenh`.
- **RF4b.** **Exclusões lexicais** (token que casa radical mas NÃO conta como verbo de criação):
  `melhoria`, `melhorias`, `criterio`, `criterios`, `criticar`, `critico`, `criptografia`. Nasce da
  observação do conselho de que `"melhorar a mensagem de erro"` casaria `melhor` — é falso positivo,
  e RF2 não salva porque `mensagem` não é substantivo-gatilho, mas `"melhorar o dashboard de erro"`
  casaria os dois.
- **RF4c.** **O gate é PT-only, e isso é limitação declarada, não omissão.** `"build me a dashboard"`
  ou `"redesign the landing page"` não casam radical nenhum e passam em silêncio. Não se adiciona
  radical EN nesta entrega: a frota escreve em português, e cada radical EN (`build`, `creat`,
  `redesign`) amplia a superfície de falso positivo do único hook do pacote que fala em toda sessão
  — o risco central declarado em §6.2. A medição de uma semana (§5b.6) DEVE contar prompts em inglês
  com substantivo-gatilho, e o gatilho de reabertura é **≥3 prompts EN com substantivo-gatilho na
  janela de uma semana**. O número é baixo de propósito: 3 já mostra hábito, e o custo de reabrir a
  decisão é uma conversa, não um deploy.
- **RF5.** O hook DEVE SEMPRE terminar com código 0, **inclusive quando ele próprio falha**: exceção
  interna é capturada, nada vai para stdout, e o prompt segue intacto. UserPromptSubmit com saída
  não-zero **engole o prompt do usuário** — um falso positivo aqui não é ruído, é perda de mensagem.
- **RF5a.** Como o código de saída é constante por RF5, ele **não é o observável do teste**. O
  observável é o **stdout**: aviso presente = disparou; stdout vazio = silêncio. Os testes de RF2,
  RF3, RF4b e RF4c DEVEM asseverar stdout vazio, e o teste de falha interna (payload malformado,
  JSON truncado, canon ausente) DEVE asseverar stdout vazio **e** código 0 — é o que impede "sempre
  sai 0" de virar uma afirmação não-verificável.
- **RF6.** Escape: `PERCUS_SKIP_DESIGN_GATE=1`.

### R22 — porta hardcoded

- **RF7.** QUANDO um `git commit` leva `vite.config.*`, `next.config.*`, `docker-compose*.yml`,
  `package.json` ou `.env*` **E** o projeto tem `.percus-ports.json` versionado **E** uma linha
  staged casa porta literal **em posição de porta**, O SISTEMA DEVE avisar nomeando `arquivo:linha`.
  Posição de porta *(ilustrativo — o plano fixa e testa a expressão)*: `port:\s*\d{4}`,
  `EXPOSE \d+`, `--port[= ]\d{4}`, `"\d{4}:\d{4}"`, `localhost:\d{4}`. O requisito é **posição**, não
  o número solto: `\d{4}` em qualquer lugar casaria ano, id e hash.
- **RF7a.** SE o literal casado pertencer ao range já alocado do próprio projeto ENTÃO O SISTEMA DEVE
  **avisar mesmo assim**, com mensagem distinta (*"esta é a sua porta, mas escrita à mão"*).
  **Rejeição explícita de uma sugestão do conselho**, que pedia silêncio nesse caso: o literal certo
  é a forma **mais comum** do hardcode que a R22 existe para impedir — é o que acontece quando
  alguém consulta o `.percus-ports.json` e copia o número. Silenciar ali deixaria o gate cego
  justamente no caso majoritário e o transformaria num detector de porta *errada*, que é outra regra.
- **RF8.** ENQUANTO o projeto **não** tiver `.percus-ports.json`, O SISTEMA DEVE ficar em silêncio.
  (Projeto que nunca alocou seria avisado em todo commit — disparo em massa, escape declarado.)
- **RF8a.** SE `.percus-ports.json` existir mas não for parseável ENTÃO O SISTEMA DEVE tratar como
  ausente (silêncio por RF8) e emitir **um** aviso de parse por commit, nunca por linha. Arquivo
  corrompido não pode virar enxurrada.
- **RF9.** SE a linha referenciar `PERCUS_PORT_BASE` ENTÃO O SISTEMA DEVE não avisar por ela. O
  critério é **a substring `PERCUS_PORT_BASE` presente na mesma linha física** — não a resolução da
  variável, não o escopo dela. Deliberadamente frouxo: quem escreveu o nome da variável na linha já
  está usando o mecanismo, e um resolvedor de variável dentro de um hook seria mais frágil que o
  defeito que ele evita.
- **RF10.** O conteúdo inspecionado DEVE ser o **staged** (`git show :arquivo`), não o do disco.
- **RF11.** Escape: `PERCUS_SKIP_PORT_SCAN=1`.

### R13 — trailer `Co-implemented-by: deepseek-v4`

- **RF12.** QUANDO um `git commit` acontece **E** existe run do `deepseek-impl` com `apply=true` mais
  recente que o commit anterior **E** a mensagem não termina com o trailer, O SISTEMA DEVE avisar —
  citando que sem o trailer o router do R11 manda o DeepSeek revisar a própria saída.
- **RF12a.** *"Mais recente que o commit anterior"* DEVE ter critério determinístico, e é este: o
  campo `ts` do run comparado com a **data de committer do `HEAD`** (`git log -1 --format=%cI`),
  ambos convertidos para **UTC** antes de comparar, com granularidade de **segundo**. Conta o run com
  `ts >= HEAD.committerDate`. **Não** se usa mtime de arquivo (muda ao copiar/clonar) nem hash de
  commit (não ordena).
- **RF12a1.** **O `ts` do run DEVE carregar offset de fuso.** Hoje o wrapper grava
  `Get-Date -Format 'yyyyMMdd-HHmmss'` — relógio local **sem offset** — enquanto `%cI` é RFC3339
  **com** offset. Comparar os dois "em UTC" é impossível: falta o dado. Sem este conserto, a
  comparação erra pelo tamanho do fuso (aqui, 4h: todo run das últimas 4h antes de um commit fica
  invisível, ou todo commit das últimas 4h ganha aviso falso). **Vira a terceira dívida do wrapper**,
  ao lado de RF13 e RF14 — e, como elas, tem de estar quitada antes de o hook de R13 existir, senão
  o detector mente com precisão de fuso horário.
- **RF12b.** O empate (`==`, mesmo segundo) conta como *depois* — deliberadamente o lado que avisa.
  Em gate warn-only o custo de um aviso a mais é uma linha; o de um aviso a menos é um commit sem
  trailer, que é exatamente o defeito que RF12 existe para pegar.
- **RF12c.** SE não houver commit anterior (primeiro commit do repositório, `git log -1` falha)
  ENTÃO todo run `apply=true` presente conta. Não é caso raro-e-ignorável: repo novo é onde o
  wrapper mais roda, e `.deepseek/runs/` só existe se alguém rodou.
- **RF13.** O wrapper `scripts/deepseek-impl.{ps1,sh}` DEVE gravar `apply` no registro de
  `.deepseek/runs/*.jsonl`. **Hoje não grava** — o log é escrito antes do branch `-Apply`, com apenas
  `ts, model, task, files, rules, usage, response`. Sem isso o hook avisaria em todo dry-run.
- **RF14.** O wrapper DEVE gravar o log na **raiz do projeto**, não em `(Get-Location)`. Hoje é
  CWD-relativo — rodar de uma subpasta esconde o run do hook (mesma classe do
  `gotcha_review_wrapper_grava_latest_relativo_ao_cwd`).
- **RF15.** Escape: `PERCUS_SKIP_DEEPSEEK_TRAILER=1`.

### R12 — meta-regra (teste, não hook)

- **RF16.** QUANDO a suíte roda, O SISTEMA DEVE reprovar se alguma seção `## R<N>.` de
  `01_REGRAS_INEGOCIAVEIS.md` não tiver `**Gate de verificação:**` e não constar da allowlist de
  dívida declarada.
- **RF16a.** A allowlist DEVE ser uma tabela **declarada dentro do próprio arquivo de teste** (não um
  JSON à parte), com três campos obrigatórios por entrada: `regra` (`R<N>`), `motivo` (por que não
  tem gate hoje) e `dono` (o que a tira dali — hook planejado, tarefa do plano, ou `dívida
  documental`). Entrada com campo vazio reprova. Morar no teste é o ponto: **crescer a allowlist
  exige editar o arquivo de teste**, e essa edição aparece no diff que o R11 revisa. Um JSON de
  dados ao lado seria editado sem que ninguém lesse.
- **RF16b.** O teste DEVE reprovar nos **três** sentidos, não só no primeiro:
  1. regra sem gate escrito **e** fora da allowlist → reprova (a lacuna);
  2. entrada na allowlist cuja regra **já ganhou** `**Gate de verificação:**` → reprova (allowlist
     stale — a entrada tem de sair). É isto que faz a lista encolher sozinha em vez de depender de
     alguém lembrar;
  3. entrada na allowlist para um `R<N>` que não existe no canon → reprova (renumeração — a mesma
     classe de defeito que gerou o CRITICAL de §1).
- **RF17.** O detector DEVE ancorar no **cabeçalho** (`^\*\*Gate de verifica`), nunca em substring —
  ver §1 e a convenção WHAT/HOW no topo desta seção.
- **RF18.** A allowlist DEVE nascer com as **9** regras sem gate escrito, já nos três campos de
  RF16a, e o teste DEVE reprovar se ela **crescer**. O critério é não-crescimento, não um total
  literal. Conteúdo inicial:

  | regra | motivo (por que não tem gate hoje) | dono (o que a tira daqui) |
  |---|---|---|
  | R7 | tem hook verificado por conteúdo; falta só a seção no canon | RF19 — documentar o hook |
  | R9 | idem | RF19 — documentar o hook |
  | R11 | idem | RF19 — documentar o hook |
  | R20 | idem | RF19 — documentar o hook |
  | R10 | sem hook; observável é o prompt | RF1–RF6 — hook `UserPromptSubmit` (tier 1) |
  | R12 | sem gate; o observável é o próprio canon | RF16–RF17 — teste da suíte (tier 1) |
  | R4 | sem hook; observável é caminho + conteúdo escrito | RF23–RF24 — guarda de caminho (tier 2) |
  | R5 | **shape não decidido** — como um hook distingue "irreversível" de rotina | §6.8 — decisão pendente |
  | R6 | **shape não decidido** — observável plausível, mas dispara em repo herdado | §6.8 — decisão pendente |

- **RF18a.** **A aritmética do encolhimento, explícita** (o caminho de 9 a 0, que a versão anterior
  desta spec errava ao dizer "9 → 3"):
  **9** → RF19 documenta R7/R9/R11/R20 → **5** (R4, R5, R6, R10, R12) → R10, R12 e R4 ganham o
  enforcement desta spec → **2** (R5, R6) → §6.8 decide o shape das duas → **0**. Só ao chegar a 0 é
  que RF20 vale: o teste passa a reprovar qualquer regra nova sem gate.
- **RF19.** As 4 regras que têm hook verificado por conteúdo e não têm gate escrito (R7, R9, R11,
  R20) DEVEM ganhar a seção apontando para o hook que já as verifica.
- **RF19a.** Nenhuma regra DEVE ganhar seção de gate com base no número que um hook cita sobre si
  mesmo; o vínculo hook↔regra DEVE ser confirmado comparando **o que o hook bloqueia** com **o corpo
  da regra** — foi o que R5/R6 violaram (§1).
- **RF20.** QUANDO R4, R5, R6, R10 e R12 ganharem enforcement, a allowlist DEVE ir a 0 — e o teste
  passa a reprovar qualquer regra nova sem gate.
- **RF20a.** R5 e R6 entram no escopo do pacote como **descobertas**, não como dívida documental: R5
  (confirmação antes de irreversível) e R6 (banco novo por projeto) precisam de decisão própria de
  shape, ainda não tomada.

### R25 — single-source-of-truth (teste, não hook)

> **Dois observáveis distintos sob o mesmo número de regra.** O conselho apontou que tratá-los como
> um só faz o teste confundir dedupe de **referência** com dedupe de **prosa**. Ficam nomeados
> separadamente daqui em diante: **R25a** (referência efêmera) e **R25b** (bloco duplicado). São
> tiers diferentes, testes diferentes e critérios de pronto diferentes.

**R25a — referência efêmera (tier 1)**

- **RF21.** QUANDO a suíte roda, O SISTEMA DEVE reprovar se houver ref a arquivo real em
  `.claude-home/plans/*.md` fora de `CANON_VERSION.md` e `.archive/`. (Menção ao *padrão* na
  definição da própria R25 não conta.)
- **RF21a.** *"Ref"* DEVE ter as formas enumeradas, senão o detector é ambíguo: conta **(a)** caminho
  nu contendo `.claude-home/plans/`, **(b)** link Markdown cujo alvo contém esse trecho, e **(c)**
  caminho em bloco de código inline (crase). **Não** conta menção ao padrão sem caminho concreto
  (`"planos ficam no .claude-home"`) — é a exceção que a própria R25 precisa para poder se definir.
- **RF21b.** O critério de *"arquivo real"* é a **forma do caminho** (tem segmento de arquivo com
  extensão), não a existência em disco: um plano efêmero já apagado é justamente o caso que a R25
  quer pegar, e checar existência silenciaria o detector exatamente quando ele acerta.

**R25b — bloco de prosa duplicado (tier 2)**

- **RF22.** QUANDO um bloco de prosa **≥200 caracteres após normalização** aparece em 2+ docs **no
  escopo de RF22f** **E** nenhuma das cópias declara o dono **nas 3 linhas imediatamente anteriores
  ao bloco**, O SISTEMA DEVE reprovar. Cópia que **nomeia a fonte** é permitida — é como o operador
  já escreve.
- **RF22a.** **N = 3 linhas, e só para cima.** Vem de medição, não de gosto: as duas declarações de
  dono que já existem no repo (o plano de enforcement e a §1 desta spec) escrevem `**Fonte da tabela
  (R25):** <caminho>` na linha imediatamente anterior ao bloco. N=1 reprovaria uma declaração com
  linha em branco no meio; N=3 cobre título + branco + declaração. Só para cima porque declaração
  *depois* do bloco não ajuda quem lê de cima para baixo — que é o caso que a R25 existe para servir.
- **RF22a1.** **"Declarar o dono" tem sintaxe fechada**, senão o teste não é implementável: uma das
  3 linhas anteriores DEVE conter um **caminho de arquivo terminado em `.md`** (ou um `[[slug]]` de
  verbete) **e** uma palavra de atribuição do conjunto fechado `Fonte` · `Dono` · `Ver` ·
  `Canon` · `vive em` · `mora em`. Caminho sozinho não basta (todo doc cita caminhos); palavra
  sozinha não basta (ela tem de apontar para onde).
- **RF22a2.** **O caminho declarado DEVE existir no repositório.** Declaração apontando para arquivo
  inexistente reprova como se não houvesse declaração — senão a isenção vira a porta dos fundos: bata
  `Fonte: qualquer-coisa.md` acima do bloco e o gate cala.
- **RF22f.** **Escopo — medido, não suposto.** "Docs do canon" DEVE excluir `node_modules/` em
  qualquer profundidade, `.archive/`, `docs/historico/` e `.clinerules/`. Isto não é higiene: a
  medição de 2026-09-12 rodou o detector com exclusão só por **prefixo** e devolveu **736** blocos
  duplicados; com `node_modules/` excluído em qualquer profundidade, **9**. O ruído inteiro eram dois
  `templates/*/node_modules/` espelhados. Um gate de R25 sem esta cláusula nasceria disparando 736
  vezes — o "escape declarado no primeiro dia" que a §1 desta spec usa como critério para rejeitar
  gates.
- **RF22g.** **Baseline medida (2026-09-12), que é a lista de trabalho da implementação:** **9 blocos
  em 5 pares de arquivo** reprovariam hoje —
  `providers/system-prompt-consult.md` ↔ `providers/system-prompt-review.md` (5 blocos);
  `01_REGRAS_INEGOCIAVEIS.md` ↔ `templates/CLAUDE.template.md`;
  `conhecimento/fazer/LEIA-ME.md` ↔ `conhecimento/resolver/LEIA-ME.md`; e duas entre o plano de
  2026-05-03 e as skills `feature-flow` / `close-milestone`. **Nenhum envolve esta spec** — o que
  responde por medição, e não por argumento, o finding `CRITICAL R25` da perna Llama na rodada 2.
- **RF22h.** **A isenção de RF22a1 não tem nenhum caso positivo no repo hoje** (dos 9, zero declaram
  dono). Isenção sem caso vivo é isenção não-testada, e detector com ramo nunca exercitado nasce
  vácuo (`gotcha_detector_de_trava_nasce_frouxo_e_vacuo_ao_mesmo_tempo`). O teste DEVE portanto
  incluir um **caso positivo sintético** — bloco duplicado *com* declaração de dono, que tem de
  passar — além do caso negativo. Sem os dois lados, "9 findings" não distingue detector correto de
  detector que reprova tudo.
- **RF22b0.** **A unidade do bloco é o parágrafo** — o trecho entre duas linhas em branco, recortado
  **antes** da normalização. Não é linha (curta demais, nunca chega a 200), não é seção (uma frase
  mudada esconderia a seção inteira) e não é janela deslizante (O(n²) sobre 1051 docs, e o resultado
  depende de onde a janela começa). Parágrafo é a unidade que o autor de fato copia e cola.
- **RF22b.** **Normalização** (fechada, nesta ordem): colapsar toda sequência de espaço em branco
  — inclusive quebra de linha — em um espaço único; remover marcação Markdown inline (`*`, `_`,
  `` ` ``, `#`, `>`); minúsculas; remover diacríticos. Sem isso "o mesmo bloco" é indefinido: a
  mesma tabela rebrada em outra largura de coluna já não casa byte a byte.
- **RF22c.** **A comparação DEVE ser por igualdade do bloco normalizado, não por similaridade.**
  Rejeição explícita da alternativa fuzzy: heurística de similaridade nasce frouxa e vácua ao mesmo
  tempo (`gotcha_detector_de_trava_nasce_frouxo_e_vacuo_ao_mesmo_tempo`), e uma já mordeu esta frota
  com proteção que dependia do **comprimento** do dado
  (`gotcha_a_protecao_acidental_depende_do_comprimento_do_dado`).
  Igualdade após normalização é grosseira — não pega paráfrase — e essa
  cegueira é **declarada**, não acidental: pega a cópia literal, que é a que de fato aconteceu três
  vezes nesta sessão.
- **RF22d.** **Isenções** (não contam como duplicação): `.archive/`, `docs/historico/`,
  `CANON_VERSION.md`, blocos de código cercados (```` ``` ````) e blocos de citação (`>`) — citar é
  o comportamento que a R25 **quer**.
- **RF22e.** Esta é a única heurística do pacote e a única com risco de vácuo. O critério de entrega
  inclui **prova por mutação**: o teste DEVE reprovar quando uma duplicação conhecida é reintroduzida
  numa cópia do canon (`gotcha_codigo_de_ontem_nao_e_codigo_sem_o_conserto`) — sem isso, "0 findings"
  não distingue canon limpo de detector morto.

### R4 — credencial *(tier 2)*

- **RF23.** QUANDO um Write/Edit mira caminho de credencial (`credentials.json`, `token.json`,
  `.env*`) **E** o conteúdo é placeholder, O SISTEMA DEVE avisar, citando o anti-padrão nomeado na
  R4. Placeholders *(ilustrativo — o plano fixa a lista e a testa)*: `{}`, vazio, `TODO`,
  `PLACEHOLDER`, `changeme`, `your-key-here`, `xxx`.
- **RF23a.** A lista de placeholders DEVE ser **um dado configurável do hook**, não literais
  espalhados no código, e nasce declaradamente **incompleta**: cobre as formas vistas, não todas as
  possíveis. Falso negativo aqui é o modo de falha aceito — o gate compete com o agente escrever
  `sk-fake-1234`, que nenhuma lista pega. É por isso que R4 é tier 2 e warn-only.
- **RF24.** DEVE ficar em silêncio quando o valor escrito é real — o gatilho é o **conteúdo**
  placeholder, não o caminho.
- **RF24a.** **Ponto cego declarado, nos mesmos termos do RF27:** a guarda de caminho só vê
  `Edit`/`Write`. Credencial escrita por **comando** — `echo TODO > .env`, heredoc, `sed -i`,
  `Set-Content` dentro de um `PowerShell` — passa inteira. Não é hipótese: é o shape do observável
  escolhido. **Não se estende R4 à guarda de comando nesta entrega** (dobraria a superfície do único
  item tier 2 que fala em sessão), mas quem ler a medição de R4 tem de saber que ela é um **piso**,
  como a de R24. Declarar o buraco é o que separa cobertura parcial de cobertura imaginária.

### R24 — cadência de deploy *(tier 2, medidor)*

- **RF25.** QUANDO um comando de deploy conhecido é interceptado, O SISTEMA DEVE registrar o evento
  (timestamp + comando + projeto) e **não** opinar sobre cadência.
- **RF25c.** O registro DEVE ter **esquema fechado**, senão "registrar o evento" não é testável:
  uma linha JSONL por evento em `.deepseek/deploy-cadencia/eventos.jsonl` (na **raiz do projeto** —
  a mesma dívida de CWD que RF14 descreve vale aqui), com os campos `ts` (RFC3339 **com offset**,
  pela razão de RF12a1), `comando` (o texto interceptado, truncado em 500 caracteres), `projeto`
  (nome da raiz resolvida) e `padrao` (qual dos 6 de RF25a casou). O teste do medidor DEVE afirmar
  os 4 campos presentes e o `padrao` correto para cada um dos 6 — é o que transforma RF25 de
  intenção em requisito verificável.
- **RF25a.** *"Comando de deploy conhecido"* **não é lista nova**: é exatamente o subconjunto de
  publicação do `$externalPatterns` do `external-action-guard`, verificado no arquivo em 2026-09-12
  — `wrangler (versions|pages|triggers)? (deploy|publish)`, `docker stack deploy`,
  `docker service (create|update|scale|rm)`, `vercel (deploy|--prod)`, `netlify deploy`,
  `kubectl (apply|rollout|delete)`. **Não** entram no medidor os padrões de interação pública
  (`gh pr/issue`, `slack-cli`, `git push`, `mailto:`), os de execução remota (`ssh`, wrapper
  `vps_*`/`ssh_*`) nem os de mutação HTTP (`curl -X POST`): `git push` não é deploy, e contá-lo
  transformaria o medidor de cadência num contador de commits.
- **RF25b.** O medidor **herda** essa lista por leitura da mesma variável, nunca por recópia — um
  padrão de deploy adicionado ao guard passa a ser medido sem edição no medidor. Recopiar aqui seria
  a duplicação que R25b proíbe, na mesma spec que a proíbe.
- **RF26.** O registro DEVE viver dentro do `external-action-guard`, que já intercepta deploy — sem
  entrada nova no registro de hooks. **Premissa verificada, não assumida:** o arquivo foi lido em
  2026-09-12 e os seis padrões de RF25a estão lá, ancorados em posição de comando (`$cmdIni`).
- **RF26a.** SE a premissa de RF26 deixar de valer (o guard for reescrito, os padrões saírem, a
  ancoragem mudar) ENTÃO o medidor **para de medir em silêncio** — e silêncio de medidor é
  indistinguível de "não houve deploy". Por isso um teste da suíte DEVE afirmar que os padrões de
  RF25a seguem presentes no guard, e reprovar quando um sumir. É o par de provas complementares:
  sem ele, `0 deploys medidos` é um número que não distingue calmaria de detector morto.
- **RF26b.** **O campo `projeto` de RF25c herda um buraco conhecido, e isso DEVE estar declarado
  antes de o medidor existir.** A única fonte de "qual projeto" no kit é `Resolve-PercusProjectRoot`
  (`hooks/_helpers.ps1`) — o mesmo helper que §6.4 e o plano de origem declaram quebrado para
  `git -C <dir>` nos 8 hooks de comando, e do qual o `external-action-guard` é um. Pior: hoje ele
  **nem chama o helper**. Sem conserto, o medidor grava o projeto errado **em silêncio** — e a
  cadência de deploy é uma métrica **por projeto**, então projeto errado não degrada o número: ele o
  inverte. Consequência de ordem: **a Proposta F (`git -C`) passa a ser pré-requisito do medidor de
  R24**, não mais uma dívida paralela que "os hooks novos nascem com ela". Ou se conserta o helper
  antes, ou RF25c grava `projeto` como *caminho absoluto da raiz resolvida pelo próprio guard*, com
  o teste afirmando qual dos dois está em uso.
- **RF27.** DEVE declarar o ponto cego herdado: deploy dentro de script cujo nome não denuncia o
  destino (`python deploy_v2.py`, `ssh ... docker service update`) não é interceptado hoje. O próprio
  guard já documenta esse buraco como mantido de propósito — o medidor **não** o fecha, e o número
  que ele produzir é um **piso**, nunca um total. Quem ler a medição tem de ver isso escrito junto.

## 5. Critério de pronto

**5a — desta spec (a decisão).** É o que fecha a Tarefa 3:

1. Cada uma das regras em escopo tem **um veredito de shape** (hook / teste / medidor / nada) com o
   observável nomeado.
2. Todo vínculo hook↔regra citado aqui foi confirmado **por conteúdo**, não pelo número que o hook
   cita (RF19a).
3. O conselho devolve veredito sem CRITICAL pendente.

**5b — da implementação (Tarefa 4, não desta spec).** Registrado aqui só para não se perder; a
entrega desta spec não exige código rodando:

1. Cada hook novo tem **prova comportamental** (Pester rodando o script de verdade em repo
   temporário), não inspeção de código.
2. Paridade `.ps1`/`.sh` com teste que **roda o `.sh` de verdade** — padrão do `spec-analyze-check`.
3. `hooks-manifest.json` atualizado: evento, matcher, forma, assinatura, escape, `alvo`.
4. Suíte inteira verde, **0 falhas** — e o total é **medido no início da Tarefa 4**, nunca citado
   daqui. O `556` que esta linha trazia era falso, e o conserto não é trocá-lo por outro número:
   medindo em 2026-09-12 com poucos minutos de diferença, a mesma árvore deu **551** (perna
   Cross-Claude) e **559** (`Invoke-Pester -SkipRun`, 45 arquivos) — porque outra sessão estava
   editando `tests/context-budget-guard.tests.ps1` no intervalo. Um total de testes é um alvo móvel
   num repo com duas sessões; **`0 falhas` é o critério, o total é contexto**.
5. **R12:** allowlist segue a aritmética de **RF18a** (9 → 5 → 2 → 0), não um salto declarado aqui.
   Este item não redeclara os números — é o defeito que RF18a acabou de consertar.
6. **R10:** uma semana warn-only antes de qualquer conversa sobre promoção, com contagem de disparos
   (quantos avisos, quantos foram bug fix mal classificado).
7. Todo hook novo responde ao escape geral `PERCUS_HOOKS_DISABLED` além do escape próprio.

## 6. Riscos e decisões em aberto

1. **R10 é o primeiro `UserPromptSubmit` do kit** — evento novo e `alvo` novo (`prompt`) no
   manifesto. O próprio manifesto registra que o teste de forma que exigia matcher `Bash|PowerShell`
   de toda guarda de PreToolUse *teria proibido a guarda de caminho por construção*. O mesmo teste
   pode proibir esta por construção; revisar antes, não depois.
2. **Falso positivo do R10 é o risco central do pacote.** `dashboard`, `painel`, `home`, `banner`,
   `CTA` são palavras cotidianas nesta frota. A conjunção (substantivo + radical de verbo − exceções)
   é a mitigação; a medição de uma semana é o juiz.
3. **R13 está bloqueada por TRÊS dívidas do wrapper** (RF13 `apply`, RF14 raiz do projeto e
   RF12a1 offset de fuso — a terceira achada pelo conselho na rodada 2). Implementar o hook antes de
   consertá-las entrega um detector que mente.
4. **`git -C <dir>` não resolve a raiz** em `Resolve-PercusProjectRoot` — dívida comum aos 8 hooks de
   comando; R22 e R13 nascem com ela. A Proposta F do `pre-commit-check` já resolve e nunca foi
   promovida ao helper. **Deixou de ser dívida paralela para R24:** por RF26b, a cadência de deploy é
   uma métrica *por projeto*, e raiz errada não degrada o número — inverte. Para o medidor, a
   Proposta F é **pré-requisito**; para R22 e R13, segue sendo dívida herdada.
5. **Cinco itens no tier 1 é muito?** Mitigação: três são teste de suíte (ruído zero em sessão). Dos
   três que falam em sessão, R22 e R13 disparam raramente por construção. Sobra R10 como única fonte
   de ruído — e é por isso que ele vai **sozinho** na primeira publicação, para que o ruído medido
   seja atribuível.
6. ~~**Em aberto:** o RF22 (bloco duplicado) vale o custo?~~ **Fechado.** Vale, e o contra foi
   resolvido pela forma, não por aposta: RF22c troca similaridade por **igualdade após normalização
   fechada** (RF22b), que não é heurística. O preço é cegueira a paráfrase — declarada em RF22c, com
   prova por mutação em RF22e. A favor seguia valendo: esta sessão pagou três edições em três
   arquivos por uma tabela recopiada.
7. **Em aberto:** publicar R10 sozinho atrasa R22/R13/testes em um ciclo de auto-update (≤10 min +
   novo launch). Aceitável, ou publica tudo e aceita ruído não-atribuível?
8. **Em aberto (fora do escopo desta spec):** R5 e R6 entraram no balde das descobertas por RF20a e
   **seguem sem shape**. Não é esquecimento: cada uma pede decisão própria — R5 (confirmação antes de
   irreversível) esbarra em como um hook distingue "irreversível" de "rotina", e R6 (banco novo por
   projeto) tem observável plausível (nome de banco em migration/compose) mas dispara em repo
   herdado. Enquanto não decidido, as duas ficam na allowlist do R12 com `dono = decisão pendente` —
   o que as torna visíveis na suíte em vez de esquecidas num balde.
9. **Risco novo, descoberto na rodada 2 do conselho: a spec não cabe mais no conselho.** O
   orquestrador truncou 9329 → ~8000 tokens, e a perna Llama tem teto próprio de 5000 (viu ~4794).
   Duas consequências, ambas ruins: findings que pedem o que já está escrito na parte cortada (três
   nesta rodada), e — pior — **um veredito `BLOQUEADA` emitido sobre um documento que a perna não
   leu inteiro**. O veredito de uma perna truncada não é comparável ao de uma perna completa, e hoje
   o log não distingue os dois. Mitigação usada aqui: a perna Cross-Claude recebeu o **caminho do
   arquivo** e leu do disco, sem truncamento. Mitigação de verdade, para o kit: ou o orquestrador
   passa arquivo em vez de texto quando o alvo é um arquivo, ou o log marca cada perna com quanto
   ela viu — senão a spec-analyze fica menos confiável à medida que a spec fica mais completa, que é
   o incentivo exatamente invertido.

## 7. Tratamento dos findings do conselho — rodada de 2026-09-12 17:44

Registro de disposição de **todos** os findings, para que a rodada seguinte não relitigue o que já
foi decidido e para que nada saia em silêncio. Log: `.deepseek/council-log/20260912-174451-analyze.jsonl`.

| Severidade / origem | Finding | Disposição |
|---|---|---|
| CRITICAL (cross-claude) | R5/R6 não têm hook — vínculo por número citado | **Aceito.** §1 corrigido, tabela dona 11/7/7 → 9/7/9, verbete novo, RF19a e RF20a criados |
| HIGH (cross-claude) | §5 exige código rodando, contradiz "não escrever hook" | **Aceito.** §5 rachado em 5a (decisão) / 5b (implementação) |
| HIGH (llama) | RF4 "radical" vago, sem algoritmo | **Aceito.** RF4 ganhou os 3 passos (normalizar / tokenizar / prefixo) + RF4a lista fechada |
| HIGH (llama) | RF5 "sempre sai 0" não é verificável | **Aceito.** RF5 explicita fail-silent; **RF5a** move o observável do teste para o stdout |
| HIGH (llama) | RF12 sem critério determinístico de "mais recente" | **Aceito.** RF12a (`ts` vs `%cI`, granularidade de segundo), RF12b (empate avisa) |
| HIGH (llama) | RF16 allowlist sem formato | **Aceito.** RF16a (3 campos, mora no teste) + RF16b (reprova nos 3 sentidos) |
| HIGH (llama) | RF18 "exatamente 9" é frágil | **Aceito** na correção anterior — critério é não-crescimento |
| MÉDIO (deepseek) | RF1 substantivos não enumerados | **Aceito.** RF1a enumera + exige teste de paridade com a R10; RF1b declara o gatilho não-lexical fora |
| MÉDIO (cross-claude) | Gate PT-only sem FR cobrindo | **Aceito.** RF4c declara a limitação e manda a medição contar prompts EN |
| MÉDIO (ambos) | RF22 sem N e sem normalização | **Aceito.** RF22a fixa N=3 por medição; RF22b fecha a normalização; RF22c rejeita fuzzy |
| MÉDIO (deepseek) | RF25 "deploy conhecido" não enumerado | **Aceito.** RF25a enumera os 6 padrões e diz o que **não** entra; RF25b herda por leitura |
| MÉDIO (deepseek) | RF26 assume o guard sem declarar | **Aceito.** RF26 vira premissa verificada com data; **RF26a** cria o teste que impede o medidor morrer calado |
| MÉDIO (deepseek) | R25 com 2 observáveis sob um rótulo | **Aceito.** Rachado em R25a / R25b |
| MÉDIO (llama) | RF9 critério de detecção indefinido | **Aceito.** RF9 fixa: substring na mesma linha física, e explica por que frouxo |
| MÉDIO (llama) | R4 placeholders podem não cobrir tudo | **Aceito parcialmente.** RF23a torna a lista configurável e **declara a incompletude como modo de falha aceito** — ampliar a lista não fecha o buraco (`sk-fake-1234` não é placeholder) |
| MÉDIO (deepseek) | RF7 sem FR para porta já alocada | **Rejeitado, com motivo.** RF7a avisa **mesmo assim**: o literal certo é a forma mais comum do hardcode que R22 proíbe; silenciar cegaria o gate no caso majoritário |
| MÉDIO (ambos) | Vazamento WHAT→HOW (escapes, regex, `hooks-manifest`, Pester) | **Rejeitado em parte, com motivo.** Convenção declarada no topo da §4: nome de escape e âncora de detecção **são** a decisão; regex literais ficam marcados `(ilustrativo)` e não vinculantes |
| BAIXO (deepseek) | RF8 `.percus-ports.json` malformado | **Aceito.** RF8a: trata como ausente + 1 aviso de parse por commit |
| BAIXO (deepseek) | RF12 primeiro commit do repo | **Aceito.** RF12c |
| BAIXO (deepseek) | RF4 `melhor`/`moderniz` com falso positivo | **Aceito.** RF4b lista de exclusões lexicais |
| BAIXO (deepseek) | §5.6 "uma semana" sem métrica de sucesso | **Em aberto por desenho.** §6.2 diz que a medição *é* o juiz; fixar limiar antes do primeiro número seria inventar o dado que a medição existe para produzir |
| BAIXO (deepseek) | §3 não nomeia quem promove a bloqueio | **Aceito implicitamente:** o operador, como em todo gate do kit. Registrado aqui em vez de virar FR |
| BAIXO (deepseek) | §1 refs a `gotcha_*` são contexto, não requisito | **Rejeitado.** Nesta frota o verbete *é* o argumento: tirá-lo deixa a decisão sem o porquê medido |
| BAIXO (llama) | Glossário gate/hook/guard/observável | **Rejeitado nesta spec.** §2 já define os 4 shapes com evento e exemplo vivo; um glossário paralelo seria a duplicação que R25b proíbe |

### Rodada 2 — 2026-09-12 18:02 (`20260912-180212-analyze.jsonl`)

> ⚠️ **O orquestrador truncou a spec**: 9329 → ~8000 tokens no prompt comum, e a perna Llama tem teto
> próprio de 5000 (viu ~4794). **Nenhuma das duas pernas leu a spec inteira**, e isso é condição de
> leitura dos vereditos abaixo, não desculpa: dois findings do Llama pedem exatamente coisas que já
> estavam escritas na parte cortada. Registrado como risco novo em §6.9.

| Severidade / origem | Finding | Disposição |
|---|---|---|
| CRITICAL (llama) | A spec replica tabelas/descrições de outros verbetes, violando R25 | **Rejeitado — por medição, não por argumento.** Rodei o detector da própria RF22 sobre os 1051 docs do canon: **0** blocos duplicados envolvem esta spec (RF22g). Toda cópia aqui nomeia o dono, que é a isenção que a R25 concede. A perna viu ~4794 tokens de 9329 |
| HIGH (deepseek) | RF22a — "declarar o dono" sem sintaxe fixada, teste não-implementável | **Aceito.** RF22a1 fecha a sintaxe (palavra de atribuição + caminho `.md`), RF22a2 exige que o caminho exista |
| HIGH (deepseek) | RF12a — compara `ts` local sem offset com `%cI` com offset, TZ indefinido | **Aceito, e é o melhor finding da rodada.** RF12a fixa UTC; **RF12a1** promove o offset a **terceira dívida do wrapper**: sem ele o detector erra pelo tamanho do fuso (4h) |
| HIGH (deepseek) | §5b.5 — aritmética "9 → 3 → 0" não fecha | **Aceito.** RF18a escreve o caminho real: 9 → 5 → 2 → 0 |
| HIGH (llama) | RF23 — sem critério de aceite testável | **Aceito parcialmente.** RF5a já estabelece o padrão (observável = stdout, não exit code) e vale para todo hook warn-only do pacote; RF23a declara a incompletude da lista como modo de falha aceito |
| HIGH (llama) | RF25 — sem teste que valide o registro do evento | **Aceito.** RF25c fixa o esquema (4 campos, caminho, JSONL) e exige teste dos 6 padrões |
| HIGH (llama) | RF22 — falta teste de mutação | **Já estava escrito** em RF22e, na parte truncada. Reforçado por RF22h com o caso positivo sintético |
| MÉDIO (deepseek) | RF22 — unidade do bloco indefinida | **Aceito.** RF22b0: a unidade é o parágrafo, recortado antes da normalização, com o porquê de não ser linha/seção/janela |
| MÉDIO (deepseek) | RF18 — allowlist enumerada só por `R<N>`, sem os 3 campos de RF16a | **Aceito.** RF18 traz a tabela inicial completa |
| MÉDIO (deepseek) | RF25 — formato/campos/local do registro não especificados | **Aceito.** RF25c |
| MÉDIO (deepseek) | RF21 — "ref a arquivo real" sem sintaxe | **Aceito.** RF21a enumera as 3 formas; RF21b decide que o critério é a forma do caminho, não a existência em disco |
| MÉDIO (deepseek) | RF4c — "se houver volume" não é trigável | **Aceito.** Fixado em ≥3 prompts EN com substantivo-gatilho por semana |
| MÉDIO (llama) | RF26a — dependência do `external-action-guard` não declarada | **Já estava escrito** em RF26 (premissa verificada com data) e RF26a (teste que impede o medidor morrer calado). Parte truncada |
| MÉDIO (llama) | WHAT→HOW — regex de deploy hard-coded em RF25a | **Rejeitado.** RF25b já manda **herdar por leitura** da variável do guard, justamente para não recopiar; a sugestão ("mover para configuração externa") criaria a terceira cópia |
| MÉDIO (llama) | "warn-only" sem métrica quantitativa | **Rejeitado, mesmo motivo da rodada 1.** §6.2 diz que a medição é o juiz; fixar limiar antes do primeiro número é inventar o dado |
| MÉDIO (llama) | Terminologia guard/gate/hook/observável | **Rejeitado — repetido da rodada 1**, já disposto acima |
| BAIXO (llama) | "tier 2" não definido | **Aceito como registro:** tier 1 = entra na primeira publicação; tier 2 = entra depois, sob medição. Fica aqui em vez de virar FR |
| BAIXO (deepseek) | RF23 — não identifica o nome literal do anti-padrão da R4 | **Aceito como tarefa da implementação**, não da decisão: o texto exato da mensagem sai do corpo da R4 na hora de escrever o hook |
| BAIXO (deepseek) | RF25a — data de verificação hardcoded | **Rejeitado.** A data é o registro de *quando* a premissa foi conferida, e RF26a já cobre a revalidação contínua por teste — que é o mecanismo, não a data |
| **HIGH (cross-claude)** | RF25–RF27 — o campo `projeto` depende de `Resolve-PercusProjectRoot`, o helper que a própria spec declara quebrado; e o `external-action-guard` nem o chama hoje | **Aceito, e reordena o plano.** RF26b: cadência é métrica **por projeto**, então projeto errado não degrada o número — inverte. A Proposta F (`git -C`) deixa de ser dívida paralela e vira **pré-requisito do medidor** |
| MÉDIO (cross-claude) | §2 — `teste do canon` não é valor de `alvo`, e `plano` (usado pelo `pre-plan-exit`) faltava na tabela | **Aceito.** Tabela de §2 refeita contra o `hooks-manifest.json` real: 4 valores de `alvo` + a suíte marcada `— (não é hook)` |
| MÉDIO (cross-claude) | §5b.4 — "556 testes" não bate com a suíte real | **Aceito, com a lição maior.** Não troquei por outro número: duas medições da mesma árvore com minutos de diferença deram 551 e 559 (outra sessão editando testes). O critério vira `0 falhas`; o total é contexto medido na hora |
| LOW (cross-claude) | RF23 — R4 não declara o ponto cego de credencial escrita por comando (`echo TODO > .env`), ao contrário de RF27 | **Aceito.** RF24a declara nos mesmos termos, e diz explicitamente que a medição de R4 é um **piso** |

**Verificado 1:1 pela perna Cross-Claude, sem defeito** (é o que dá valor a ela, e o motivo de ter
recebido o caminho do arquivo em vez do texto truncado): RF1a — os 22 gatilhos batem com a R10 na
mesma ordem; RF12a — o `Get-Date -Format 'yyyyMMdd-HHmmss'` confirmado no wrapper; RF13/RF14 — o log
realmente não grava `apply` e usa `(Get-Location)`; RF18 — a recontagem por `^\*\*Gate de verifica`
devolve exatamente R4, R5, R6, R7, R9, R10, R11, R12, R20; RF25a/RF26 — os 6 padrões de deploy estão
no guard, todos ancorados em `$cmdIni`.

**Trajetória dos vereditos:** rodada 1 `BLOQUEADA (1 critical)` → rodada 2 `AJUSTAR`, com o CRITICAL
da perna Llama refutado **por medição** (RF22g) e não por argumento. O HIGH que sobra (RF26b) é de
**ordem de execução**, não de conteúdo: ele diz que a Proposta F tem de vir antes do medidor de R24 —
e essa reordenação já está escrita.
