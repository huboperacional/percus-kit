# Migração para casa única: `percus-kit` + fim da dependência de republish

**Data:** 2026-07-29
**Estado:** design aprovado pelo operador (topologia + escopo da fase 1)
**Origem:** o operador cobrou "não deveríamos estar usando nada no `_Novo_Projeto` agora que temos
o V2 — você já deveria ter migrado isso", e pediu que o processo fosse fechado de forma definitiva.

---

## 1. Problema

Existem **duas cópias divergentes do canon V2** e o vocabulário "V1 vs V2" descreve mal o que é cada
coisa, então todo trabalho continua drenando pro lugar errado — inclusive o desta própria sessão.

**O que a exploração mediu (2026-07-29):**

| Fato | Evidência |
|---|---|
| O V2 **já mora dentro do kit** desde 2026-07-20 | `CANON_VERSION.md`, changelog v6.30.0: "Canon V2 dobrado pra dentro do kit (`v2/`). O greenfield `_Novo_Projeto_V2` muda de casa… **A pasta avulsa vira arquivo**" |
| A pasta avulsa **não virou arquivo** e continua recebendo commits | 3 commits desta sessão (`7f8b1f1`, `b1a7856`, `9f983c3`) caíram nela |
| As duas cópias **divergiram** | `MIGRACAO.md` 125 linhas, `instalar-gates.sh` 78, `percus-gate.sh` 49, `conselho.md` 15, `review.md` 8, `CONSTITUICAO.md` 2; `loops/tdd.md` existe **só** na cópia viva |
| O gate que roda de verdade está **cego**, não apenas desatualizado | `_Novo_Projeto/v2/gates/percus-gate.sh` enxerga **33 de 105** verbetes de `COMO_RESOLVER.md`: o rastreio de fence dessincroniza com um ``` solto no texto e ele pula o resto do arquivo. Sai `exit 0` por não olhar, não por estar limpo. A cópia avulsa vê os 105, mas tinha os falsos positivos que corrigi hoje |
| A pasta avulsa tem **zero consumidores** | nenhum projeto define `PERCUS_CANON_V2_DIR`; o `tiatendo` (piloto-1) não referencia `_Novo_Projeto_V2` nem `v2/` |
| Quem roteia os projetos aponta pra cópia **viva** | `templates/CLAUDE.template.md`: `${env:PERCUS_CANON_DIR}/v2/loops/` |
| O kit é o veículo de entrega | `git pull` nas 10 máquinas; `PERCUS_CANON_DIR` → kit; `marketplace.json` com `source: ./plugin/percus-review` (relativo) |
| Atividade | kit: 63 commits/30 dias · pasta avulsa: 8 commits no total |

**Diagnóstico:** `_Novo_Projeto` **não é "o V1"** — é o *kit* (`huboperacional/percus-kit`), e contém
tanto a camada velha (`01..06_*.md`, `comandos/`, `checklists/`) quanto a nova (`v2/`). O nome da pasta
é que faz ela ler como "coisa velha", e a existência de `_Novo_Projeto_V2` faz parecer que a distinção
é de repositório quando é de **camada**. Foi essa leitura que levou o operador a supor que a migração
já teria acontecido — suposição legítima, porque a pasta existir dizia exatamente isso.

## 2. Problema secundário: o canal de entrega do plugin está morto

O republish/retag do plugin foi descartado por decisão de custo em 2026-07-01. Consequências medidas
hoje, no mesmo dia em que custaram trabalho real:

- O cache instalado tem **duas** pastas (`6.28.0`, `6.29.0`) e há **duas regras de resolução**:
  `CLAUDE_PLUGIN_ROOT` → `6.28.0` (hooks, skills e slash commands saem daí) e
  `percus-review-auto.*` → maior versão instalada (`6.29.0`). O canon-source está em `6.31.1`.
- Um fix de hook sincronizado só em `6.29.0` ficou **inerte**; foi preciso copiar à mão nas duas.
  O mesmo valia pro router — o comando de review do chat rodava a versão antiga.
- O canon já havia escolhido o caminho self-contained **para os gates**
  (`v2/gates/instalar-gates.sh`, git hook nativo, zero dependência de publicação).

## 3. Decisões

### 3.1 Topologia: uma casa, nome honesto

- `D:\Claud Automations\_Novo_Projeto` → **`D:\Claud Automations\percus-kit`**.
- `_Novo_Projeto_V2`: o conteúdo exclusivo é trazido para `percus-kit/v2/`; a pasta é **apagada**.
- Camada velha (`01..06_*.md`, `comandos/`, `checklists/`) → `.archive/`, com ponteiro no `README.md`.
- **Não** aterrissar em `_Novo_Projeto_V2`: a pasta avulsa tem 8 commits, enquanto o kit carrega o
  histórico do canon (48 versões de changelog). Landar no repo de 8 commits joga esse histórico fora
  ou exige cirurgia de merge, e o remote que as 10 máquinas puxam é o do kit.

### 3.2 Plugin: encolher, em duas etapas

Conselho Percus consultado (`consult`, deepseek + groq-llama): **2/2 por encolher** o plugin.

**Correção factual sobre a resposta do conselho:** ambos afirmaram que "slash commands e skills existem
somente via plugin". **É falso**, e isso foi verificado:
`D:\Claud Automations\Padrao Comportamento Humano\.claude\skills\` tem skills funcionando sem plugin
nenhum, e hooks em `settings.json` são mecanismo de primeira classe do harness. Hoje o `settings.json`
global **não tem** seção `hooks` — todos vêm do plugin, o que explica a dependência total.

- **Etapa 1 (esta rodada):** o **enforcement** sai do plugin. São **11 hooks registrados** no
  `hooks.json` (conferido, não estimado): `PreToolUse` — `pre-plan-exit`, `pre-commit-check`,
  `mock-scan-pre-commit`, `auth-import-pre-commit`, `migration-check-pre-commit`,
  `types-check-pre-commit`, `external-action-guard`, `crud-evidence-warn`; `Stop` — `on-stop-check`,
  `state-drift-check`; `PreCompact` — `pre-compact-checkpoint`. Todos passam a ser registrados no
  `settings.json` global apontando pro kit (`${PERCUS_CANON_DIR}\hooks\…`), entregues por `git pull`.
  Ordem de migração: primeiro os que já custaram trabalho (`pre-commit-check`, `external-action-guard`),
  depois o resto, um por commit.
- **Etapa 2 (rodada futura, se valer):** skills e slash commands migram pro `.claude-home/` via
  instalador e o plugin é desinstalado. Fora de escopo aqui porque exige passo por máquina.

**Risco aceito, com mitigação obrigatória:** enforcement duplo (bloqueio em dobro, ordem de execução
imprevisível, bypass). Regra dura — ao registrar um hook no `settings.json`, o equivalente do plugin é
desativado **no mesmo commit**. Nunca os dois vivos ao mesmo tempo.

## 4. Ordem de execução

1. **Merge das duas cópias do V2** em `percus-kit/v2/`. **Não** é "merge arquivo por arquivo" — o
   pre-mortem apontou isso como risco de consenso. O procedimento é assimétrico de propósito:
   - **Base = cópia viva** (`_Novo_Projeto/v2/`). É ela que os projetos leem e ela tem `loops/tdd.md`
     e a evolução v6.30.x. A cópia morta **nunca** é base.
   - Da cópia morta entram **exatamente 3 deltas nomeados**, nada além: (a) o gate de conhecimento,
     (b) seção `.percus-review.json` em `loops/review.md`, (c) o `.gitignore` — que no kit vira só a
     linha `.percus/`, porque `.deepseek/` já está lá. Qualquer outra diferença é evolução da viva e
     **fica como está**.
   - **Delta (a) não é "portar o meu fix"** — medir mudou o alvo. A cópia viva já resolve o falso
     positivo de âncora (pulando code fence e blockquote), mas é justamente esse rastreio de fence que
     a deixa **cega em 72 dos 105 verbetes**. A cópia morta enxerga os 105 mas tinha os falsos
     positivos. O resultado do merge é **melhor que as duas**: detecção por linha de título (`^## `),
     que exclui blockquote por construção e não depende de fence, mais crase opcional em `tags:`.
     Prova: 105 verbetes visíveis + `exit 0` no canon + matriz negativa ainda barrando.
   - Prova antes de seguir: gate roda no canon com `exit 0` **e** a matriz negativa (repo temporário)
     ainda bloqueia âncora órfã e verbete sem `tags:`. Sem essas duas evidências, o passo não fecha.
   - A pasta morta **só é apagada no passo 5**, depois de tudo verde — ela é o backup natural.
2. **Rename** da pasta + varredura das referências:
   - `.claude-home\settings.json`: `PERCUS_CANON_DIR` + ~14 entradas de permissão que hardcodam o path
     absoluto (variantes acumuladas do mesmo comando; se não forem atualizadas, viram prompt de
     permissão em vez de erro — falha silenciosa de UX).
   - **47 arquivos no kit citam `_Novo_Projeto`** (contados, não estimados). A varredura toca só os
     **vivos**: `templates/*` (4), `plugin/percus-review/commands/*` (5), `skills/*/SKILL.md` (4),
     `scripts/tracking_audit.py`, `hooks/auth-import-pre-commit.sh`, `hooks/on-stop-check.sh`,
     `plugin.json` (description), `tests/hardening-2026-05-18.tests.ps1` (tem o path **hardcoded** como
     fallback de `PERCUS_CANON_DIR` — quebra a suíte se ficar), `v2/MIGRACAO.md`,
     `v2/referencia/README.md`, `v2/gates/instalar-gates.sh`, `README.md`, `AMBIENTE_LOCAL_OPERADOR.md`.
     **Não** toca os históricos (`docs/superpowers/plans|specs` de maio, `docs/handoffs/*`,
     `docs/contracts/*`, `.archive/*`): descrevem o passado e reescrevê-los falsifica o registro.
   - 2 arquivos de projeto: `GHL-GOWA-WhatsApp\CLAUDE.md`, settings do `GHL-Evolution-WhatsApp`.
   - `tests/version-alignment.tests.ps1` deriva o path de `$PSScriptRoot` — imune ao rename por desenho.
   - **A varredura não é confiável como ato de memória** (risco levantado no pre-mortem: uma referência
     escapa e quebra em silêncio). Então ela vira **gate**: `tests/no-legacy-kit-path.tests.ps1` falha se
     `_Novo_Projeto` aparecer em qualquer arquivo **vivo** (allowlist explícita para `.archive/`,
     `docs/superpowers/plans|specs/`, `docs/handoffs/`, `docs/contracts/` e o próprio teste). Escapar
     passa a ser vermelho na suíte, não descoberta em produção.
   - **⚠️ O rename NÃO se propaga por `git pull`.** O nome do diretório de trabalho é local de cada
     máquina — o repo é o mesmo. Com 10 máquinas, ou existe um passo local por máquina ou o kit passa a
     ter nome diferente em cada uma e todo path absoluto documentado mente. Mitigação: `scripts/
     renomear-kit-local.ps1` (idempotente) que (a) detecta o path atual via `PERCUS_CANON_DIR`,
     (b) renomeia a pasta, (c) reescreve `PERCUS_CANON_DIR` e as entradas de permissão no
     `settings.json` do usuário, (d) valida o JSON resultante com `ConvertFrom-Json` antes de salvar,
     (e) faz backup datado do settings. Rodar em cada máquina no primeiro `git pull` após o rename.
     **Enquanto uma máquina não rodar, ela continua funcionando com o nome antigo** — o script é o
     único jeito de o rename não virar drift entre máquinas.
3. **Arquivar a camada velha** em `.archive/` com ponteiro.
4. **Migrar os 11 hooks** pro `settings.json` — um hook por commit, com o equivalente do plugin
   desativado no mesmo commit. Começa por `pre-commit-check` e `external-action-guard`.
   O pre-mortem chamou este passo de "desativa todo o enforcement sem alarme". Então a ordem **dentro
   de cada commit** é fixa e nenhuma etapa é pulável:
   1. Backup datado do `settings.json`.
   2. Registra o hook novo apontando pro kit.
   3. **Valida o JSON** (`Get-Content ... | ConvertFrom-Json`) — erro de sintaxe em `settings.json`
      falha calado e derruba os hooks todos, não só o que foi editado.
   4. **Canário do par**: um comando que **deve** ser bloqueado e um que **deve** passar, os dois
      rodados de verdade. Bloqueio observado = hook novo vivo. Sem isso, não avança.
   5. Só então desativa o equivalente no `hooks.json` do plugin, e repete o canário para provar que
      **um** bloqueio acontece — não dois, não zero.
   6. Sincroniza as **duas** pastas de cache do plugin (`6.28.0` e `6.29.0`), senão o hook desativado
      continua vivo em uma delas (foi o erro cometido em 2026-07-29 com o fix do `pre-commit-check`).
5. **Apagar** `_Novo_Projeto_V2`.

## 5. Critério de pronto (evidência observada, não asserção)

- `percus-gate.sh` da cópia viva roda no canon e sai `exit 0`, **e** a matriz negativa continua
  bloqueando âncora órfã e verbete sem `tags:`.
- Suíte do plugin verde (hoje 166/166) depois do rename — nenhum teste depende do path antigo.
- Um commit real de teste em um projeto passa pelo hook vindo do `settings.json`, e o hook do plugin
  correspondente **não** dispara (prova de que não há enforcement duplo).
- `pwsh -File "<kit>\scripts\percus-review-auto.ps1"` roda do path novo e decide igual ao anterior.
- `_Novo_Projeto_V2` não existe mais e nada aponta pra ele (`grep` limpo fora de transcript).
- Os 4 arquivos de versão continuam alinhados (`tests/version-alignment.tests.ps1` verde).

## 5.1 Por que a fase 2 (matar o "V1/V2") importa mais do que parece

O rótulo "V1/V2" nomeia **três pares diferentes** neste kit, e isso já produziu erro real:

| Par | V1 | V2 |
|---|---|---|
| Camada do canon | `01..06_*.md`, `comandos/`, `checklists/` | `v2/` (CONSTITUICAO + 8 loops) |
| Pasta no disco | `_Novo_Projeto` | `_Novo_Projeto_V2` (a avulsa, morta) |
| Doc de auth | `PADRAO_AUTH_CROSS_PROJETO.md` (arquivado) | `PADRAO_AUTH_SERVICE.md` — ver `docs/contracts/MIGRATION_V1_TO_V2.md` |

Foi essa sobrecarga que fez o operador (e esta sessão) trabalharem na pasta errada. A fase 2 não é
cosmética: é remover o termo ambíguo do vocabulário.

## 5.2 Registro do pre-mortem do conselho (2026-07-29)

Rodado em `pre-mortem` com `deepseek` + `groq-llama` sobre a versão de 137 linhas deste spec. A perna
Cross-Claude não rodou: exige subagent via Agent tool, restrito nesta sessão sem pedido do operador.
Log em `.deepseek/council-log/`.

| Risco | Quem apontou | O que mudou no spec |
|---|---|---|
| Merge das cópias perde o fix ou introduz divergência sutil | DeepSeek + Llama (**consenso**) | §4.1 virou merge **assimétrico**: base = cópia viva, 3 deltas nomeados da morta, prova por gate + matriz negativa antes de seguir, pasta morta só apagada no fim |
| `settings.json` mal editado desativa **todo** o enforcement sem alarme / enforcement duplo | DeepSeek + Llama (**consenso**) | §4.4 ganhou sequência fixa de 6 etapas por commit: backup → registra → valida JSON → canário → desativa o do plugin → canário de novo + sync das 2 caches |
| Varredura manual deixa referência escapar e quebra em silêncio | DeepSeek | §4.2: a varredura virou **teste** (`no-legacy-kit-path.tests.ps1`) com allowlist pros históricos |
| Resistência/incompreensão do vocabulário novo | Llama | §5.1 já trata (fase 2 mata o termo); o ponteiro no `README.md` do passo 3 é o paliativo imediato |
| **O rename não se propaga por `git pull`** (achado ao ler o pre-mortem; nenhum provider viu) | — | §4.2: `scripts/renomear-kit-local.ps1`, idempotente, roda uma vez por máquina; sem ele o kit tem nome diferente em cada máquina |

## 6. Fora de escopo (declarado)

- Subir `v2/` pra raiz e matar o vocabulário "V1/V2" — **fase 2**, porque mexe no `CLAUDE.md` dos 12
  projetos.
- Migrar skills/slash commands pro `.claude-home/` e desinstalar o plugin — **etapa 2** do §3.2.
- Ressuscitar o republish — contraria a decisão de custo de 2026-07-01.
- Reapontar os 12 projetos pro piloto V2 (`PERCUS_CANON_V2_DIR`): o piloto-1 fechou e o binding nunca
  existiu; a adoção segue por projeto, não neste spec.
