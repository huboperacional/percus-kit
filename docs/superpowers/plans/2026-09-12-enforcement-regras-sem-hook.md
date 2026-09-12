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
   (`specs/2026-09-12-enforcement-7-regras-comportamentais.md`): decide a **forma** de cada uma.
4. **Consolidação da cadeia de hooks** — spec escrita
   (`specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md`). **Virou pré-requisito da 3** por
   medição, não por preferência. ← PRÓXIMO (implementar)
5. **Pacote B** — ajustar o spec pelos findings do conselho e implementar `plano-sync`.

## ESTADO DA EXECUÇÃO

### ✅ Feito (3 versões, 5 commits locais, nenhum empurrado ainda)

- **6.45.0** `context-budget-guard` — PostToolUse em todas as tools, mede o contexto vivo pela cauda
  do transcript. Nasceu de uma sessão que foi a 610k tokens com "checkpoint" dito 11 vezes.
  **Publicado** (o cache já tem 6.45.0).
- **6.46.0** conselho — fallback pelo resultado (não pela presença da chave), flag
  `PERCUS_CROSS_CLAUDE=subagent`, `cross_claude_pending` honesto, resumo do F3 com
  `nao-verificado=N`. **Não publicado.**
- **6.47.0** `spec-analyze-check` — o gate `[S]` mecânico. **Não publicado.**
- **Spec do Pacote B** commitada (`e18abf8`), com veredito `AJUSTAR` do conselho — 10 findings a
  tratar antes de implementar.

### ✅ Tarefa 3 fechada (2026-09-12)

Spec: `docs/superpowers/specs/2026-09-12-enforcement-7-regras-comportamentais.md`.
Triagem por **shape do observável** (guarda de comando / guarda de caminho / observador de transcript
/ teste do canon). Resultados que mudam o plano:

- **R12 e R25 não viram hook** — o observável delas é o canon, e o canon tem suíte: viram teste.
- **R24 não vira gate** — a exceção legítima da própria regra é o caso mais comum; vira medidor.
- **R13 racha**: só o trailer é mecânico, e está bloqueado por duas dívidas do wrapper.
- **CRITICAL do conselho:** R5 e R6 **não tinham hook** — `types-check` e `migration-check` citam
  numeração stale. A auditoria inteira foi feita por varredor de número citado (mede rótulo, não
  gate). Tabela dona corrigida 11/7/7 → **9/7/9**; verbete novo
  `conhecimento/resolver/auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe.md`.

### ⏳ Próximo passo imediato

**Implementar a consolidação da cadeia de hooks**, seguindo
`specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md`. A ordem de entrega está na spec: (1)
estreitar o matcher do `PostToolUse` — grátis, isolada; (2) dispatcher `PreToolUse` + as 3 defesas +
paridade `.sh`; (3) dispatcher `PostToolUse` com porta por timestamp. Só então os checks das 7.

**Por que isto entrou na frente.** A tarefa 3 ia adicionar 4 hooks; medi a cadeia antes e ela já
custa **3 357 ms em todo comando Bash** (8 hooks × ~420 ms de startup do PowerShell, mesmo em
no-op), mais **477 ms em toda tool call** no `context-budget-guard`. Verbete:
`conhecimento/resolver/cadeia-de-hooks-cobra-420ms-por-hook-mesmo-em-no-op.md`. Conselho 3/3 na
abordagem do dispatcher. Com ele, **3 357 ms → 61 ms** e o custo marginal de um check novo vira o
próprio tempo de execução — que é o que devolve a decisão das 7 para o mérito.

**A decisão de *quais merecem* já está tomada**, em
`specs/2026-09-12-enforcement-7-regras-comportamentais.md` (triagem por shape do observável: R12 e
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
- **`spec-analyze-check` é warn-only** por desenho. Promover a bloqueio é decisão separada, depois
  de medir quanto a frota reclama.
- **`pre-commit-check` casa `git`…`commit` como texto** — barrou dois comandos de *teste* nesta
  sessão. Guarda conservadora funcionando; o falso positivo é o lado seguro.
- **A spec das comportamentais está desatualizada na contagem.** O arquivo se chama
  `...-enforcement-7-regras-comportamentais.md` e trata 7; a auditoria foi corrigida no mesmo dia
  para **9/7/9** — R5 e R6 não tinham gate, os hooks que citam `(R5)`/`(R6)` cobram tipos e
  migration (renumeração antiga). Falta acrescentar R5 e R6 à triagem daquela spec e renomear o
  arquivo. Dono do número: `conhecimento/resolver/regra-declarada-automatica-sem-hook-e-decoracao.md`.
- **Pacote B**: `AJUSTAR` com 10 findings (6 DeepSeek, 2 Llama, 2 Cross-Claude), incluindo uma
  afirmação minha no spec que citava `153 linhas` como prova de que um teto de `150` funciona.

### Publicação

`PERCUS_CANON_DIR` aponta para este repo, então **scripts** (`medir-baseline-boot`, `plano-sync`
futuro) valem no instante em que são salvos. **Hooks e skills** só chegam aos projetos por
publicação: push → auto-update (≤10 min) → novo launch. Cache atual: **6.45.0**; kit em **6.47.0**.
Cinco commits aguardam push, pendente de autorização do operador (R20).
