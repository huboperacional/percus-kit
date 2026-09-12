# Spec — enforcement das 7 regras comportamentais (R4, R10, R12, R13, R22, R24, R25)

**Tarefa 3** do plano `docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md`.
Entrega desta spec: **decidir quais das 7 merecem hook e qual o shape de cada uma** — não escrever
hook. A lição que governa a decisão: gate que dispara em massa no primeiro dia vira escape
declarado.

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
fazer*. Esse é o eixo que faltava: **toda guarda precisa de um observável, e o kit só tem quatro
shapes de observável** — declarados no campo `alvo` de `hooks-manifest.json`:

| Shape | Evento | O que lê | Exemplo vivo |
|---|---|---|---|
| guarda de comando | PreToolUse Bash\|PowerShell | `tool_input.command` | `pre-commit-check` |
| guarda de caminho | PreToolUse Edit\|Write | `tool_input.file_path` | `knowledge-write-guard` |
| observador de transcript | PostToolUse | `transcript_path` | `context-budget-guard` |
| **teste do canon** | suíte Pester | os arquivos do canon | `gate-conhecimento.tests.ps1` |

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

### R10 — gate de design por gatilho lexical

- **RF1.** QUANDO o prompt do usuário contém um gatilho substantivo da R10 **E** um verbo de
  criação/redesenho **E** nenhum marcador de exceção, O SISTEMA DEVE injetar no contexto um aviso
  nomeando o gatilho casado e a bifurcação (componente isolado → shadcn MCP; tela/fluxo → v0.dev).
- **RF2.** QUANDO o prompt contém o gatilho mas nenhum verbo de criação (`"o dashboard tá com erro
  500"`, `"corrige o painel"`), O SISTEMA DEVE ficar em silêncio.
- **RF3.** QUANDO o prompt contém marcador de exceção da própria regra (bug fix, ajuste de copy,
  troca de cor, `"sem mockup"`), O SISTEMA DEVE ficar em silêncio.
- **RF4.** O casamento de verbo DEVE ser por radical (`cri`, `refaz`/`refaç`, `redesenh`, `moderniz`,
  `melhor`), nunca por lista de conjugações — marcador por conjugação nasce cego
  (`gotcha_trava_de_copy_so_ve_exemplo_delimitado`).
- **RF5.** DEVE SEMPRE sair 0. UserPromptSubmit com saída não-zero **engole o prompt do usuário** —
  um falso positivo aqui não é ruído, é perda de mensagem.
- **RF6.** Escape: `PERCUS_SKIP_DESIGN_GATE=1`.

### R22 — porta hardcoded

- **RF7.** QUANDO um `git commit` leva `vite.config.*`, `next.config.*`, `docker-compose*.yml`,
  `package.json` ou `.env*` **E** o projeto tem `.percus-ports.json` versionado **E** uma linha
  staged casa porta literal em posição de porta (`port:\s*\d{4}`, `EXPOSE \d+`, `--port[= ]\d{4}`,
  `"\d{4}:\d{4}"`, `localhost:\d{4}`), O SISTEMA DEVE avisar nomeando `arquivo:linha`.
- **RF8.** ENQUANTO o projeto **não** tiver `.percus-ports.json`, O SISTEMA DEVE ficar em silêncio.
  (Projeto que nunca alocou seria avisado em todo commit — disparo em massa, escape declarado.)
- **RF9.** SE a linha referenciar `PERCUS_PORT_BASE` ENTÃO O SISTEMA DEVE não avisar por ela.
- **RF10.** O conteúdo inspecionado DEVE ser o **staged** (`git show :arquivo`), não o do disco.
- **RF11.** Escape: `PERCUS_SKIP_PORT_SCAN=1`.

### R13 — trailer `Co-implemented-by: deepseek-v4`

- **RF12.** QUANDO um `git commit` acontece **E** existe run do `deepseek-impl` com `apply=true` mais
  recente que o commit anterior **E** a mensagem não termina com o trailer, O SISTEMA DEVE avisar —
  citando que sem o trailer o router do R11 manda o DeepSeek revisar a própria saída.
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
- **RF17.** O detector DEVE ancorar no **cabeçalho** (`^\*\*Gate de verifica`), nunca em substring —
  ver §1.
- **RF18.** A allowlist DEVE nascer com a lista **enumerada** das regras sem gate escrito — R4, R5,
  R6, R7, R9, R10, R11, R12, R20 — e o teste DEVE reprovar se a allowlist **crescer**. O critério é
  não-crescimento, não um total literal.
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

- **RF21.** QUANDO a suíte roda, O SISTEMA DEVE reprovar se houver ref a arquivo real em
  `.claude-home/plans/*.md` fora de `CANON_VERSION.md` e `.archive/`. (Menção ao *padrão* na
  definição da própria R25 não conta.)
- **RF22.** *(tier 2)* QUANDO um bloco de prosa ≥200 caracteres aparece normalizado em 2+ docs do
  canon **E** nenhuma das cópias declara o dono num raio de N linhas, O SISTEMA DEVE reprovar. Cópia
  que **nomeia a fonte** é permitida — é como o operador já escreve.

### R4 — credencial *(tier 2)*

- **RF23.** QUANDO um Write/Edit mira caminho de credencial (`credentials.json`, `token.json`,
  `.env*`) **E** o conteúdo é placeholder (`{}`, vazio, `TODO`, `PLACEHOLDER`, `changeme`,
  `your-key-here`, `xxx`), O SISTEMA DEVE avisar, citando o anti-padrão nomeado na R4.
- **RF24.** DEVE ficar em silêncio quando o valor escrito é real — o gatilho é o **conteúdo**
  placeholder, não o caminho.

### R24 — cadência de deploy *(tier 2, medidor)*

- **RF25.** QUANDO um comando de deploy conhecido é interceptado, O SISTEMA DEVE registrar o evento
  (timestamp + comando + projeto) e **não** opinar sobre cadência.
- **RF26.** O registro DEVE viver dentro do `external-action-guard`, que já intercepta deploy — sem
  entrada nova no registro de hooks.
- **RF27.** DEVE declarar o ponto cego herdado: deploy dentro de script cujo nome não denuncia o
  destino (`python deploy_v2.py`, `ssh ... docker service update`) não é interceptado hoje.

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
4. Suíte inteira verde (556 + os novos), 0 falhas.
5. **R12:** allowlist 9 → 3 no mesmo commit da documentação; → 0 ao fim da spec.
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
3. **R13 está bloqueada por duas dívidas do wrapper** (RF13, RF14). Implementar o hook antes de
   consertá-las entrega um detector que mente.
4. **`git -C <dir>` não resolve a raiz** em `Resolve-PercusProjectRoot` — dívida comum aos 8 hooks de
   comando; R22 e R13 nascem com ela. A Proposta F do `pre-commit-check` já resolve e nunca foi
   promovida ao helper.
5. **Cinco itens no tier 1 é muito?** Mitigação: três são teste de suíte (ruído zero em sessão). Dos
   três que falam em sessão, R22 e R13 disparam raramente por construção. Sobra R10 como única fonte
   de ruído — e é por isso que ele vai **sozinho** na primeira publicação, para que o ruído medido
   seja atribuível.
6. **Em aberto:** o RF22 (bloco duplicado) vale o custo? A favor: esta sessão pagou três edições em
   três arquivos por uma tabela recopiada. Contra: é o único item do pacote com heurística de
   similaridade, e heurística de similaridade nasce frouxa e vácua junto
   (`gotcha_detector_de_trava_nasce_frouxo_e_vacuo_ao_mesmo_tempo`).
7. **Em aberto:** publicar R10 sozinho atrasa R22/R13/testes em um ciclo de auto-update (≤10 min +
   novo launch). Aceitável, ou publica tudo e aceita ruído não-atribuível?
