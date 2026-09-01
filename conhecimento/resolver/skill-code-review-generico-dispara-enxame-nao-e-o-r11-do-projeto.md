## Invocar a skill genérica "code-review" pensando no R11 do projeto dispara um enxame de subagentes, não o gate esperado {#skill-code-review-generico-dispara-enxame-nao-e-o-r11-do-projeto}

`tags: skill, code-review, percus-review, R11, nome ambiguo, subagentes, custo, engano de invocacao, R23`

**Sintoma:** ao precisar satisfazer o gate R11 antes de um commit, invocar a skill chamada
`code-review` (built-in/genérica) em vez de `percus-review:review` (a do canon Percus). A skill
genérica roda, mas o hook de pre-commit continua bloqueando — porque ela não escreve em
`.deepseek/reviews/latest.jsonl`, que é o que o hook lê. No caminho, ela dispara uma varredura
própria com **múltiplos subagentes em paralelo** ("finder angles": bugs, reuso, simplificação,
eficiência, altitude, convenções...) — 8-11 agentes, dezenas de milhares de tokens cada, para um
diff que às vezes nem é o que se pretendia revisar.

**Por que é fácil confundir:** os dois nomes descrevem a mesma AÇÃO em português ("revisar o
código") e um projeto com o plugin `percus-review` instalado frequentemente tem as duas skills
disponíveis na mesma lista — a genérica do harness e a do canon, lado a lado, sem marcação visual de
qual é qual além do nome completo (`percus-review:review` vs `code-review`).

**Como perceber rápido que invocou a errada:** a skill certa (`percus-review:review`) roda o
`review-router.ps1`/`.sh`, decide `deepseek`/`cross-claude`/`dual`, e devolve findings em segundos,
com saída no formato `## Findings DeepSeek`/`## Findings Cross-Claude`. A skill genérica, ao ser
invocada, tipicamente responde algo como "vou esperar os agentes finder terminarem" — se aparecer
menção a agentes/fases/dimensões rodando em background, já é sinal de ter chamado a errada.

**Recuperação:** parar os agentes remanescentes da skill errada (`TaskStop` em cada um — os que já
terminaram não têm como ser interrompidos, só descartados) assim que perceber, antes de deixar todas
as dimensões completarem; então invocar a skill certa pelo nome completo com namespace
(`percus-review:review`, não `review` nem `code-review`). Custo do engano some quando pego cedo —
cada minuto de atraso é mais um "finder angle" terminando.

**Prevenção:** ao precisar do gate R11 num projeto com o plugin instalado, use sempre o nome
namespaced completo (`percus-review:review`), nunca a forma curta — mesmo que a lista de skills
disponíveis mostre as duas com descrições parecidas.
