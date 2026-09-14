# PLANO.md — hub gerado, frente por arquivo, estado derivado — Design

**Data:** 2026-09-12 · Brainstorm com o operador · Pacote B (o Pacote A, `context-budget-guard`,
saiu na 6.45.0 e é independente deste). **Corpo ajustado pelas rodadas 1 e 2 do
`spec-analyze` em 2026-09-13.**

## O que este documento decide

O `docs/PLANO.md` deixa de ser um arquivo escrito à mão que cresce sem limite e passa a ser um
**hub gerado** de no máximo 80 linhas. Cada frente vira um arquivo próprio em `docs/plano/`, e o
estado de uma frente passa a ser **derivado** das suas tarefas em vez de declarado no título.

## Rodada 2 do `spec-analyze`, por delta — triagem (2026-09-13, noite)

> **Estado:** `AJUSTAR` nas três pernas, **nenhum CRITICAL**, findings tratados abaixo e aplicados no
> corpo. Pelo teto de 2 rodadas do conselho, a spec **não volta ao analyze**: segue para o plano de
> implementação, e defeito daqui em diante aparece no review do diff (R11).

**Como rodou.** Delta de ~2,5k tokens com as 12 decisões novas, as medições de cada uma e a lista do
que não reanalisar; `truncated: false` nas pernas de API. **DeepSeek:** a primeira chamada voltou
**vazia** (gastou os 16 000 tokens de teto raciocinando) e foi refeita sozinha com `-MaxTokens 32000`
— `.deepseek/council-log/20260913-213302-analyze.jsonl`, `AJUSTAR (4 high)`. **Llama:**
`20260913-213059-analyze.jsonl`, `AJUSTAR (1 high)`. **Cross-Claude:** subagente com o caminho da spec
e do código, `AJUSTAR (2 high)`; as três afirmações dela sobre código foram conferidas antes de aceitar.

**Achado do próprio método.** 3 findings pediam o que a spec já decide e o delta tinha resumido, e 3
outros (Llama) contradiziam o texto do próprio delta. Delta enxuto evita truncagem, mas a borda que
ele omite volta como finding: conferir na spec antes de aceitar.

### ACEITAR (aplicados no corpo)

| # | Finding | Perna | Premissa conferida | Onde |
|---|---|---|---|---|
| 1 | Arquivar no mesmo commit em que a frente fecha escapa do `crud-evidence-warn`, porque RF23 excluía `docs/historico/` | Cross-Claude HIGH | procede: o `[4-C]` commitado sai de `docs/plano/`, o `[5-T]` entra no histórico, e não há linha idêntica removida | RF23 |
| 2 | O "movimento" de RF23a não é implementável como o hook está | Cross-Claude HIGH | procede: o conjunto de removidas é por arquivo (`crud-evidence-warn.ps1:100`, no laço da linha 93) | RF23a |
| 3 | Checkpoint e R2 mandam editar `docs/PLANO.md`, que vira gerado | Cross-Claude MEDIUM | procede: `skills/checkpoint/SKILL.md:53` e `01_REGRAS_INEGOCIAVEIS.md:103` | RF26, RF27 |
| 4 | `.md` sob `docs/plano/` fora de classe (`_nova-frente.md`, subpasta) some calado | Cross-Claude MEDIUM | procede: RF16 só lia `.md` direto sem `_` | RF16a |
| 5 | Uma tag desconhecida basta para a frente ser incerta? | Llama MEDIUM | redação | RF4 |
| 6 | Sufixo de colisão parecia parar em `-3`; e vem antes ou depois do corte em 60? | Llama MEDIUM, DeepSeek LOW | redação | RF15 |
| 7 | `[4-C]?` é exemplo, não fórmula | DeepSeek HIGH, Llama MEDIUM | redação | RF4 |
| 8 | SC3: linha de base e saída por amostra insuficiente | DeepSeek HIGH | a unidade estava na spec; a linha de base e a saída, não | SC3 |
| 9 | As frentes vivas medidas são de projetos que o Fatiar recusa hoje | DeepSeek HIGH | procede: valem depois da passada manual; o teto de 25 não depende delas | RF8b |
| 10 | No Sync, "mês da execução" põe frente fechada há tempo no mês corrente | DeepSeek MEDIUM | procede; a regra passa a ser uma só nos dois modos | RF6a |
| 11 | Orçamento de 80 linhas sem conta linha a linha | DeepSeek MEDIUM | parcial: a parte fixa estava declarada, não enumerada | RF9 |
| 12 | Precedência entre abort do Sync e avisos na mesma execução | DeepSeek MEDIUM | procede | RF10 |
| 13 | "Frente viva" sem definição | DeepSeek MEDIUM | procede na definição; o ranking não precisa de regra própria | Definições, RF8b |
| 14 | Mover **e** editar um `[5-T]` no mesmo commit avisa | DeepSeek MEDIUM | procede; falso positivo aceito e declarado | RF23a |
| 15 | Marcas por `session_id` acumulam | DeepSeek LOW | procede; declarado | RF22b |

### RECUSAR, com motivo

- **Frente só com tags desconhecidas fica sem estado** (DeepSeek HIGH): RF4 já decide, `sem tarefa?`.
- **`docs/plano/manual.md` sem tratamento** (DeepSeek MEDIUM): é frente nova criada à mão (RF15a, RF16).
- **Ordem de avaliação entre recusas** (Llama LOW): RF13 lista todas as que falharam, juntas.
- **Critério de "antiga" sem medição** (Llama HIGH): D3 remove o critério de "antiga".
- **`state-drift-check` bloquearia projeto sem HANDOFF** (Llama MEDIUM): sem HANDOFF ele sai 0 calado (RF22).
- **SC3 sem procedimento de falha** (Llama LOW): o SC diz que a justificativa 2 sai da spec.
- **Movimento de `[5-T]` esconde falta de evidência** (Llama MEDIUM): a linha movida já era `[5-T]`
  commitado, com a evidência cobrada no commit que a criou. O caso real, fechar e arquivar no mesmo
  commit, é o item 1 aceito.
- **Aviso de tarefa em `_notas/` acumula sem prazo** (Cross-Claude LOW): a linha no hub, lida em toda
  sessão, é o mecanismo; gate ou idade máxima tornariam escape a tolerância que RF16a escolheu.

### Considerado e mantido: o Fatiar continua recusando (Cross-Claude MEDIUM, pergunta 3 do delta)

A alternativa: mandar seção com tarefa órfã para `_notas/` com aviso, e partir o preâmbulo em 40
linhas mais uma nota, em vez de recusar. Resolveria a praticidade do rollout, já que hoje só o piloto
passa. **Não entra**, por dois motivos medidos:

- **Onde a recusa é por (b), o conserto manual é pequeno:** 11 seções em três projetos (1 no tiatendo,
  3 no Paid Midia, 7 no Plexco Tasks). Em troca, cada tarefa órfã é classificada por uma pessoa
  **antes** de existir arquivo gerado. A alternativa troca essa parada por revisão de diff, que a
  própria Cross-Claude aponta como menos confiável.
- **Onde a recusa é por (c), partir em 40 linhas é chute com outro nome:** o `_contexto.md` viraria as
  40 primeiras linhas de um diário (4 259 no Familia-Milionaria), e não "o que é o projeto".

A assimetria com o Sync (RF16a) continua deliberada: no Fatiar é o script que classifica; no Sync, a
pessoa já classificou ao escrever. **Decisão reversível pelo operador** — está registrada para ser
contestada.

## Rodada 1 do `spec-analyze` — triagem dos findings, com premissa conferida (2026-09-13)

> **Estado:** `AJUSTAR`, **corpo ajustado** (2026-09-13, noite). Cada item ACEITAR abaixo aponta o
> requisito que o resolve. A rodada 2, por delta, está na seção acima.

**Fontes.** DeepSeek e Llama: `.deepseek/council-log/20260912-153617-analyze.jsonl` (`truncated: false`,
4 138 tokens: as duas pernas leram a spec inteira). Cross-Claude: saiu `error` nesse log; a resposta
válida veio do subagente da sessão de 12/09. **Contagem real: 37 findings** (DeepSeek 21, sendo 6 HIGH;
Llama 10, sendo 2 HIGH; Cross-Claude 6, sendo 2 HIGH). O "10 findings (6+2+2)" do plano contava só os HIGH.

### Medições que decidem a triagem

| O que a spec afirma | Medido em 2026-09-13 | Veredito |
|---|---|---|
| `state-drift-check` só lê o HANDOFF dentro de "Status de features"; 4 de 31 têm | Código confirma (`Read-HandoffFeatures`; sem casar, `exit 0`). **4 de 27** HANDOFFs na raiz dos projetos têm a seção. Recontado à noite pelo par que o hook de fato compara: **4 de 29** projetos com PLANO **e** HANDOFF, 4 desses 29 são worktrees | procede; recontar o N |
| `crud-evidence-warn` casa por basename | Confirmado (`GetFileName` = `PLANO.md`/`HANDOFF.md`), e ele é **warn-only** | procede |
| `PLANO.template.md` tem `## Histórico` | Confirmado (linha 74) | procede |
| "teto 150 já funciona: 12 projetos com gate, máximo 153" | O gate é `v2/gates/percus-gate.sh:54`. **13** projetos têm `percus-gate` em hook de git e HANDOFF; o maior tem **230 linhas** (`Paid Midia Automation/docs/HANDOFF.md`) | **falso**, e pior que o finding |
| Fatiar por `##` | `## Fase`/`## Marco` aparece **0** vezes em 4 de 5 PLANOs (6 só no Empresa-Milionaria, que a spec recusa). Mas `##` que **não é frente** existe em todos: Micro Investors 4 de 24, tiatendo 2 de 173, Plexco Tasks 15 de 84 (`Incidente:`, `Backlog:`, `Dívida:`), Familia-Milionaria 37 de 55. **`### Frente` aninhada**: tiatendo 13, Plexco Tasks 3 | a premissa da Cross-Claude cai; o problema de fundo é **maior** |
| Só tags do vocabulário canônico | Plexco Tasks tem `[EM EXECUÇÃO]` em título de `##` | a ordenação precisa tratar tag desconhecida |

### ACEITAR (entram no corpo)

1. **Ordem total das tags**, e o comportamento com tag desconhecida (DeepSeek HIGH; Llama FR-001 é o mesmo). → RF1, RF4
2. **Hub de "~1 tela" x `_contexto.md` de até 150 linhas**, contradição interna (DeepSeek HIGH). Fixar o orçamento do hub em linhas, contando o `_contexto.md`. → RF9, RF10
3. **Critério de "`[5-T]` antiga"** e destino de `[5-T]` sem data (DeepSeek HIGH). → RF6, RF6a
4. **`state-drift-check`: exit code e mensagem de cada caso** (DeepSeek HIGH; Llama SC-001 é o mesmo). Hoje ele bloqueia (exit 2) só em divergência casada e sai 0 calado quando não consegue comparar. Decidir como "avisar" sai num evento `Stop`. → RF22, RF22a, RF22b
5. **Numerar requisitos (RF-N)** e ligar cada teste a um RF (DeepSeek HIGH), no estilo da spec das comportamentais. → "Requisitos funcionais" e "Verificação"
6. **SC do benefício "3,6 → ~2 leituras por sessão"**, medido com o mesmo método dos 384 transcripts (DeepSeek HIGH). → SC3
7. **Seções `##` que não são frente e `### Frente` aninhada**: classificação e destino no Fatiar (Cross-Claude HIGH, reformulado pela medição; o LOW da DeepSeek sobre as 4 seções do piloto é o mesmo). → Definições, RF13b, RF14, RF14a
8. **Corrigir "12 projetos, máximo 153"** para 13 projetos, máximo 230 (Cross-Claude HIGH), e rever o argumento "o teto já funciona". → "Fora de escopo"
9. `docs/ESTADO.md` (Projeção): formato e relação com o hub (DeepSeek MEDIUM). → RF12, RF12a
10. Slug: sanitização e colisão determinística (DeepSeek MEDIUM; Cross-Claude LOW). → RF15
11. "Árvore suja": o predicado exato, e se vale para `-Modo Projecao` (DeepSeek MEDIUM; Cross-Claude MEDIUM). → RF16b, RF18
12. Conservação de tarefas: declarar que o script move linhas **sem editar**. O multiconjunto das linhas exatas é o invariante, e qualquer diferença aborta (DeepSeek MEDIUM). → RF19
13. Uma unidade só nas medições de leitura: tokens (DeepSeek MEDIUM). → "Motivação", SC3
14. Teto do `_contexto.md`: bloqueia ou avisa, e o que o Sync faz ao estourar (DeepSeek MEDIUM; Llama TERM-002). → RF10
15. Frente sem tarefa: estado explícito (DeepSeek MEDIUM). → RF3
16. Renomear frente: o hub é regerado a cada Sync; decidir o que acontece com os links do `historico/` (DeepSeek MEDIUM, parcial). → RF6c, RF15a
17. Versão do formato: declarar que vale para o diretório, e não por arquivo de frente (DeepSeek MEDIUM, parcial). → RF11
18. `crud-evidence-warn`: declarar que continua warn-only depois de incluir `docs/plano/*.md` (DeepSeek MEDIUM). → RF23, RF23a
19. "30 projetos": citar o comando. Hoje são 27 HANDOFFs na raiz e 33 repositórios git em `D:\Claud Automations` (DeepSeek MEDIUM). → "Rollout" (25 projetos, com o comando)
20. **O Sync nunca arquiva** frente que fecha no uso normal: só o Fatiar move para `historico/` (Cross-Claude MEDIUM). É um buraco real. → RF6, RF16
21. Redação: o título "não é fonte do estado; é lido só para sinalizar divergência" (DeepSeek LOW; Llama TERM-003 é o mesmo). → RF5
22. Migração v1→v2: marcar como reservada e testar só "versão desconhecida → recusa" (DeepSeek LOW). → RF11a
23. Definir "hub" (Llama TERM-001). → Definições
24. Empresa-Milionaria: exigir a mensagem de recusa e o relatório no formato padrão (Llama EDGE-001, parcial). → RF13a, RF20
25. Declarar as dependências: PowerShell 5.1+ e git (Llama ASSUMP-001). → "Dependências"
26. Mapear Etapa D/A aos passos do Rollout (Cross-Claude LOW). → "Rollout"

### RECUSAR, com motivo

- **"Vazamento de HOW"** (caminho do kit, nome de script, flags, marcador HTML, caminho de teste: DeepSeek MEDIUM ×2, Llama LEAK-001). As specs de design do kit nomeiam artefato de propósito, como fazem a de consolidação e a das comportamentais. A separação WHAT/HOW do spec-kit não é o padrão da casa.
- **"frente" x "bloco"** (Llama CONSIST-001): a tabela mapeia o vocabulário do operador de propósito. Nos artefatos só existe "Frente".
- **Descrever a R11 na spec** (Llama CONSIST-002): é documento interno do kit, e a regra é referência do canon.

### O que aplicar a triagem descobriu (medições de 2026-09-13, noite)

Aplicar os itens exigiu medir o que os findings só apontavam. Oito resultados mudam o desenho, e
são o conteúdo da rodada 2:

1. **Um terço das frentes não tem tarefa nenhuma.** 111 de 332 (33%) nos três PLANOs grandes com
   frente: tiatendo 73 de 171 (49 delas com `[5-T]` **só no título**), Paid Midia 30 de 92, Plexco
   Tasks 8 de 69. No piloto, 0 de 20. Pela decisão central elas aparecem como `sem tarefa` (RF3), e
   não como `[5-T]`. É consequência direta da decisão, não efeito colateral, e é o custo mais
   visível dela.
2. **Como estão hoje, só o Micro Investors passa no Fatiar.** tiatendo, Paid Midia e Plexco Tasks
   têm tarefa fora de `## Frente` (3, 52 e 55 tarefas); Plexco Tasks e Familia-Milionaria têm
   preâmbulo acima do teto (189 e 4 259 linhas). O script recusa e o relatório lista o conserto
   (RF13).
3. **A mediana de leituras de PLANO por sessão já é 2.** Recontagem com o mesmo script: 536
   leituras em 137 sessões, **média 3,9, mediana 2, p75 5**. O "3,6 → ~2" é sobre a cauda, então o
   SC3 mede média e p75, e não mediana.
4. **O piloto não tem volume para medir leitura:** 3 sessões com leitura de PLANO em 26 dias. O SC3
   fica para o primeiro projeto que acumular 10 sessões depois do Fatiar.
5. **`Stop` aceita aviso sem bloqueio, por `systemMessage`** (doc oficial, citada em RF22a). Um
   subagente consultado nesta sessão afirmou o contrário, sem citar fonte; a página desmente. Como o
   `Stop` dispara a cada fim de turno, o aviso sai uma vez por sessão (RF22b).
6. **O commit do Fatiar inundaria o `crud-evidence-warn`:** toda linha `[5-T]` movida aparece como
   adicionada no arquivo novo (316 linhas de tarefa `[5-T]` no tiatendo). RF23a desconta movimento.
7. **Árvore suja medida pela árvore inteira travaria o tiatendo para sempre:** 255 arquivos
   untracked, nenhum nos caminhos do plano. RF18 restringe o predicado aos caminhos que o Fatiar toca.
8. **"O teto do HANDOFF funciona" não se sustenta por dois lados:** entre os 13 projetos com gate, o
   do Paid Midia tem 230 linhas; e 20 dos 33 repositórios não têm o gate, o maior HANDOFF deles com
   2 216 linhas (Kommo-Disparo-WhatsApp).

### O que a triagem muda na implementação

- O conserto do `state-drift-check`, que sai verde calado em 25 dos 29 projetos com PLANO e HANDOFF, **independe do resto** e pode sair antes do `plano-sync`.
- O item 7 muda o desenho do Fatiar. Por medição, "cada `##` é uma frente" é falso nos quatro PLANOs que o script aceitaria.

## Motivação — e a correção de rota que a medição impôs

O pacote nasceu de uma hipótese que **a medição desmentiu**, e o registro honesto disso é parte do
design.

**Hipótese inicial (errada):** "o boot custa ~150k tokens lendo o PLANO inteiro". Veio de ler o
`CHECKLIST_INICIO_SESSAO` passo 2 ("ler `docs/PLANO.md` e contar os status") e supor leitura
integral, somada ao tamanho real dos arquivos (6.262 linhas em Empresa-Milionaria, 11.255 em
tiatendo).

**O que os 384 transcritos mostram:** 481 leituras de `PLANO.md` medidas, das quais **457 são
parciais** (`offset`/`limit`) e só 24 integrais. Mediana por leitura: ~0,5k tokens. Custo médio por
sessão que toca o PLANO: **~5k tokens**, cerca de 6% de um boot de 80k, não 65%. **Unidade:** todas
as medições de leitura deste documento são em tokens, estimados como caracteres ÷ 4 (a mesma
conversão do script de medição).

**Conclusão que sobrevive à medição:** economia de token **não** é a justificativa deste pacote.
Sobram três, todas medidas:

1. **O documento mente.** 13 afirmações falsas no `docs/PLANO.md` do Plexco Tasks, a mais antiga com
   ~3 meses; 101 commits tocaram o arquivo sem voltar nelas. Ver
   `conhecimento/resolver/plano-append-only-mente-e-o-canon-elege-ele-juiz.md`. O canon elege o
   PLANO como juiz ("o PLANO vence") e não tem nenhuma instrução que reconcilie o PLANO contra a
   realidade — então qualquer erro que entre nele é promovido a fato.
2. **Idas e voltas.** Média de 3,6 leituras de PLANO por sessão em 12/09; 3,9 na recontagem de
   13/09, com mediana 2 e p75 5. O agente caça informação no arquivo, e o custo está na cauda. Um hub
   curto mais o arquivo da frente do próximo passo deveria derrubar a média para perto de 2. **Isto
   é hipótese até o SC3 medir.**
3. **Colisão entre sessões.** Duas sessões editando o mesmo arquivo gigante conflitam no git; a
   6.38.0 já resolveu exatamente isso na base de conhecimento (monólito → um arquivo por verbete).

**Achado colateral, independente deste pacote e mais grave que ele:** o hook `state-drift-check`
(evento `Stop`, **bloqueia** com exit 2) só coleta features do HANDOFF dentro de uma seção chamada
"Status de features". Apenas **4 dos 29** projetos com PLANO e HANDOFF têm essa seção. Nos outros
25 o hook roda, não acha nada, e sai verde — um gate que protege no papel e não no fato. Corrigido
aqui (RF21, RF22).

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

### Classes de seção, pelas definições abaixo (2026-09-13)

Medido com as definições desta spec aplicadas ao `docs/PLANO.md` de cada projeto:

| Projeto | `##` | Frentes | Sem tarefa | Incertas | Não-frente **com** tarefa | Notas | Preâmbulo | Arquivaria | Passa no Fatiar hoje? |
|---|---|---|---|---|---|---|---|---|---|
| Micro Investors | 24 | 20 | 0 | 1 | 0 | 4 | 3 l | 1 | **sim** |
| tiatendo | 173 | 171 | 73 | 5 | 1 (3 tarefas) | 1 | 7 l | 13 | não — RF13 (b) |
| Familia-Milionaria | 55 | 18 | 1 | 1 | 0 | 37 | **4 259 l** | 10 | não — RF13 (c) |
| Paid Midia Automation | 120 | 92 | 30 | 9 | 3 (52) | 25 | 2 l | 24 | não — RF13 (b) |
| Plexco Tasks | 84 | 69 | 8 | 5 | 7 (55) | 8 | **189 l** | 19 | não — RF13 (b), (c) |
| Empresa-Milionaria | 35 | **0** | — | — | 1 (19) | 34 | 13 l | 0 | não — RF13 (a), (b) |

Nenhum dos seis tem `##` dentro de bloco de código cercado, e nenhum repete uma linha de tarefa
idêntica. A maior nota do piloto é "Estado vigente", com 476 linhas de trabalho fechado narrado em
`###`.

## Definições

- **Hub** — o `docs/PLANO.md` de um projeto já fatiado: arquivo 100% gerado pelo Sync, com orçamento
  fixo de linhas (RF9). É um arquivo, não uma tela. Antes do Fatiar, a vista equivalente é o
  `docs/ESTADO.md` da Projeção (RF12).
- **Tag canônica** — exatamente uma de `[0]`, `[1-S]`, `[2-E]`, `[3-H]`, `[4-C]`, `[5-T]`, a legenda
  de `templates/PLANO.template.md`. Comparação exata: `[5-T parcial]`, `[~5-T]` e `[4-C→LIVE]` não
  são canônicas.
- **Linha de tarefa** — linha que, fora de bloco de código cercado, começa com `-` ou `*`, espaço,
  e uma tag canônica entre colchetes (opcionalmente entre crases). É a mesma forma que o
  `state-drift-check` já lê em `Read-PlanoFeatures`.
- **Linha de tag desconhecida** — mesma forma, com conteúdo entre colchetes que não é tag canônica:
  `[5-T parcial]`, `[risco]`, `[x]`, `[ ]`. Medido: presente em 5 frentes do tiatendo, 9 do Paid
  Midia, 5 do Plexco Tasks, 1 do piloto, 1 da Familia-Milionaria.
- **Seção** — de uma linha `## ` (fora de bloco de código cercado) até a próxima, incluindo todos os
  `###` e níveis abaixo.
- **Frente** — seção cujo título, sem crases, asteriscos, sublinhados e espaços iniciais, começa com
  a palavra `Frente` (`## Frente: X`, `## Frente B2 …`).
- **Frente viva** — frente com arquivo em `docs/plano/`, isto é, não arquivada. Inclui as `sem tarefa`
  e as incertas.
- **Nota** — seção que não é frente e não tem nenhuma linha de tarefa.
- **Preâmbulo** — as linhas antes do primeiro `## `.
- **Estado derivado** — ver RF2 a RF4.
- **Arquivar** — mover o conteúdo de uma frente fechada para `docs/historico/AAAA-MM.md` (RF6).

## Vocabulário

Não se inventa termo novo. O que existe hoje é mapeado ao vocabulário do operador:

| Operador diz | Canon usa | Onde vive |
|---|---|---|
| Fase / marco | Fase, Marco | **não entra no formato v1** — nenhum PLANO aceitável usa `## Fase` como agrupador (ver "Fora de escopo") |
| Bloco | **Frente** (186 no tiatendo, 100 no Paid Midia, 77 no Plexco) | **um arquivo** em `docs/plano/` |
| Tarefa | linha `- [2-E] nome` | dentro do arquivo da frente |

`## Frente:` continua sendo `## Frente:`. Nada é renomeado.

## Dependências

- **PowerShell 5.1 ou 7+.** A suíte do kit já cobra compatibilidade com 5.1 (`ps51-compat`).
- **git no PATH, e o projeto dentro de um repositório ou worktree.** O git é fonte de data
  (`blame`, `log`), de predicado (`status`) e o desfazer. Fora de git, os três modos recusam (RF18).
- **Nenhuma outra.** Sem Python, sem `jq`, sem rede.

## Forma dos artefatos

```
docs/
  PLANO.md              ← hub: 100% GERADO pelo Sync, no máximo 80 linhas (RF7–RF9)
  ESTADO.md             ← só ANTES do Fatiar: projeção gerada do monolito (RF12)
  plano/
    _contexto.md        ← escrito à mão: o que é o projeto, rumo, decisões vivas. Teto 40 linhas (RF10)
    _notas/<slug>.md    ← seções não-frente sem tarefa, movidas pelo Fatiar (RF14)
    <slug>.md           ← um arquivo por frente VIVA, com o dossiê dela
  historico/
    AAAA-MM.md          ← frentes arquivadas (RF6), agrupadas por mês
```

Arquivo gerado é **100% gerado** — é o padrão que o kit já usa em `conhecimento/*/INDICE.md`, e não
há mecanismo de preservar trecho manual dentro dele. Por isso o texto escrito à mão mora em
`_contexto.md`, arquivo separado, que o gerador copia para o topo do hub.

## A decisão central: estado derivado, não declarado

**O estado de uma frente é a MENOR tag entre suas tarefas.** Uma frente com tarefas em `[5-T]` e uma
em `[2-E]` é `[2-E]`, sempre.

Isso converte a R2 ("nunca arredonde para cima") de regra que alguém precisa lembrar em consequência
aritmética: ninguém promove uma frente escrevendo bonito no título, porque o título **não é fonte do
estado** — é lido só para sinalizar divergência (RF5). É a resposta direta ao verbete do PLANO que
mente.

O preço, medido: frente que só declara estado no título, sem linha de tarefa, fica `sem tarefa`
(RF3). No tiatendo são 73 de 171, e 49 delas dizem `[5-T]` no título. O script não converte título
em tarefa — isso seria reintroduzir o estado declarado pela porta dos fundos.

## Requisitos funcionais

> Numeração estável: requisito removido deixa buraco, não renumera. Cada teste de "Verificação"
> nomeia o RF que prova.

### Tarefa, tag e estado

- **RF1.** A ordem total das tags canônicas DEVE ser `[0]` < `[1-S]` < `[2-E]` < `[3-H]` < `[4-C]` <
  `[5-T]`, a da legenda. Nenhuma outra tag entra na ordem.
- **RF2.** O estado derivado de uma frente DEVE ser a menor tag canônica (RF1) entre todas as linhas
  de tarefa da seção, incluindo as que estão sob `###` aninhados.
- **RF3.** Frente sem nenhuma linha de tarefa DEVE ter o estado explícito `sem tarefa`: valor fora da
  ordem de RF1, nunca preenchido a partir do título e nunca arquivado (RF6).
- **RF4.** Linha de tag desconhecida NÃO DEVE entrar no mínimo de RF2, e DEVE marcar a frente como
  **incerta** — basta uma, mesmo que a frente tenha linhas canônicas: o hub mostra o estado derivado seguido de `?` (a menor canônica, como `[2-E]?`, ou
  `sem tarefa?` quando não há canônica nenhuma), o relatório lista a
  linha, e frente incerta nunca é arquivada. Não é erro: nenhum modo aborta por ela. É a R2 aplicada
  à tag que o script não entende — medido no Paid Midia, 3 frentes com tudo `[5-T]` e uma linha
  como `[5-T parcial]`, que por esta regra não fecham sozinhas.
- **RF5.** A tag canônica no **título** de uma frente NÃO DEVE ser fonte do estado; é lida só para
  sinalizar divergência. Quando existe e difere do estado derivado (incluindo `sem tarefa`), o
  relatório DEVE listar `titulo [X] != derivado [Y]`, e o hub DEVE contar as divergências numa linha.
  Medido: 55 divergências no tiatendo, 19 no Paid Midia, 3 no Plexco Tasks, 0 no piloto.

### Arquivamento

- **RF6.** Uma frente DEVE ser arquivada quando o estado derivado é `[5-T]` e ela não é incerta. **Não
  existe critério de "antiga":** fechou, sai. A regra é a mesma no Fatiar e no Sync, e é por isso
  que o Sync arquiva frente que fecha no uso normal.
- **RF6a.** O mês de destino DEVE ser o do maior `author-time` do `git blame` entre as linhas da
  seção, contando linha ainda não commitada como a data da execução. A regra é a mesma nos dois modos:
  no Fatiar, a árvore limpa de RF18 garante que toda linha tem commit; no Sync, a frente que acabou de
  fechar tem a última tarefa não commitada e cai no mês corrente, e a que fechou há tempo e só agora
  deixou de ser incerta cai no mês em que fechou. **Não existe `[5-T]` sem data.** Medido:
  `git blame --line-porcelain` leva 3,2 s no PLANO do tiatendo (11 448 linhas, 570 commits) e 4,9 s no
  do Micro Investors. *Emenda da rodada 2 (DeepSeek, MEDIUM):* a versão anterior usava, no Sync, o mês
  da execução para toda frente.
- **RF6b.** Arquivar DEVE acrescentar a seção inteira, sem editar linha, ao fim de
  `docs/historico/AAAA-MM.md` (criando o arquivo se não existir). Dentro de uma execução, as frentes
  arquivadas entram em ordem alfabética de slug. No Sync, o arquivo `docs/plano/<slug>.md` é
  removido.
- **RF6c.** Ao arquivar `docs/plano/<slug>.md`, o relatório DEVE listar os arquivos rastreados que
  citam esse caminho (`git grep -l`), **sem editá-los**. O hub não quebra: ele é regerado e aponta
  para `docs/historico/`, e não para frente arquivada.

### Hub

- **RF7.** O hub DEVE ser 100% gerado. Linha 1: `<!-- GERADO por plano-sync.ps1 -Modo Sync. Nao edite
  a mao. -->`; linha 2: `<!-- plano-format: 1 -->`.
- **RF8.** O conteúdo DEVE seguir esta ordem: (a) o `docs/plano/_contexto.md`, verbatim; (b) uma linha
  de contadores — quantas frentes em cada tag, `sem tarefa`, incertas, arquivadas (seções em
  `docs/historico/*.md`) e notas; (c) as linhas de aviso que existirem: títulos divergentes (RF5),
  tarefas fora de frente e arquivos fora de classe (RF16a); (d) a tabela de frentes vivas; (e) ponteiros para
  `docs/plano/_notas/` e `docs/historico/`.
- **RF8a.** A tabela DEVE ter as colunas estado, nome, última ação e link. **Nome** é o título sem o
  `## ` e sem o prefixo `Frente:`, cortado em 80 caracteres com `…`, com `|` escapado. **Última ação**
  é a data do último commit que tocou o arquivo da frente; arquivo com mudança ainda não commitada
  usa a data da execução, porque o checkpoint commita logo depois do Sync.
- **RF8b.** A tabela DEVE vir ordenada por última ação decrescente, com empate desfeito pelo slug, e
  ter **no máximo 25 linhas de frente**. O excedente vira uma única linha: `+N frentes vivas fora da
  tabela — docs/plano/`. Frente parada, inclusive `sem tarefa`, afunda pela data e não precisa de
  regra própria. As frentes vivas medidas nos PLANOs grandes (≈ 158 no tiatendo, 68 no Paid Midia, 50
  no Plexco Tasks) só existirão **depois** da passada manual que o Fatiar exige neles; o teto de 25
  não depende desses números.
- **RF9.** O hub DEVE ter **no máximo 80 linhas**, contando o `_contexto.md`. A aritmética:
  `_contexto.md` ≤ 40 (RF10) + parte fixa ≤ 15 + tabela ≤ 25 = 80. A parte fixa, linha a linha: 2
  marcadores + 1 em branco + 1 em branco depois do contexto + 1 de contadores + até 3 de aviso + 1 em
  branco + 2 de cabeçalho e separador da tabela + 1 de excedente + 1 em branco + 1 de ponteiros (os
  dois numa linha só) = 14, com teto 15. O termo
  "~1 tela" sai deste documento: o compromisso é o número.
- **RF10.** O `docs/plano/_contexto.md` DEVE ter no máximo **40 linhas**. Acima disso, o Sync DEVE
  **abortar sem escrever o hub**, com exit 1 e mensagem nomeando o arquivo, o tamanho e a saída
  (mover o excedente para uma nota em `docs/plano/_notas/`). Não trunca, e não escreve hub fora do
  orçamento. O teto antigo de 150 cai porque não cabia num hub curto. **O dono do número é o
  script:** não entra teto de `_contexto.md` no `percus-gate`, para o 40 não existir em dois lugares
  (R25). Quando o Sync aborta por este RF, a saída traz o abort primeiro e, depois dele, os avisos que
  a execução já tinha achado (RF16a).

### Versão do formato

- **RF11.** A versão do formato DEVE valer para o **diretório**: o marcador vive só no hub e cobre
  `docs/plano/`, `docs/plano/_notas/` e `docs/historico/` juntos. Arquivo de frente não carrega
  marcador — seria uma linha que o script acrescenta, e ela quebraria a conservação (RF19).
- **RF11a.** Sync ou Fatiar diante de hub com versão diferente de `1` DEVE recusar com exit 1,
  nomeando a versão encontrada. **A migração v1→v2 é reservada:** não existe v2, e o único
  comportamento de versão testado é "versão desconhecida → recusa".

### Modo Projeção — Etapa D

- **RF12.** `-Modo Projecao` DEVE ler o `docs/PLANO.md` monolítico, aplicar as definições e RF1–RF5,
  e escrever **só** `docs/ESTADO.md`, no formato do hub (RF7–RF9), com três diferenças: a linha 1 diz
  `-Modo Projecao`; o topo é o preâmbulo, cortado em 40 linhas e seguido de
  `(preambulo com N linhas; o Fatiar recusa acima de 40)` quando passar; e a última ação de uma frente
  é o maior `author-time` do `git blame` entre as linhas da seção. Não move, não apaga e não arquiva
  nada.
- **RF12a.** O Fatiar DEVE apagar `docs/ESTADO.md` no mesmo passo em que grava o hub: projeção e hub
  nunca coexistem.

### Modo Fatiar — Etapa A

- **RF13.** O Fatiar DEVE verificar **todas** as pré-condições antes de escrever qualquer arquivo, e
  recusar o projeto inteiro (exit 1) listando **todas** as que falharam, não só a primeira:
  - **(a)** existe pelo menos uma frente;
  - **(b)** nenhuma linha de tarefa fora de frente, no preâmbulo ou em seção não-frente. Tarefa fora
    de frente não entra em estado nenhum, e o hub mentiria por omissão. Promover a seção a frente
    seria chutar: das 11 seções nessa condição no tiatendo, Paid Midia e Plexco Tasks, duas são
    "Resumo numérico", cópia de contagem e não unidade de trabalho;
  - **(c)** preâmbulo com no máximo 40 linhas, porque ele vira `_contexto.md` (RF10);
  - **(d)** o projeto ainda não foi fatiado: `docs/plano/` não existe e o `docs/PLANO.md` não tem
    marcador de formato;
  - **(e)** árvore limpa, pelo predicado de RF18.
- **RF13a.** Projeto sem frente (Empresa-Milionaria: 0 em 35 seções) DEVE receber a recusa no formato
  do relatório (RF20), com a linha `recusas: 0 secoes Frente em 35 secoes ## -- o script nao separa
  estado de narrativa por heuristica; passada manual com o operador`.
- **RF13b.** A recusa por (b) DEVE nomear cada seção, com o número de tarefas; a recusa por (c) DEVE
  dizer o tamanho do preâmbulo. O conserto é humano e curto: renomear a seção para `## Frente:`, mover
  as tarefas, encurtar o preâmbulo.
- **RF14.** O destino DEVE ser dado pela classe:

  | Classe | Destino |
  |---|---|
  | frente | `docs/plano/<slug>.md`, com a seção inteira e o título incluído; ou `docs/historico/AAAA-MM.md`, se RF6 |
  | nota | `docs/plano/_notas/<slug>.md` |
  | preâmbulo | `docs/plano/_contexto.md` |

  A seção `Fase`/`Marco` que não é frente não tem classe própria: se não tem tarefa, é nota.
- **RF14a.** `### Frente` aninhada DEVE ficar dentro do arquivo da seção que a contém, e as tarefas
  dela entram no estado dessa seção (medido: 13 no tiatendo e 2 no Plexco Tasks, dentro de `## Frente`).
  Aninhada em seção não-frente (6 no Paid Midia, 1 no Plexco Tasks), segue a classe da seção: se há
  tarefa, a pré-condição (b) recusa.
- **RF15.** O slug DEVE ser calculado nesta ordem: (1) remover o prefixo `Frente` e o separador que
  o segue (`:`, `—`, `-`, espaço); (2) decompor em Unicode NFD e descartar as marcas diacríticas;
  (3) passar a minúsculas; (4) trocar toda sequência de caracteres fora de `[a-z0-9]` por um `-`;
  (5) aparar `-` das pontas; (6) cortar em 60 caracteres e aparar de novo; (7) se vazio, usar `frente`
  (ou `nota`); (8) se for nome reservado do Windows (`con`, `prn`, `aux`, `nul`, `com1`–`com9`,
  `lpt1`–`lpt9`), acrescentar `-x`. **Colisão**, inclusive a criada pelo corte em 60: em ordem de
  aparição no PLANO, a primeira fica com o slug, a segunda ganha `-2`, a terceira `-3`, e assim por
  diante, sem limite; o sufixo entra **depois** do corte, e o nome pode passar de 60 pelo tamanho dele.
  Os passos 4 e
  5 garantem que slug nunca começa com `_`, então não colide com `_contexto.md` nem com `_notas/`.
- **RF15a.** O slug DEVE ser calculado **só no Fatiar**. Nenhum modo renomeia arquivo de frente: o
  nome do arquivo é a identidade da frente, e o título dentro dele pode mudar à vontade. Frente nova,
  depois do Fatiar, é arquivo criado à mão em `docs/plano/`.

### Modo Sync — rotina

- **RF16.** O Sync DEVE ler as frentes em `docs/plano/*.md` (todo `.md` direto em `docs/plano/` cujo
  nome não começa com `_`), arquivar as que RF6 manda, e regenerar o hub (RF7–RF10). Não usa o
  `docs/PLANO.md` como fonte. Hub sem marcador de formato → recusa com exit 1: projeto não fatiado
  usa a Projeção.
- **RF16a.** Linha de tarefa em `_contexto.md` ou em `_notas/*.md` não entra em estado nenhum, e o
  Sync NÃO DEVE abortar por ela; o hub DEVE mostrar `N tarefas fora de frente: <arquivos>` e o
  relatório lista cada linha. O mesmo vale para **arquivo fora de classe**: todo `.md` sob
  `docs/plano/` que não é frente, `_contexto.md` nem `_notas/*.md` — um `_nova-frente.md` criado por
  analogia, uma frente movida para subpasta. Ele não entra em estado nenhum e, sem o aviso, sumiria
  calado (Cross-Claude, rodada 2). No Fatiar a mesma condição recusa (RF13b) porque ali é o script que
  decide a classe; aqui foi uma pessoa que escreveu, e parar o checkpoint por isso vira escape de
  rotina.
- **RF16b.** Árvore suja NÃO DEVE impedir o Sync: ele roda no checkpoint, antes do commit, com a
  árvore suja por definição. As proteções dele são a conservação (RF19) e o review R11 do commit.

### Segurança

- **RF17.** `-DryRun` DEVE ser o padrão nos três modos; escrever exige `-Aplicar`. Em dry-run o script
  imprime o relatório (RF20) e, na Projeção, o conteúdo que gravaria. Não cria, move nem apaga
  arquivo algum, nem o `docs/.plano-sync-report.txt`.
- **RF18.** **Árvore suja**, para o Fatiar, DEVE ser exatamente: `git status --porcelain
  --untracked-files=all -- docs/PLANO.md docs/ESTADO.md docs/plano docs/historico` com saída não
  vazia. Só os caminhos que o Fatiar lê ou escreve; arquivo sujo em outro lugar não impede (medido:
  tiatendo tem 255 untracked, 5 deles em `docs/`, nenhum nesses caminhos). **A Projeção é isenta:**
  grava um único arquivo 100% gerado e se desfaz apagando-o. O Sync é isento por RF16b. Diretório fora
  de repositório git ou worktree: os três modos recusam com exit 1 (medido: 2 dos 29 projetos com
  PLANO e HANDOFF estão fora de git — Paid Midia Tracking e CL_Liliflow).
- **RF19.** O script DEVE **mover linhas, nunca editá-las**, e provar isso por invariante antes de
  gravar e de novo relendo do disco depois de gravar:
  - **Fatiar:** o multiconjunto das linhas do `docs/PLANO.md` original é igual ao multiconjunto das
    linhas de `_contexto.md` + `docs/plano/*.md` + `docs/plano/_notas/*.md` + o trecho acrescentado a
    `docs/historico/*.md` nesta execução. O hub fica fora: é gerado;
  - **Sync:** o multiconjunto das linhas de `docs/plano/*.md` (exceto `_*`) antes é igual ao delas
    depois + o trecho acrescentado ao histórico.

  A comparação é por igualdade exata do texto da linha, normalizando só o terminador (`CRLF`/`LF`).
  Multiconjunto, e não conjunto, porque linha em branco e `---` se repetem. **Qualquer diferença —
  linha sumida, a mais ou alterada — aborta com exit 1** e restaura o estado anterior: os originais
  voltam do que foi lido em memória, e os arquivos criados são apagados.
- **RF20.** O script DEVE terminar sempre com o mesmo bloco, em qualquer modo e desfecho:

  ```
  [plano-sync] <projeto> — modo <X>, formato v<N>, <DRY-RUN | APLICADO | RECUSADO | ABORTADO>
    antes:   <L> linhas, <S> secoes ## (<F> frentes, <N> notas), preambulo <P> linhas
    depois:  hub <H> linhas | <V> frentes vivas | <A> arquivadas nesta execucao | <N> notas
    estados: <contagem por tag, sem tarefa, incertas>
    linhas:  <T> antes, <T> depois  [CONSERVADAS | DIFERENCA <n> -> ABORTADO]
    avisos:  titulo divergente <n> | tag desconhecida <n> | frente > 400 linhas <n> | refs a arquivado <n>
    recusas: <cada pre-condicao que falhou, com o local e o conserto>
  ```

  Depois do bloco, uma linha por item de aviso ou recusa. **Exit 0** em dry-run ou execução aplicada;
  **exit 1** em recusa ou abort. Com `-Aplicar` e exit 0, o bloco também é gravado em
  `docs/.plano-sync-report.txt`. Frente acima de 400 linhas é só aviso: ela cresce por razão legítima
  enquanto vive e sai inteira quando fecha. Teto rígido nela repetiria o erro do `CONTEXT.md`, que
  virou escape rotineiro.

Vinte e cinco relatórios comparáveis mostram padrão de falha; vinte e cinco prosas não.

#### As duas revisões, de naturezas diferentes

O operador pediu revisão dupla antes de cada projeto aplicar. Duas passadas do **mesmo** agente
sobre o próprio trabalho tendem a confirmar o erro (o "verificador cego ao raciocínio" já registrado
na memória do operador). Então as duas revisões são de tipos distintos:

1. **Mecânica, pelo script** — a conservação de RF19. Não depende de ninguém prestar atenção.
2. **Cross-provider, pelo R11.** O diff da reorganização passa pelo review antes do commit, como
   qualquer mudança.

O `git diff` da árvore limpa é a terceira conferência, de graça.

### Hooks e canon

- **RF21.** O `state-drift-check` DEVE ler as tarefas de `docs/plano/*.md` (exceto `_*`) quando o hub
  tem marcador de formato, e de `docs/PLANO.md` ou `PLANO.md`, como hoje, quando não tem. Lendo só o
  hub depois do Fatiar, o hook silenciaria: o hub não tem linha de tarefa.
- **RF22.** O `state-drift-check` DEVE sair assim, por caso:

  | Caso | Saída |
  |---|---|
  | **Divergência casada:** mesmo nome normalizado, uma tag de cada lado, tags diferentes | **exit 2**, stderr como hoje: bloqueia, e o stderr vai ao modelo |
  | **Não comparou:** a fonte de RF21 tem ao menos uma linha de tarefa e existe HANDOFF, mas ele não tem a seção `Status de Features` ou a seção não rende nenhuma linha parseável | **exit 0** com `{"systemMessage": "<mensagem>"}` no stdout, uma vez por sessão (RF22b) |
  | Sem PLANO, sem HANDOFF, fonte sem tarefa, stdin vazio, `PERCUS_SKIP_DRIFT_CHECK` ou `PERCUS_HOOKS_DISABLED`, erro interno | exit 0, calado |

  Mensagem do segundo caso: `[percus:hook state-drift] NAO COMPAROU: <caminho do HANDOFF> nao tem a
  secao "Status de Features" (templates/HANDOFF.template.md) -- a divergencia de status PLANO x
  HANDOFF nao e verificada neste projeto. Nada foi bloqueado.`
- **RF22a.** O canal DEVE ser `systemMessage`, por ser o único que o `Stop` oferece para dar texto ao
  modelo sem bloquear. Doc oficial (`https://code.claude.com/docs/en/hooks`, seção Stop): *"Stop does
  not support `additionalContext`. To give Claude text without blocking, return `systemMessage`."* e
  *"On exit 0, Claude Code writes stdout and stderr to the debug log only, not the transcript, so
  Claude doesn't see them."* A segunda frase é o que o kit já tinha medido para outro evento
  (`docs/superpowers/medicoes/2026-07-31-semantica-hooks-harness.md`, item 10). Exit 2 no caso "não
  comparou" bloquearia o fim de todo turno em 25 de 29 projetos: escape declarado no primeiro dia.
- **RF22b.** O aviso DEVE sair **uma vez por `session_id`**, marcado em
  `.deepseek/state-drift/<session_id>.flag` — o mesmo desenho do `context-budget-guard`, que guarda
  estado por sessão em `.deepseek/context-budget/`. O `Stop` dispara a cada fim de turno, e repetir o
  aviso seria ruído que custa contexto e ensina a ignorar. Payload sem `session_id`, ou falha ao gravar
  a marca: avisa mesmo assim, pelo lado que fala. As marcas acumulam, uma por sessão e de poucos bytes,
  sem limpeza: declarado e aceito.
- **RF22c.** O aviso tem caminho para ficar verde: a seção existe no template
  (`templates/HANDOFF.template.md:31`). Medido: 4 dos 29 projetos com PLANO e HANDOFF a têm, então
  hoje ele dispara em 25. Continua warn-only; promover a bloqueio está em "Fora de escopo".
- **RF23.** O `crud-evidence-warn` DEVE casar também os arquivos staged em `docs/plano/` cujo nome não
  começa com `_` **e em `docs/historico/`**, além de `PLANO.md` e `HANDOFF.md` por basename. Continua
  **warn-only** (exit 0 sempre), com a mesma mensagem e o mesmo escape `CRUD-verified:`. *Emenda da
  rodada 2 (Cross-Claude, HIGH):* a versão anterior excluía `docs/historico/` com o argumento de que
  arquivar só move um `[5-T]` que já existia. Falso no caso mais comum: a última tarefa passa de
  `[4-C]` a `[5-T]`, o checkpoint roda o Sync e a frente é arquivada **no mesmo commit** — o `[5-T]`
  nasce direto no histórico, sem nunca ter sido commitado em `docs/plano/`, e a exclusão o esconderia.
  O movimento legítimo fica com RF23a.
- **RF23a.** Linha `[5-T]` adicionada que aparece, idêntica depois da normalização que o hook já faz,
  como removida **em qualquer arquivo** do mesmo diff staged é **movimento**, e NÃO DEVE avisar. Sem
  isso o commit do Fatiar avisaria sobre toda tarefa `[5-T]` do projeto (316 no tiatendo). Hoje o
  conjunto de removidas é recriado **por arquivo** (`plugin/percus-review/hooks/crud-evidence-warn.ps1:100`,
  dentro do laço da linha 93): casar `docs/PLANO.md` com `docs/plano/<slug>.md` exige juntar as removidas
  de todos os arquivos antes de olhar as adicionadas. Mover **e** editar a mesma linha `[5-T]` no mesmo
  commit avisa: falso positivo aceito e declarado, porque o hook é warn-only e tem escape.
- **RF24.** O passo 2 do `CHECKLIST_INICIO_SESSAO` DEVE, em projeto fatiado, mandar ler o hub e abrir
  **só** o arquivo da frente do próximo passo; a contagem de status do passo sai dos contadores do
  hub. Em projeto não fatiado, o passo não muda.
- **RF25.** O `templates/PLANO.template.md` DEVE perder a seção `## Histórico (changelog do plano em
  si)` (linha 74): é o convite estrutural à narrativa que produziu 34% de blocos datados no
  Empresa-Milionaria.
- **RF26.** A skill `checkpoint` DEVE rodar `plano-sync -Modo Sync -Aplicar` antes do commit quando o
  hub tem marcador de formato. Exit 1 do Sync interrompe o checkpoint, com a mensagem do relatório, e
  o checkpoint não commita hub atrasado em relação às frentes. O passo 1 da skill também DEVE mudar:
  hoje manda atualizar `docs/PLANO.md` (`plugin/percus-review/skills/checkpoint/SKILL.md:53`), o que em
  projeto fatiado é editar à mão o hub gerado, sobrescrito sem aviso pelo Sync seguinte. Passa a
  dizer: o arquivo da frente em `docs/plano/`, ou `docs/PLANO.md` em projeto não fatiado.
- **RF27.** O "Onde atualizar" da R2 (`01_REGRAS_INEGOCIAVEIS.md:103`, hoje `docs/PLANO.md` fixo) DEVE
  ganhar a mesma distinção: em projeto fatiado, o arquivo da frente em `docs/plano/`. Sem isso a regra
  inegociável manda editar arquivo gerado (Cross-Claude, rodada 2).

## Critérios de sucesso

- **SC1 — conservação.** Toda execução com `-Aplicar` termina com `linhas: T antes, T depois
  [CONSERVADAS]`, ou com exit 1 e nada gravado. Provado por RED (T20).
- **SC2 — orçamento do hub.** Hub com no máximo 80 linhas em toda fixture, inclusive a de pior caso:
  200 frentes vivas e `_contexto.md` de 40 linhas (T7).
- **SC3 — idas ao arquivo** (a justificativa 2).
  - **Método:** o script do commit `e18abf8`. Ele conta, por transcrito de sessão, os `Read` cujo
    `file_path` em maiúsculas contém `PLANO` — o que já casa `docs/plano/*.md` —, e soma o tamanho do
    resultado. Tokens = caracteres ÷ 4. Conta só a ferramenta `Read`: leitura por `grep` ou `cat` fica
    fora, nos dois lados da comparação. A implementação salva esse script no kit, para a medição ser
    repetível e não depender de um transcrito.
  - **Linha de base da frota, 2026-09-13:** 400 transcritos, 137 sessões com leitura de PLANO, média
    3,9, mediana 2, p75 5, mediana de 3,7k tokens por sessão.
  - **Critério:** a unidade é a **sessão com ao menos uma leitura de plano**. No primeiro projeto que
    acumular 10 dessas sessões depois do Fatiar, **média ≤ 2,5 e p75 ≤ 3** leituras por sessão. A linha
    de base são as 10 últimas sessões do mesmo tipo antes do Fatiar, no mesmo projeto; havendo menos de
    10, todas as que houver, com o N declarado. O piloto não serve: teve 3 sessões com leitura de PLANO
    em 26 dias.
  - **Amostra insuficiente é saída explícita:** se, 90 dias depois do primeiro Fatiar, nenhum projeto
    tiver 10 sessões, o SC3 fica `não medido`, e a justificativa 2 é marcada assim nesta spec.
  - **SC3 não trava o rollout.** Se falhar, a justificativa 2 sai deste documento; as outras duas não
    dependem dela.
- **SC4 — `state-drift-check` deixa de ser verde calado.** Fixture sem a seção: a primeira parada da
  sessão produz exatamente um `systemMessage`, e a segunda parada da mesma sessão, nenhum. Fixture com
  a seção e sem divergência: nenhum (T23).
- **SC5 — piloto.** `-Modo Fatiar -Aplicar` no Micro Investors termina `CONSERVADAS`, com 0 recusas, e
  o operador aprova o diff antes do commit.

## Rollout

O `plano-sync.ps1` é **script do kit**, lido via `PERCUS_CANON_DIR` (que aponta para
`D:\Claud Automations\percus-kit`, o mesmo disco). Ele chega aos projetos **no instante em que é
salvo** — não depende de push nem de update de plugin. Só hooks e skills precisam de publicação.

0. **Antes de tudo, e independente:** o conserto do `state-drift-check` (RF21–RF22c). Sem hub
   fatiado, ele segue lendo `docs/PLANO.md`, então pode sair sem o resto.
1. Implementar com TDD no kit.
2. **Etapa D — Projeção no piloto** (Micro Investors, 787 linhas, 20 frentes): `-Modo Projecao
   -Aplicar`, e o operador confere o `docs/ESTADO.md` contra o que sabe do projeto. Desfaz-se apagando
   o arquivo.
3. **Etapa A — Fatiar no piloto:** dry-run, relatório lido com o operador, `-Aplicar`, diff revisado
   pelo operador, R11, commit (SC5).
4. Ajustar o que o piloto mostrar → commit → push do kit (R20).
5. Escrever o **documento de broadcast** (~10 linhas) que o operador cola nos outros projetos: rodar a
   Etapa D e o **dry-run** da Etapa A, e devolver os dois relatórios. **Quantos:** 29 `docs/PLANO.md`
   no primeiro nível de `D:\Claud Automations` (`ls -d "/d/Claud Automations"/*/docs/PLANO.md`), dos
   quais 4 são worktrees (o `.git` é arquivo) — **25 projetos**. Pela tabela de classes, os PLANOs
   grandes voltam com recusa, e isso é o esperado: o relatório diz o conserto.
6. Devolutivas chegam no formato do relatório → melhorias viram formato v2, hoje reservado (RF11a).

**O documento de broadcast manda rodar, não interpretar.** Se 25 agentes lerem instruções e "se
adaptarem", saem 25 formatos — e aí não existe um processo, existem vinte e cinco. A inteligência
mora no script, em um lugar, testada uma vez.

## Fora de escopo

Cada item diz até quando vale.

- **Reescrever o `docs/PLANO.md` do Empresa-Milionaria** — o script recusa (RF13a). A passada manual
  é trabalho à parte, **quando o operador marcar**, com ele presente.
- **Converter frente `sem tarefa` em linhas de tarefa** (73 no tiatendo) — **nunca pelo script**.
  Inferir tarefa a partir de título ou de tabela é o estado declarado que este pacote remove. Cada
  projeto converte à mão, depois do Fatiar, se quiser o estado derivado dessas frentes.
- **Mudar o formato do `HANDOFF.md`** — **enquanto este pacote não depender dele.** A justificativa
  anterior, "o teto de 150 já funciona: 12 projetos com gate, máximo 153 linhas", era falsa. Medido em
  2026-09-13: 13 projetos têm `percus-gate` no hook de git, e o `docs/HANDOFF.md` do Paid Midia
  Automation tem 230 linhas; 20 dos 33 repositórios não têm o gate, e o maior HANDOFF entre eles tem
  2 216 linhas (Kommo-Disparo-WhatsApp). Como as 230 linhas passaram pelo gate não foi medido. Os dois
  achados são próprios, fora deste pacote.
- **Agrupar frentes por Fase ou Marco no hub** — **até o formato v2, e só se o piloto ou as
  devolutivas pedirem.** Medido na triagem: `## Fase`/`## Marco` no início do título aparece 0 vezes
  em 4 de 5 PLANOs; onde a palavra aparece num `##` aceitável, é parte do nome da frente
  (`Frente: … (Fase A)`).
- **Promover o aviso "não comparou" do `state-drift-check` a bloqueio** — **até a seção existir na
  maioria dos projetos**, medido de novo antes de decidir.
- **Paridade `.sh` do `plano-sync`** — **até um projeto rodar fora do Windows.** Hoje o script é
  chamado pelo agente, nesta máquina.
- **Dieta de conectores MCP** — **permanentemente fora deste pacote**; é conta do operador, e
  `scripts/medir-baseline-boot.ps1` (6.45.0) é o instrumento. Mediana atual da frota: 81k, faixa
  50k–151k.

## Verificação

TDD em `plugin/percus-review/tests/plano-sync.tests.ps1` e nos testes dos hooks alterados. Cada teste
nomeia o RF que prova.

| Teste | O que prova | RF / SC |
|---|---|---|
| T1 | ordem total e mínimo, inclusive tarefa sob `###` aninhado | RF1, RF2 |
| T2 | frente sem tarefa → `sem tarefa`, tag do título ignorada, não arquiva | RF3, RF5, RF6 |
| T3 | tag desconhecida → sufixo `?`, não arquiva, nenhum modo aborta | RF4 |
| T4 | título divergente aparece em `avisos` e no hub; o estado é o derivado | RF5 |
| T5 | arquivamento: mês do maior `author-time` do blame nos dois modos (fixture git com datas forçadas); linha não commitada conta como a execução; ordem por slug | RF6, RF6a, RF6b |
| T6 | arquivar lista as refs rastreadas e não as edita | RF6c |
| T7 | hub: marcadores, ordem das partes, ordenação, teto de 25 com linha de excedente, pior caso ≤ 80 | RF7–RF9, SC2 |
| T8 | `_contexto.md` com 41 linhas → Sync exit 1, hub intocado | RF10 |
| T9 | última ação: arquivo commitado → data do commit; sujo → data da execução | RF8a |
| T10 | hub sem marcador no Sync, e `plano-format: 2` no Sync e no Fatiar → recusa | RF11, RF11a, RF16 |
| T11 | Projeção: formato do hub, preâmbulo cortado em 40 com a linha de corte, nada movido | RF12 |
| T12 | Fatiar apaga `docs/ESTADO.md` | RF12a |
| T13 | cada pré-condição (a)–(e) recusa sozinha; duas falhas juntas saem as duas no relatório | RF13, RF13b, RF20 |
| T14 | destino por classe; `### Frente` aninhada fica na seção que a contém; aninhada em não-frente segue a seção | RF14, RF14a |
| T15 | slug: acento, pontuação, prefixo `Frente:`, 61+ caracteres, colisão (inclusive por corte), nome reservado, vazio | RF15 |
| T16 | Sync não renomeia arquivo de frente cujo título mudou | RF15a |
| T17 | Sync: tarefa em `_notas/` e arquivo fora de classe → linhas no hub, sem abort; árvore suja não impede | RF16a, RF16b |
| T18 | dry-run não escreve nos três modos (árvore igual antes e depois) | RF17 |
| T19 | árvore suja: untracked fora dos caminhos não impede, dentro impede; fora de git → recusa | RF18 |
| T20 | conservação com RED: escrita que perde uma linha, e outra que altera uma linha → aborta e restaura | RF19, SC1 |
| T21 | idempotência: Sync 2× dá o mesmo hub, byte a byte; Fatiar 2× → a segunda recusa por (d) | RF13, RF16 |
| T22 | fixtures dos três formatos reais: tag no título sem tarefa (tiatendo), só tarefas (Micro Investors), diário sem frente (Empresa-Milionaria) | RF3, RF13a, RF14 |
| T23 | `state-drift-check`: os três casos da tabela; aviso uma vez por `session_id`; fonte `docs/plano/` em projeto fatiado | RF21, RF22, RF22b, SC4 |
| T24 | `crud-evidence-warn`: `docs/plano/x.md` e `docs/historico/AAAA-MM.md` casam; `[5-T]` movida de `docs/PLANO.md` para `docs/plano/x.md` não avisa; `[4-C]`→`[5-T]` arquivada no mesmo commit avisa; `[5-T]` nova avisa | RF23, RF23a |
| T25 | checkpoint roda o Sync em projeto fatiado; exit 1 do Sync interrompe | RF26 |

- **RF24, RF25, RF27 e o passo 1 de RF26 são texto do canon**, sem comportamento para testar:
  conferidos no R11 do diff.
- **Suíte inteira do kit verde**, não só os testes do tema, nos dois ambientes (Git Bash e
  PowerShell), e **sozinha**: nunca em paralelo com outra execução da suíte.
- **Piloto real** em Micro Investors, com diff revisado pelo operador (SC5).
