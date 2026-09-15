# Spec — R11 sem ponto único de falha

_Feature: r11-sem-ponto-unico · Criada: 2026-09-14 · Status: ANALYZED · Trilho G (R9: scripts de review + hooks)_

> **O QUÊ e o PORQUÊ — não o COMO.** Por ser ferramenta, o comportamento observável inclui
> **exit codes, arquivos gravados e mensagens** — isso É o contrato e está especificado aqui.
> Onde nomes de arquivo/variável aparecem, são parte da interface, não sugestão de implementação.
> `Status: COMPLETO` num FR = requisito **fechado** (sem NEEDS-CLARIFICATION), **não** implementado.

**Por quê (medido 2026-09-14).** O gate R11 depende de uma única chamada à API DeepSeek, sem
timeout nem retry (não existe retry em lugar nenhum do kit). Numa tarde: 3 falhas + 1 travamento de
4 min; uma onda de correções pronta ficou BLOQUEADA ~65 min. Quando a API responde 2xx sem
`choices`, o `.ps1` morre em "Cannot index into a null array" e descarta o corpo (verbete
`conhecimento/resolver/deepseek-review-2xx-sem-choices-nao-grava-review.md`). O wrapper grava um
placeholder e manda despachar Cross-Claude, mas **não há jeito suportado de registrar** a review do
subagente — o controlador calculou o hash à mão e escreveu `d-<hash>.jsonl` sozinho. E o hook
**nunca lê o conteúdo** do marcador: placeholder ou arquivo vazio liberam o commit igual a review real.

---

## 1. Cenários de usuário (priorizados)

- **US1 (P1) — API lenta/instável, retry resolve**
  - **Given** a 1ª chamada à DeepSeek estoura o timeout (ou volta 429/5xx/2xx sem `choices`)
    **When** o agente roda o review **Then** o cliente avisa no stderr que vai tentar de novo, espera o
    backoff, faz exatamente 1 nova tentativa, que responde normal; `latest.jsonl` e `d-<hash>.jsonl`
    são gravados como hoje, exit 0, e o commit libera pelo hash.
- **US2 (P1) — API fora após o retry → Cross-Claude registrado → commit libera por hash**
  - **Given** as 2 tentativas falham por indisponibilidade **When** o wrapper recebe exit 4 **Then**
    grava o placeholder e emite `__PERCUS_NEEDS_CROSS_CLAUDE__` com a instrução de rodar o comando de
    registro; **When** o agente despacha o subagente Sonnet e registra os findings dele com canal
    `cross-claude` **Then** surgem `d-<hash>.jsonl` e `latest.jsonl` com `canal:"cross-claude"` e
    findings não vazios, 1 linha de telemetria, e o commit libera pelo hash — mesmo após os 5 min.
- **US3 (P1) — 2xx sem `choices` fica visível**
  - **Given** a API responde 2xx sem `choices` nas 2 tentativas **When** o review roda **Then** o stderr
    mostra os primeiros 2 000 caracteres do corpo bruto, o mesmo trecho fica em
    `.deepseek/reviews/ultimo-erro.txt`, nenhum marcador é escrito e o exit é 4.
- **US4 (P1) — marcador vazio ou placeholder não libera**
  - **Given** `d-<hash do diff atual>.jsonl` ≤24 h existe mas é placeholder, tem `findings`
    vazio/só espaço, está vazio ou não é JSON **When** o agente tenta commitar **Then** o hook NÃO
    libera por ele; cai no caminho de `latest.jsonl` e, sem marcador válido, bloqueia dizendo qual
    arquivo foi recusado e por quê.
- **US5 (P2) — placeholder `latest.jsonl` recente ainda libera, com aviso**
  - **Given** `latest.jsonl` é placeholder explícito (`deferred:true` + `reason` não vazio) com ≤5 min e
    não há `d-<hash>` que libere **When** o agente commita **Then** o commit libera, o stderr avisa que
    é commit sem review real, e 1 linha é acrescentada a `.deepseek/reviews/deferidos.log`.

---

## 2. Requisitos funcionais (FR)

Todo FR vale para **`.ps1` e `.sh`** (paridade de comportamento, mensagens e exit codes).

### Cliente DeepSeek (`deepseek-review.ps1` / `.sh`)
- **FR-001** — Cada chamada à API DEVE ter timeout; padrão 180 s. Precedência: parâmetro
  (`-TimeoutSec`/`--timeout`) > variável `PERCUS_DEEPSEEK_TIMEOUT_S` > padrão. _Status: COMPLETO_
- **FR-002** — O cliente DEVE fazer **exatamente 1** nova tentativa, após backoff (padrão 5 s;
  precedência `-BackoffSec`/`--backoff` > `PERCUS_DEEPSEEK_BACKOFF_S` > padrão), SOMENTE quando a 1ª
  falhar por: timeout/erro de rede (inclusive conexão TCP que não completa), HTTP 429, HTTP 5xx, ou
  HTTP 2xx com corpo vazio ou sem `choices`. Antes de esperar, DEVE imprimir no stderr a causa e que
  vai tentar de novo. _Status: COMPLETO_
- **FR-003** — Todo HTTP 4xx exceto 429 NÃO DEVE gerar nova tentativa: 1 chamada só, exit 1, nenhum
  marcador. _Status: COMPLETO_
- **FR-004** — Sempre que o corpo recebido não tiver `choices`, o cliente DEVE mostrar no stderr o
  status HTTP e os **primeiros 2 000 caracteres** do corpo bruto, e gravar o mesmo em
  `.deepseek/reviews/ultimo-erro.txt` (sobrescrito, com timestamp). NUNCA inclui cabeçalhos; toda
  ocorrência da chave no corpo vira `***` antes de tela e arquivo. _Status: COMPLETO_
- **FR-005** — Exit codes: 0 sucesso/diff vazio; 1 erro de ambiente ou chamada não recuperável (chave
  ausente, dependência ausente, 4xx do FR-003); 2 argumento/git inválido; 3 resposta **com
  `choices`** porém inutilizável (content vazio ou `finish_reason` ≠ `stop`, incluindo `length`);
  **4 provedor indisponível após retry** (a 2ª tentativa também falhou por uma causa do FR-002,
  inclusive 2xx sem `choices`/corpo vazio). Nos exits 1, 3 e 4 nenhum marcador é gravado. _Status: COMPLETO_
- **FR-006** — Com resposta boa, gravação de `latest.jsonl`, `d-<hash>.jsonl`, telemetria e poda
  continuam como hoje, e o `.sh` DEVE passar a gravar `model` e `usage` no marcador (paridade com o
  `.ps1`). _Status: COMPLETO_

### Wrapper (`percus-review-auto.ps1` / `.sh`)
- **FR-007** — Com exit 4, o `reason` do placeholder DEVE conter "provedor indisponível após retry";
  para outro exit não-zero DEVE citar o código. Placeholder + marcador continuam nos dois casos.
  _Status: COMPLETO_
- **FR-008** — O marcador `__PERCUS_NEEDS_CROSS_CLAUDE__` é emitido em 4 pontos: rota `deepseek`
  (DeepSeek falhou), rota `dual` (sempre; texto de falha quando DeepSeek falhou), rota `council` e rota
  `cross-claude`. Em TODOS, o texto DEVE conter o nome do comando de registro (`registrar-review`), o
  caminho absoluto dele e `-Canal cross-claude` (ps1) / `--canal cross-claude` (sh). _Status: COMPLETO_

### Comando de registro de review (`registrar-review.ps1` / `.sh`, novo)
- **FR-009** — DEVE receber um arquivo de findings e o nome do canal (ex.: `cross-claude`), e
  opcionalmente o identificador do modelo; roda no repo alvo (ou recebe o diretório). _Status: COMPLETO_
- **FR-010** — DEVE recusar com exit 2, nada gravado e motivo no stderr: arquivo ausente; conteúdo
  vazio ou só whitespace; arquivo **inteiro** que é um objeto JSON com `deferred:true` ou
  `placeholder:true`; texto livre contendo `__PERCUS_NEEDS_CROSS_CLAUDE__`; canal vazio; repositório
  sem commit (HEAD inexistente → mensagem "repositório sem commit"); `git diff HEAD` vazio; findings
  acima de 256 KB. Texto livre que só menciona `deferred` NÃO é recusado. _Status: COMPLETO_
- **FR-011** — DEVE calcular o hash **igual ao hook**: SHA-256 dos bytes escritos por
  `git -C <raiz do repo> diff HEAD --output=<tmp>`, 12 primeiros hex minúsculos. Hash vazio → exit 1,
  nada gravado. _Status: COMPLETO_
  - _Emenda 2026-09-14 (controlador):_ arquivo de diff vazio = **sem hash** (o hash do conteúdo vazio, `e3b0c44298fc`, conta como hash vazio): `d-<hash>.jsonl` NUNCA é gravado — vale para este comando e para o cliente DeepSeek (`deepseek-review.ps1`/`.sh`).
- **FR-012** — DEVE gravar **primeiro** `d-<hash>.jsonl` e **depois** `latest.jsonl`, cada um com
  `timestamp`, `base` (""), `diff_lines`, `model` (informado ou null), `usage` (null), `findings` e
  `canal`. Se qualquer gravação falhar, remove o que gravou nesta chamada e sai exit 3. Observável:
  nunca existe marcador parcial nem conteúdo intercalado entre processos concorrentes. Sucesso: exit 0
  e uma linha no stdout `hash=<h> latest=<caminho> d=<caminho>`. _Status: COMPLETO_
- **FR-013** — DEVE acrescentar 1 linha a `.deepseek/spend/<YYYY-MM>.jsonl` (mês UTC) com
  `timestamp`, `tool:"registrar-review"`, `provider` = canal, `model`, `usage:null`, `diff_lines`. Falha
  na telemetria NÃO muda o exit. _Status: COMPLETO_
- **FR-014** — O `.sh` pode exigir `jq` (como o cliente `.sh` já exige); sem ele sai exit 1 com
  mensagem explícita — nunca grava JSON inválido. _Status: COMPLETO_

### Hook (`pre-commit-check.ps1` / `.sh` e `git-hooks/pre-commit.template.sh`)
- **FR-015** — Leitura limitada: o hook lê **no máximo um arquivo por caminho de decisão** — o
  `d-<hash>` e, só se ele não liberar, o `latest.jsonl` (até 2 leituras, cada uma com teto 256 KB, BOM
  UTF-8 tolerado). Nunca enumera diretório no caminho por hash; o fallback atual quando `latest.jsonl`
  não existe (pega o `*.jsonl` mais recente do diretório) continua como hoje. Classificação do arquivo
  lido: **review** = raiz é objeto JSON e `findings` é string não vazia após trim; **placeholder** =
  raiz objeto com `deferred:true` e `reason` string não vazia; **inválido** = vazio, não-JSON, raiz
  não-objeto, `findings` não-string, acima do teto, ou nenhum dos dois. _Status: COMPLETO_
- **FR-016** — `d-<hash>.jsonl` com mais de 24 h é ignorado **sem ser lido**. Com ≤24 h, só libera se
  for **review**; placeholder ou inválido NÃO liberam e o hook segue para `latest.jsonl`. _Status: COMPLETO_
  - _Emenda 2026-09-14 (controlador):_ hash do diff vazio (`e3b0c44298fc`) = **sem hash**: o hook pula o caminho por hash (não procura `d-e3b0c44298fc.jsonl`) e decide direto por `latest.jsonl`; coberto por teste nas 3 camadas.
- **FR-017** — `latest.jsonl` (ou o fallback) com mais de 5 min bloqueia como hoje, **sem ler
  conteúdo**. Com ≤5 min: **review** libera em silêncio; **placeholder** libera com aviso no stderr e
  1 linha em `.deepseek/reviews/deferidos.log` com `timestamp`, `camada` (`pretooluse` | `git-hook`),
  raiz do repo, `decision` (valor gravado pelo wrapper: `deepseek` | `dual` | `council` |
  `cross-claude`, ou `desconhecida`) e `reason`; **inválido** bloqueia (exit 2 no PreToolUse, exit 1 no
  hook git) citando arquivo e motivo. _Status: COMPLETO_
- **FR-018** — O hook git nativo (`/bin/sh`) NÃO DEVE depender de `jq`; a classificação do FR-015
  DEVE dar o mesmo resultado das outras camadas em toda a matriz de testes. _Status: COMPLETO_
- **FR-019** — Fail-graceful: erro interno do hook → exit 0 com uma linha no stderr começando por
  `[percus:hook pre-commit] WARN:`. Falha ao gravar `deferidos.log` não bloqueia nem muda a decisão.
  _Status: COMPLETO_

### Documentação (mesmo merge)
- **FR-020** — `01_REGRAS_INEGOCIAVEIS.md`, R11 "Exceções declaráveis": a linha "DeepSeek API down"
  DEVE descrever o retry automático + review Cross-Claude registrada pelo comando do FR-009 (placeholder
  libera só por 5 min, com log). O verbete citado vira **resolvido** apontando para esta feature.
  `CANON_VERSION.md` ganha entrada "Pendente de versão". _Status: COMPLETO_

---

## 3. Critérios de sucesso (SC)

- **SC-001** — Matriz do hook (3 camadas × {review, placeholder, `findings` vazio, só espaço,
  não-string, raiz array, arquivo vazio, não-JSON, >256 KB, com BOM}): **zero** liberações por
  `d-<hash>` que não seja review e **zero** por `latest.jsonl` inválido.
- **SC-002** — Os 5 testes de `plugin/percus-review/tests/pre-commit-hash-validity.tests.ps1` passam
  sem mudar asserção nem fixture.
- **SC-003** — Servidor local simulando 2xx sem `choices` com corpo de 5 KB contendo a chave: stderr e
  `ultimo-erro.txt` têm exatamente os primeiros 2 000 caracteres, chave como `***`; exit 4; nenhum
  marcador novo.
- **SC-004** — Servidor que falha a 1ª e responde a 2ª: exit 0 e marcador gravado; tempo extra ≤
  backoff + timeout configurados (+1 s de folga). 401 e 404 simulados: exatamente 1 requisição, exit 1.
- **SC-005** — Servidor que nunca responde, timeout 2 s e backoff 1 s: o tempo do cliente ACIMA de
  uma chamada normal medida no mesmo teste (a partida do processo `pwsh`/`bash` sozinha já consome
  0,5–1,5 s e torna o absoluto instável) fica ≤ 6 s, com exit 4 (hoje trava indefinidamente).
- **SC-006** — Fluxo US2 ponta a ponta em repo temporário: registro + commit liberado pelo hash com
  `latest.jsonl` envelhecido para 60 min; hash idêntico entre `.ps1` e `.sh` para diff com acentos.
- **SC-007** — Latência do hook (não há benchmark hoje): mediana de 20 execuções do
  `pre-commit-check.ps1` sobre o fixture `New-RepoComDiff` de
  `plugin/percus-review/tests/pre-commit-hash-validity.tests.ps1`, versão antiga e nova medidas no
  mesmo run e na mesma máquina; aceitável mediana(novo) − mediana(antigo) ≤ 20 ms.
- **SC-008** — Suíte inteira verde, incluindo `ps51-compat` e checagem ASCII/LF dos `.sh`.

---

## 4. Entidades-chave

- **Marcador de review** — `timestamp`, `base`, `diff_lines`, `model`, `usage`, `findings`, `canal`
  (opcional; ausente = `deepseek`). Vive em `latest.jsonl` e `d-<hash>.jsonl`.
- **Placeholder deferido** — `deferred:true`, `reason`, `decision`, `timestamp`, `placeholder:true`,
  `note`. Só em `latest.jsonl`; nunca libera por hash.
- **Registro de deferimento** — linha em `deferidos.log` por camada que liberou por placeholder.
- **Último erro do provedor** — `ultimo-erro.txt`: timestamp, status HTTP, 2 000 caracteres do corpo.
- **Linha de telemetria** — mesma forma da atual em `.deepseek/spend/<YYYY-MM>.jsonl`.

---

## 5. Edge cases

- Marcador com BOM UTF-8 (o `.ps1` no PS 5.1 grava com BOM) → classificado normalmente (FR-015).
- Marcador >256 KB → inválido, bloqueia com "acima do teto"; o registro recusa na entrada (FR-010/015).
- `findings` só whitespace, não-string, ou raiz JSON não-objeto → inválido / recusado (FR-010/015).
- Relógio adiantado/atrasado → irrelevante para o conteúdo; só as janelas 24 h/5 min usam mtime,
  como hoje (FR-016/017).
- Duas sessões gravando marcadores ao mesmo tempo → nunca conteúdo parcial/intercalado; o último
  `latest.jsonl` vence; `d-<hash>` de diffs diferentes são arquivos diferentes (FR-012). Placeholder de
  outra sessão liberando meu commit em 5 min continua possível, mas avisado e logado (FR-017).
- 1ª tentativa morre no connect TCP → conta como erro de rede, faz o retry (FR-002); duração máxima
  = 2 × timeout + backoff.
- Retry que recebe 401 depois de um 5xx → para ali, exit 1 (FR-003/005).
- Corpo com a chave ecoada → `***` antes de tela e arquivo (FR-004).
- `.sh` sem `jq`: cliente e registro saem exit 1 com mensagem (FR-014); `pre-commit-check.sh` já
  depende de `jq` para ler o comando e sem ele libera (exit 0, comportamento atual, mantido); o hook
  git não usa `jq` (FR-018).
- PreToolUse e hook git liberando pelo mesmo placeholder → 2 linhas em `deferidos.log`, uma por
  `camada`. **Intencional**: não há correlação por commit (FR-017).
- Registro chamado de subdiretório → hash calculado na raiz do repo (FR-011).
- Findings do subagente citando `"deferred": true` num trecho de código → aceitos; só o arquivo que é
  inteiro um objeto placeholder é recusado (FR-010).
- Repositório sem commit: o registro recusa (exit 2, FR-010). O hook mantém o comportamento atual:
  `git diff HEAD` falha, a dispensa por extensão não se aplica, o arquivo temporário do diff fica vazio
  e o hash calculado é o do arquivo vazio (`e3b0c44298fc`); como hash vazio é **sem hash** (emenda
  FR-016), o hook nem procura `d-e3b0c44298fc.jsonl` — decide direto por `latest.jsonl` ≤5 min
  (FR-017). No hook git, `git diff --cached --quiet` roda contra a árvore vazia e segue o mesmo caminho.

---

## 6. Assumptions & Constraints

- **Assumptions:** outage da DeepSeek é intermitente (minutos); 1 retry cobre o caso comum sem dobrar
  custo. Findings reais cabem com folga em 256 KB. O agente segue o texto do marcador
  `__PERCUS_NEEDS_CROSS_CLAUDE__`.
- **Constraints:** `.ps1` roda em Windows PowerShell 5.1 (sem `??`, sem ternário, um child por
  `Join-Path`); `.ps1` editado mantém BOM se já tinha; `.sh` ASCII + LF. Hook continua O(1) (FR-015).
- **Fora de escopo:** Gemini/agy (piloto 2026-09-14: Gemini 3.1 Pro 0/3, Sonnet 4.6 via agy 1.5/3 —
  ambos abaixo de ≥2/3); teto/fatiamento de diff; fact-check; council orchestrator; circuit breaker;
  mais de 1 retry; bump de versão (convenção de bump no merge registrada em `CANON_VERSION.md`).
- **Dependências:** `deepseek-review.{ps1,sh}`, `percus-review-auto.{ps1,sh}`,
  `pre-commit-check.{ps1,sh}`, `git-hooks/pre-commit.template.sh` (projetos com o hook git instalado
  precisam reinstalar para ganhar FR-015..018), testes de hash-validity e ps51-compat.

---

## 7. Clarifications

- Nenhum `NEEDS-CLARIFICATION` aberto: as decisões de 2026-09-14 fecham timeout, retry, exit 4,
  comando de registro, classificação do marcador e escopo.

### Sessão de clarificação 2026-09-14
- _(vazio)_

---

## 8. Resultado do spec-analyze

Logs: `.deepseek/council-log/20260914-201321-analyze.jsonl` (deepseek + groq-llama) e
`.deepseek/council-log/20260914-201539-analyze.jsonl` (cross-claude).

| Provider | Veredito | HIGH procedentes | HIGH recusados |
|---|---|---|---|
| deepseek (v4-flash) | AJUSTAR (5 high) | 5 — exit 3×4, 4xx sem retry, leitura por caminho, `d-<hash>` >24 h, `latest` >5 min | 0 |
| groq-llama (gpt-oss-120b) | AJUSTAR (1 high) | 0 | 1 — "vários `d-<hash>` válidos" |
| cross-claude (sonnet-5) | AJUSTAR (1 high) | 0 | 1 — "Status COMPLETO engana" |

**Recusados e motivo:**
- "Vários `d-<hash>` válidos" (SC-001) — não ocorre: o hash é do diff atual e só um arquivo casa.
- "Status COMPLETO engana" — semântica do template; resolvida pela nota no cabeçalho.
- Circuit breaker em `02_INFRA` — fora de escopo; retry único + registro Cross-Claude é a decisão.
- "Vazamento WHAT→HOW" (nomes de arquivo, exit, hash, `jq`) — em tooling é o contrato observável.
- Correlacionar as 2 linhas do `deferidos.log` por commit — intencional, uma por camada (§5).
- Demais itens LOW de redação.

**VEREDITO CONSOLIDADO: AJUSTAR → ajustado nesta revisão** (18 itens procedentes aplicados).

**Decisão do controlador no planejamento (2026-09-14):** hash do diff vazio (`e3b0c44298fc`) = sem hash — nem registro/cliente gravam `d-e3b0c44298fc.jsonl` (FR-011) nem o hook o procura (FR-016). Evidência: existe hoje um `d-e3b0c44298fc.jsonl` real em outro worktree; ele liberaria por 24 h qualquer diff de repositório sem commit.
