## O revisor carrega a faixa de regras FIXA no prompt e reprova regra que existe {#revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida}

`tags: review, R11, cross-provider, deepseek-review, council-orchestrator, prompt hardcoded, faixa de regras, R1-R13, R1-R19, R1-R23, R25, AGENTS.md, cwd, finding infundado, drift de canon, falso positivo`

**Sintoma:** o review devolve um finding dizendo que a regra que você citou **não existe** — algo
como *"referência a R{N} fora do conjunto R1-R13 citado no AGENTS.md; se não existe mapeamento
documentado, a tag vira ruído"*. A regra existe, está no canon, e outras dezenas de arquivos já a
usam.

**A causa, medida em 2026-09-12 e não deduzida:** a faixa está **escrita à mão dentro do prompt do
revisor**, em vários lugares, e todos envelheceram.

**Meça o teto, não o cite.** O canon vai a **R25** — e este número não veio de ler uma citação em
lugar nenhum, veio de derivar o máximo:

```bash
grep -oE "^## R[0-9]+\." 01_REGRAS_INEGOCIAVEIS.md | grep -oE "[0-9]+" | sort -n | tail -1   # -> 25
grep -cE "^## R[0-9]+\." 01_REGRAS_INEGOCIAVEIS.md                                           # -> 25, sem buraco
```

> ⚠️ Lido com o kit em **6.48.0**. Número de linha envelhece: ache pelo padrão, e use
> **`rg "R1-R[0-9]+" plugin/`**. Não use `rg "R1-R1[0-9]"` — ele perde o `R1-R23` do modo `analyze`.
> E não busque pela frase ao redor: `deepseek-review.*` escreve *"violações"* com acento e
> `council-orchestrator.*` escreve *"violacoes"* sem, então buscar o texto acha metade e faz o
> problema parecer menor do que é.

São **seis** sítios de prompt em **três faixas que discordam entre si**, mais 2 comentários:

| Onde | Diz | Regras que o revisor não sabe que existem |
|---|---|---|
| `deepseek-review.ps1` / `.sh` | `R1-R13` | **12** |
| `council-orchestrator.ps1` / `.sh` — modo `review` | `R1-R19` | **6** |
| `council-orchestrator.ps1` / `.sh` — modo `analyze` | `R1-R23` | **2** (R24, R25) |
| `council-orchestrator.ps1` / `.sh` — comentários | `R1-R19` | — |

**O modo `analyze` é o mais traiçoeiro**: por estar quase certo, ele passa por atualizado. Quem
conferir só ele conclui que o kit está em dia.

Nada lê o arquivo de regras para descobrir o teto: o número é literal, duplicado por linguagem de
script e por modo. Toda regra acima do literal é, para o revisor, **inexistente** — e ele diz isso
com a confiança de quem está citando documentação.

**A moral está na história deste verbete, e é a prova mais forte que ele tem.** A primeira versão
afirmava que *"o canon já vai a R23"* — porque quem escreveu **viu R23 existir** (linha 842) e
inferiu que era o teto, sem medir o máximo. Ou seja: um verbete que denuncia números copiados usou
um número copiado como régua, e errou por dois. O mesmo autor errou o comando de busca duas vezes
seguidas pela mesma razão — **descreveu** o padrão (`R1-R1[0-9]`) em vez de **derivá-lo** do que
estava no disco. Se a armadilha pega quem está escrevendo sobre ela, ela não é sobre distração.

**A pista falsa que vem junto:** o finding cita *"o AGENTS.md"*, o que sugere que ele leu o arquivo
errado. Não foi isso. O `deepseek-review.ps1` faz `Join-Path (Get-Location) 'AGENTS.md'` — lê o
`AGENTS.md` do **diretório de onde você chamou**, e quando não há nenhum injeta o texto
*"(AGENTS.md ausente — revise pelo bom senso de Percus)"*. No caso medido o repo alvo **não tinha
AGENTS.md nenhum**, então o revisor citou como fonte um documento que nunca recebeu. Duas
explicações plausíveis circularam e **as duas estavam erradas**: nem "ele leu as regras do outro
repo" (não leu regra nenhuma), nem "rodar de dentro do repo certo resolve" (o `Get-Location`
importa para o `AGENTS.md`, não para a faixa — rodando de dentro do kit o finding vem igual).

**Por que engana:** o finding chega bem formado, com número de regra, nome de arquivo e sugestão de
correção. Nada nele parece memória do modelo. É a mesma classe de
[[auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe]] e de
[[regra-declarada-automatica-sem-hook-e-decoracao]]: mede-se o **rótulo** em vez da coisa. As três
morderam no mesmo repo **no mesmo dia** — hook se autodeclarando `(R5)`/`(R6)` depois de uma
renumeração, uma tabela de auditoria recopiada em três arquivos, e esta faixa em seis. Sempre um
literal escrito à mão fazendo as vezes de fonte.

**Como aplicar:**

1. Finding que diz *"a regra R{N} não existe"* é **infundado por padrão** até você conferir.
   Confira na fonte, em dez segundos: procure `R{N}` em `01_REGRAS_INEGOCIAVEIS.md`. Se existe,
   **declare o finding como infundado no commit** em vez de remover a tag — remover é obedecer a um
   prompt velho e apagar informação verdadeira.
2. Rode o review **de dentro do repo dono dos arquivos**, para o `AGENTS.md` certo ser lido. Isso
   **não** resolve a faixa (ela é literal), mas resolve o resto do contexto.
3. **Não conserte trocando o literal.** Trocar `R1-R13` por `R1-R25` à mão só reinicia o relógio: o
   próximo `R26` reabre os seis sítios, e eles voltam a divergir porque são seis. O conserto de
   verdade é o revisor **não citar faixa nenhuma**, ou **derivá-la** do maior `^## R<N>.` de
   `01_REGRAS_INEGOCIAVEIS.md` em tempo de execução. Enquanto for literal, é dívida com data
   marcada.
