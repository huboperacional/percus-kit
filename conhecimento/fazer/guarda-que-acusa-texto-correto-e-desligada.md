## Guarda que acusa texto correto não é guarda rigorosa — é guarda que ensina a equipe a afrouxar guardas {#guarda-que-acusa-texto-correto-e-desligada}

`tags: guarda estatica, varredura, regex, falso positivo, teste de texto, xfail, disciplina de teste, drift, TDD, comentario`

**Quando:** você está escrevendo uma **guarda de varredura** — um teste que lê arquivos e reprova
quando encontra um padrão (preço morto, nome de produto herdado, slogan revertido, promessa de
função que não existe).

**A regra:** um padrão que reprova texto **correto** custa mais do que a cobertura que ele dá. Ele
não é pego como bug — é pego como "a guarda é chata". E o conserto que a equipe aplica não é
melhorar o padrão: é **enfraquecer a guarda**, ou pular ela. A próxima a ser afrouxada será uma que
importava.

**Caso real (2026-08-23):** ao guardar o slogan de uma decisão de preço revertida, o padrão mais
óbvio era `eixo de preço …{0,40} CNPJ` — é como a decisão antiga se descrevia. Escrito, acusou
**três textos corretos**: a frase nova que anunciava o eixo novo, o comentário que explicava a
reversão e o comentário do CSS que justificava o layout novo. Todos diziam que o eixo **mudou** — e
o padrão não distingue *"é X"* de *"deixou de ser X"*, porque **a distinção mora no verbo**, não nas
duas palavras que ele casava. Foi removido, com o motivo escrito no próprio arquivo de teste.

**Como escolher o padrão:**

1. **Prefira afirmações no presente.** *"o preço é por CNPJ"* só aparece em texto errado; *"eixo de
   preço … CNPJ"* aparece em texto certo e errado.
2. **Desconfie de homônimo técnico.** `família` reprovou um comentário sobre **família de fonte**;
   `relatório` tem dois usos legítimos (mensagem proativa e relatório de indicações do programa de
   afiliados). Nesses casos, ou **narre o padrão** (proximidade com outra palavra: `painel …
   relatório`) ou **restrinja a forma** (só possessivo e plural: `sua família`, `famílias`).
3. **Rode o padrão ANTES de acreditar nele.** A lista de ofensores é a revisão do padrão: se houver
   texto correto ali, o padrão está errado — não o texto.
4. **Declare a recusa no arquivo.** O padrão que você *não* usou, e por quê, vale mais que o que
   você usou: é o que impede a próxima pessoa de reintroduzi-lo achando que faltava cobertura.

**Varrer comentário: sim, e assumindo o custo.** Número e slogan mortos em comentário são o rascunho
de onde alguém copia para dentro da tela — e distinguir comentário de código estaticamente é frágil.
Mas a decisão tem preço: você vai bater na própria guarda ao escrever a explicação histórica. A
saída é **descrever o que o texto dizia, em vez de transcrever**. Escreva isso na docstring da
guarda: sem a instrução, a próxima pessoa acha que é bug.

**Limite que se declara, não se esconde:** guarda estática não distingue rótulo de substantivo. Um
chip de UI com a palavra sozinha, sem contexto por perto, **não é pego** — e foi assim que um rótulo
sobreviveu até a leitura manual. Escreva o limite no arquivo; guarda com limite escrito é guarda em
que se confia.

Ver também, em `conhecimento/resolver/`: **o-screenshot-pega-o-que-a-guarda-nao-ve**.
