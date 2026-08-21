## Contagem de portas erra por padrão — só vale enumerada e re-contada por outro {#contagem-de-portas-erra-por-padrao}

tags: call site, guarda, costura, alcance, quantos lugares, grep addItem, spec, conselho, cross-review, guard inerte, porta do cliente, N24, mutacao

**Sintoma:** a guarda foi implementada, revisada e testada, os testes ficam verdes — e ela
simplesmente **não roda** num dos caminhos vivos. O diff parece coerente, ninguém vê nada errado, e
o defeito volta pela porta que ninguém contou.

**Causa raiz:** contar call sites é a operação em que a intuição mais falha, porque o cérebro conta
as portas **do desenho que está na cabeça**, não as do código. E o erro é **invisível na review**:
não há linha errada para apontar, só uma ausência.

**Medido em uma única sessão** (tiatendo, 2026-08-20): **quatro** afirmações de "são N portas",
**três erradas**, todas por gente diferente e todas com o código na mão.

| quem | afirmou | era | como caiu |
|---|---|---|---|
| autor da spec | "os pontos de mutação são **2**" | **8** | `grep -n "addItem("` de um revisor |
| revisor cross-model | "contei **6**" | **8** | o grep do autor, depois |
| autor da spec (v3) | "**3** pontos de guarda" | **4** | o implementador, ao ver o bug antigo voltar |
| autor de outra spec | "**7** portas do matcher" | **7** ✅ | conferido linha a linha por revisor independente |

A única que sobreviveu foi a que já vinha **enumerada linha a linha no documento** e foi
**re-contada por outra pessoa**.

**Solução:**

1. **Nunca escreva "são N portas" sem colar o comando e a LISTA que ele produziu.** Número sozinho
   não é verificável e apodrece na primeira frente que adiciona um call site.
2. **Peça a contagem a quem não escreveu a afirmação.** Foi o que pegou as três.
3. 🔑 **A pergunta certa não é "quantos call sites?" — é "qual é a porta do CLIENTE?"** No caso
   medido, o tenant de produção tinha um gerador LLM ligado, então o turno real entrava por um
   handler **paralelo** ao que a spec inteira descrevia. O conserto teria ficado **inerte para o
   único tenant em produção**, com todos os testes verdes.
4. **Prefira desenho que não exija enumerar.** Guarda em **entrada de fase** (lista estável) vence
   guarda replicada em **sítios de escrita** (lista que cresce a cada frente). Se o desenho obriga a
   repetir a guarda em 8 lugares, o desenho está errado: ela vai ficar inerte em um deles.
5. **Indexe por NOME DE FUNÇÃO, não por número de linha.** Na mesma sessão, os números de linha de
   uma spec envelheceram **~449 linhas** em horas, porque uma frente paralela mexeu no arquivo.
6. **A mutação pega o que a review não pega.** Uma das guardas "novas" era **código morto** — usava
   um predicado cujo pré-gate era `False` exatamente naquele ponto. Passou pela review humana e
   morreu no alvo de mutação.

**Ver também:** [[mutacao-sobrevive-por-guarda-redundante]],
[[estado-atual-nao-prova-evento-passado]].
