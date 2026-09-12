## O revisor carrega a faixa de regras FIXA no prompt e reprova regra que existe {#revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida}

`tags: review, R11, cross-provider, deepseek-review, prompt hardcoded, faixa de regras, R1-R13, R1-R19, R23, AGENTS.md, cwd, finding infundado, drift de canon, falso positivo`

**Sintoma:** o review devolve um finding dizendo que a regra que você citou **não existe** — algo
como *"referência a R{N} fora do conjunto R1-R13 citado no AGENTS.md; se não existe mapeamento
documentado, a tag vira ruído"*. A regra existe, está no canon, e outras dezenas de arquivos já a
usam.

**A causa, medida em 2026-09-12 e não deduzida:** a faixa está **escrita à mão dentro do prompt do
revisor**, e envelheceu.

> ⚠️ Lido com o kit em **`d9b75da` (6.48.0)**. Número de linha envelhece: se não bater, ache pelo
> padrão em vez de concluir que o verbete está errado — e use **`rg "R1-R1[0-9]" plugin/`**, não o
> texto ao redor. Duas das quatro ocorrências escrevem *"violações"* com acento e as outras duas
> *"violacoes"* sem; buscar pela frase acha metade e faz parecer que o problema é menor do que é.

São **quatro** sítios de prompt, e eles **discordam entre si**:

- `deepseek-review.ps1:150` e `deepseek-review.sh:134` — *"violações **R1-R13**"*
- `council-orchestrator.ps1:315` e `council-orchestrator.sh:216` — *"violacoes **R1-R19**"*

Os quatro estão atrás do canon, que já vai a **R23** (`01_REGRAS_INEGOCIAVEIS.md`). Nada lê o
arquivo de regras para descobrir o teto: o número é literal, duplicado por linguagem de script.
Então toda regra acima do literal é, para o revisor, inexistente — e ele diz isso com a confiança
de quem está citando documentação.

**A pista falsa que vem junto:** o finding cita *"o AGENTS.md"*, o que sugere que ele leu o arquivo
errado. Não foi isso. O `deepseek-review.ps1:125` faz `Join-Path (Get-Location) 'AGENTS.md'` — lê o
`AGENTS.md` do **diretório de onde você chamou**, e quando não há nenhum injeta o texto
*"(AGENTS.md ausente — revise pelo bom senso de Percus)"*. No caso medido o repo alvo **não tinha
AGENTS.md nenhum**, então o revisor citou como fonte um documento que nunca recebeu. A explicação
"ele leu as regras do outro repo" é plausível, circula, e **estava errada** — o `Get-Location`
importa para o `AGENTS.md`, não para a faixa.

**Por que engana:** o finding chega bem formado, com número de regra, nome de arquivo e sugestão de
correção. Nada nele parece memória do modelo. É a mesma classe de
[[auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe]]: mede-se o **rótulo** em
vez da coisa.

**Como aplicar:**

1. Finding que diz *"a regra R{N} não existe"* é **infundado por padrão** até você conferir.
   Confira na fonte, em dez segundos: procure `R{N}` em `01_REGRAS_INEGOCIAVEIS.md` e conte quantos
   arquivos já usam a tag. Se existe, **declare o finding como infundado no commit** em vez de
   remover a tag — remover é obedecer a um prompt velho e apagar informação verdadeira.
2. Rode o review **de dentro do repo dono dos arquivos**, para o `AGENTS.md` certo ser lido. Isso
   não resolve a faixa (ela é literal), mas resolve o resto do contexto.
3. Ao subir o canon para uma regra nova, **os quatro literais entram no mesmo commit** — e são
   quatro justamente porque cada script existe em `.ps1` e `.sh`. Um teto escrito à mão em quatro
   lugares que já divergem entre si (R1-R13 × R1-R19) vai divergir de novo: enquanto não for
   derivado do arquivo de regras, é dívida com data marcada. O conserto de verdade é o revisor não
   citar faixa nenhuma, ou lê-la de `01_REGRAS_INEGOCIAVEIS.md`.
