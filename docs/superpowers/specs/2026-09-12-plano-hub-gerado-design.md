# PLANO.md — hub gerado, frente por arquivo, estado derivado — Design

**Data:** 2026-09-12 · Brainstorm com o operador · Pacote B (o Pacote A, `context-budget-guard`,
saiu na 6.45.0 e é independente deste).

## O que este documento decide

O `docs/PLANO.md` deixa de ser um arquivo escrito à mão que cresce sem limite e passa a ser um
**hub gerado** de ~1 tela. Cada frente vira um arquivo próprio em `docs/plano/`, e o estado de uma
frente passa a ser **derivado** das suas tarefas em vez de declarado no título.

## Motivação — e a correção de rota que a medição impôs

O pacote nasceu de uma hipótese que **a medição desmentiu**, e o registro honesto disso é parte do
design.

**Hipótese inicial (errada):** "o boot custa ~150k tokens lendo o PLANO inteiro". Veio de ler o
`CHECKLIST_INICIO_SESSAO` passo 2 ("ler `docs/PLANO.md` e contar os status") e supor leitura
integral, somada ao tamanho real dos arquivos (6.262 linhas em Empresa-Milionaria, 11.255 em
tiatendo).

**O que os 384 transcritos mostram:** 481 leituras de `PLANO.md` medidas, das quais **457 são
parciais** (`offset`/`limit`) e só 24 integrais. Mediana por leitura: ~2k chars (~0,5k tokens).
Custo médio por sessão que toca o PLANO: **~5k tokens** — cerca de 6% de um boot de 80k, não 65%.

**Conclusão que sobrevive à medição:** economia de token **não** é a justificativa deste pacote.
Sobram três, todas medidas:

1. **O documento mente.** 13 afirmações falsas no `docs/PLANO.md` do Plexco Tasks, a mais antiga com
   ~3 meses; 101 commits tocaram o arquivo sem voltar nelas. Ver
   `conhecimento/resolver/plano-append-only-mente-e-o-canon-elege-ele-juiz.md`. O canon elege o
   PLANO como juiz ("o PLANO vence") e não tem nenhuma instrução que reconcilie o PLANO contra a
   realidade — então qualquer erro que entre nele é promovido a fato.
2. **Idas e voltas.** 3,6 leituras de PLANO por sessão: o agente caça informação no arquivo. Um hub
   de uma tela derruba isso para ~2 (hub + a frente do próximo passo).
3. **Colisão entre sessões.** Duas sessões editando o mesmo arquivo gigante conflitam no git; a
   6.38.0 já resolveu exatamente isso na base de conhecimento (monólito → um arquivo por verbete).

**Achado colateral, independente deste pacote e mais grave que ele:** o hook `state-drift-check`
(evento `Stop`, **bloqueia** com exit 2) só coleta features do HANDOFF dentro de uma seção chamada
"Status de features". Apenas **4 de 31** HANDOFFs têm essa seção. Nos outros 27 o hook roda, não
acha nada, e sai verde — um gate que protege no papel e não no fato. Corrigido aqui.

## Estado atual medido (2026-09-12)

| Projeto | Linhas | Seções `##` | `[5-T]` fechadas | Linhas que ocupam |
|---|---|---|---|---|
| tiatendo | 11.256 | 171 | 97 | 7.835 (69%) |
| Empresa-Milionaria | 6.263 | 33 | **0** | 0 |
| Familia-Milionaria | 4.640 | 55 | 16 | 112 (2%) |
| Paid Midia Automation | 4.073 | 120 | 74 | 2.953 (72%) |
| Plexco Tasks | 3.826 | 84 | 16 | 1.159 (30%) |
| Micro Investors (piloto) | 787 | 24 (20 são frentes) | — | — |

Os projetos **não** seguem um formato só. tiatendo põe a tag no título da frente
(`## Frente: X — [5-T] (data)`); Micro Investors não põe tag nenhuma no título e só tem tarefas
(`- [4-C] Login …`); Empresa-Milionaria não tem frente nem tag — virou diário, com 6.263 linhas e
19 tarefas. **Nenhuma heurística única cobre os três**, e o design assume isso explicitamente.

## Vocabulário

Não se inventa termo novo. O que existe hoje é mapeado ao vocabulário do operador:

| Operador diz | Canon usa | Onde vive |
|---|---|---|
| Fase / marco | Fase, Marco | linha no hub, agrupando frentes |
| Bloco | **Frente** (186 no tiatendo, 100 no Paid Midia, 77 no Plexco) | **um arquivo** em `docs/plano/` |
| Tarefa | linha `- [2-E] nome` | dentro do arquivo da frente |

`## Frente:` continua sendo `## Frente:`. Nada é renomeado.

## Forma dos artefatos

```
docs/
  PLANO.md              ← 100% GERADO, ~1 tela. "GERADO por scripts/plano-sync.ps1. Nao edite a mao."
  plano/
    _contexto.md        ← escrito a mao: o que e o projeto, rumo, decisoes vivas. Teto 150 linhas.
    <slug-da-frente>.md ← um arquivo por frente VIVA, com o dossie dela
  historico/
    AAAA-MM.md          ← frentes [5-T] encerradas, agrupadas por mes
```

O hub é montado com: o conteúdo de `_contexto.md` no topo, uma tabela de uma linha por frente
(estado, nome, última ação, link), os contadores por estado (*"2 em `[0]`, 3 em `[2-E]`, 1 em
`[4-C]`, 47 arquivadas"*) e o ponteiro para `docs/historico/`. É isso que responde "como estamos?",
que é a pergunta que o operador realmente faz.

Arquivo gerado é **100% gerado** — é o padrão que o kit já usa em `conhecimento/*/INDICE.md`, e não
há mecanismo de preservar trecho manual dentro dele. Por isso o texto escrito à mão mora em
`_contexto.md`, arquivo separado, que o gerador copia para o topo do hub.

## A decisão central: estado derivado, não declarado

**O estado de uma frente é a MENOR tag entre suas tarefas.** Uma frente com tarefas em `[5-T]` e uma
em `[2-E]` é `[2-E]`, sempre.

Isso converte a R2 ("nunca arredonde para cima") de regra que alguém precisa lembrar em consequência
aritmética: ninguém promove uma frente escrevendo bonito no título, porque o título não é lido para
isso. É a resposta direta ao verbete do PLANO que mente.

Quando o título da frente *também* traz uma tag (caso tiatendo) e ela diverge da derivada, o script
**avisa** e mantém a derivada. Divergência é sinal, não erro a silenciar.

## O gerador: `scripts/plano-sync.ps1`

Três modos. É o mesmo script que faz "chegar por D".

| Modo | O que faz | Quando |
|---|---|---|
| `-Modo Projecao` | Lê o `docs/PLANO.md` monolítico **como está**, extrai seções `##` e tags, escreve `docs/ESTADO.md` (1 tela). **Não move nem apaga nada.** | Etapa D — roda em qualquer projeto hoje, reversível apagando um arquivo |
| `-Modo Fatiar` | Move cada seção `##` para `docs/plano/<slug>.md`, `[5-T]` antigas para `docs/historico/AAAA-MM.md`, promove o hub a `docs/PLANO.md` | Etapa A — uma vez por projeto |
| `-Modo Sync` | Regenera o hub a partir de `docs/plano/*.md` | Rotina, no checkpoint |

**Segurança, embutida no script:**

- **`-DryRun` é o padrão.** Escrever exige `-Aplicar` explícito.
- **Recusa rodar com árvore suja.** O git é o desfazer, e só serve se o estado anterior estiver
  commitado.
- **Recusa o que não entende.** Em Empresa-Milionaria (0 frentes tageadas, 6.263 linhas de diário),
  `-Modo Fatiar` **aborta e diz por quê**, em vez de chutar uma separação entre estado e narrativa.
  Projeto assim entra na fila de uma passada manual, com o operador olhando.
- **Marcador de versão do formato:** o hub carrega `<!-- plano-format: 1 -->`. Quando o formato
  evoluir, o script sabe quem está em qual versão e migra 1→2 sozinho. Sem isso, "vamos melhorando
  conforme as devolutivas" vira divergência silenciosa entre os 30 projetos.

### As duas revisões, de naturezas diferentes

O operador pediu revisão dupla antes de cada projeto aplicar. Duas passadas do **mesmo** agente
sobre o próprio trabalho tendem a confirmar o erro (o "verificador cego ao raciocínio" já registrado
na memória do operador). Então as duas revisões são de tipos distintos:

1. **Mecânica, pelo script — conservação de tarefas.** Antes de escrever, extrai o conjunto de
   linhas `[tag]` do original; depois de escrever, extrai do resultado; compara os conjuntos. **Se
   uma tarefa sumiu, aborta e restaura.** Não depende de ninguém prestar atenção.
2. **Cross-provider, pelo R11.** O diff da reorganização passa pelo review antes do commit, como
   qualquer mudança.

O `git diff` da árvore limpa é a terceira conferência, de graça.

### Relatório padronizado

O script termina sempre imprimindo o mesmo bloco, e grava em `docs/.plano-sync-report.txt`:

```
[plano-sync] <projeto> — modo <X>, formato v<N>
  antes:  <L> linhas, <S> secoes
  depois: hub <H> linhas | <F> frentes vivas | <A> arquivadas em docs/historico/
  tarefas: <T> antes, <T> depois  [CONSERVADAS | FALTAM <n> -> ABORTADO]
  recusas: <lista de secoes que o script nao classificou, com o motivo>
```

Trinta relatórios comparáveis mostram padrão de falha; trinta prosas não.

## Hooks e gate

- **`state-drift-check`** (a correção mais importante, e válida mesmo sem o resto): procura as
  tarefas em `docs/PLANO.md` **ou** `docs/plano/*.md`, e **avisa quando não consegue comparar** em
  vez de sair verde. Hoje, sem a seção "Status de features" no HANDOFF, ele silencia — em 27 de 31
  projetos.
- **`crud-evidence-warn`**: hoje casa por basename (`PLANO.md`/`HANDOFF.md`); passa a incluir
  `docs/plano/*.md`, senão para de avisar depois do fatiamento.
- **Gate do canon**: teto de 150 linhas em `_contexto.md`. Arquivo de frente **não** ganha teto
  rígido — cresce por razão legítima enquanto a frente vive e sai inteiro quando ela fecha; só aviso
  acima de ~400 linhas. Teto rígido em arquivo que cresce legitimamente é o erro do `CONTEXT.md`,
  que virou escape rotineiro.
- **`CHECKLIST_INICIO_SESSAO` passo 2**: lê o hub (1 tela) e abre **apenas** o arquivo da frente do
  próximo passo.
- **`PLANO.template.md`**: sai a seção `## Histórico (changelog do plano em si)` — é o convite
  estrutural à narrativa que produziu 34% de blocos datados em Empresa-Milionaria.
- **Skill `checkpoint`**: roda `plano-sync -Modo Sync` antes do commit, para o hub nunca ficar atrás
  dos arquivos.

## Rollout

O `plano-sync.ps1` é **script do kit**, lido via `PERCUS_CANON_DIR` (que aponta para
`D:\Claud Automations\percus-kit`, o mesmo disco). Ele chega aos projetos **no instante em que é
salvo** — não depende de push nem de update de plugin. Só hooks e skills precisam de publicação.

1. Implementar com TDD no kit.
2. **Piloto em Micro Investors** (787 linhas, 20 frentes) — pequeno o bastante para revisar o
   resultado à mão, estruturado o bastante para a heurística valer. Operador confere o antes/depois.
3. Ajustar o que o piloto mostrar → commit → push do kit.
4. Escrever o **documento de broadcast** (~10 linhas) que o operador cola nos outros projetos.
5. Devolutivas chegam no formato do relatório → melhorias viram formato v2, migrado pelo script.

**O documento de broadcast manda rodar, não interpretar.** Se 30 agentes lerem instruções e "se
adaptarem", saem 30 formatos — e aí não existe um processo, existem trinta. A inteligência mora no
script, em um lugar, testada uma vez.

## Fora de escopo

- Reescrever `docs/PLANO.md` de Empresa-Milionaria: o script recusa, e a passada manual é trabalho
  à parte, com o operador presente.
- Mudar o formato do `HANDOFF.md` (teto 150 já funciona: 12 projetos com gate, máximo 153 linhas).
- Dieta de conectores MCP: é conta do operador, e `scripts/medir-baseline-boot.ps1` (6.45.0) é o
  instrumento. Mediana atual da frota: 81k, faixa 50k–151k.

## Verificação

- TDD em `plugin/percus-review/tests/plano-sync.tests.ps1`: fixtures dos **três** formatos reais
  (tag no título / só tarefas / diário sem tag); conservação de tarefas provada com RED (fixture em
  que uma tarefa some → aborta); recusa em árvore suja; `-DryRun` não escreve; idempotência (rodar
  duas vezes dá o mesmo resultado); migração de formato v1→v2.
- Testes dos hooks alterados, incluindo o caso "HANDOFF sem a seção → avisa" (hoje: silencia).
- Suíte inteira do kit verde, não só os testes do tema.
- Piloto real em Micro Investors, com diff revisado pelo operador.
