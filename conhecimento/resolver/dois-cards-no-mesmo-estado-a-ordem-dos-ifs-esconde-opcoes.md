## Dois cards no MESMO estado de sessão: a ordem dos `if` decide quais opções existem {#dois-cards-no-mesmo-estado-a-ordem-dos-ifs-esconde-opcoes}

`tags: menu numerado, estado de sessao compartilhado, ordem dos if, opcao inalcancavel, card de escolha, flag no contexto, resolvedor por ultimo, duplicata, escrita duplicada, hoisting`

**Sintoma.** O card diz *"Qual item deseja atualizar? Responda com o número"*. O usuário responde
`1` e, em vez de atualizar o item 1, **ganha uma linha nova duplicada**. Responder `2` re-emite o
mesmo card, em loop. Responder `3` cancela. Só as posições 4 e 5 fazem o que o card promete.

**Causa raiz.** Uma única função serve **dois cards diferentes** sob o **mesmo** estado de sessão,
distinguidos apenas por uma flag no contexto (`aguardando_selecao_X`). E o resolvedor do card
numerado era o **último** `if` da cadeia. O vocabulário do primeiro card (`"1"` = criar novo, `"2"` =
atualizar, `"3"` = cancelar) **cobre** os números que o segundo card oferece, e intercepta todos
antes que cheguem ao resolvedor certo.

Com um `limit(5)` na busca de candidatos, o resultado é aritmético: das 5 posições possíveis, **3
são sequestradas e só 2 são alcançáveis** — e ninguém percebe, porque cada resposta *faz alguma
coisa*, só que a errada.

**Por que a cobertura não pega.** Teste que chama o handler já dentro do ramo certo passa verde: o
defeito é de **ORDEM**, não de matcher. Só um teste que entre pelo dispatch real, com o card
efetivamente na tela, vê o desvio.

**Solução.** Suba o resolvedor do sub-menu para o **topo** da função, guardado pela **FLAG** — nunca
pelo texto da resposta, porque o texto é exatamente o que colide. O card anterior continua lendo
`"1"` como a opção dele enquanto a flag estiver desligada. E **apague a cópia morta** que ficou
embaixo: duas cópias do mesmo resolvedor no mesmo arquivo é o próximo leitor consertando a errada.

```python
# ANTES: resolvedor numerado por último -> "1" nunca chegava nele
if texto == "3" or is_negative(texto): ...      # menu A
if texto == "1" or is_affirmative(texto): ...   # menu A  <- engolia o "1" do menu B
if texto == "2": ...                            # menu A
if ctx.get("aguardando_selecao"): ...           # menu B  <- inalcançável pra 1,2,3

# DEPOIS: a FLAG decide qual card está na tela, e ela é consultada primeiro
if ctx.get("aguardando_selecao"):
    ...  # menu B resolve, com o cancelar avaliado antes do parse numérico
    return
if texto == "3" or is_negative(texto): ...      # menu A
```

**Como achar irmãos.** Procure o mesmo literal de estado em mais de um `upsertSession` do mesmo
arquivo, ou uma flag booleana no contexto decidindo qual card está na tela. Onde houver duas cards
por estado, a ordem dos `if` é contrato — e contrato que ninguém escreveu.

Ver também [[card-promete-resposta-que-ninguem-le]] (a face gêmea: a copy promete forma que o
matcher não lê) e [[caso-ancora-da-ausencia-passa-por-merito-do-bug]].
