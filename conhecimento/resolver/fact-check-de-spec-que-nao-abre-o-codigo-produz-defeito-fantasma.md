## Fact-check de spec que não abre o CÓDIGO produz defeito FANTASMA {#fact-check-de-spec-que-nao-abre-o-codigo-produz-defeito-fantasma}

`tags: conselho, spec-analyze, fact-check, defeito-fantasma, R11, R20, 5-T, frente-filha`

**O sintoma**

O conselho (`spec-analyze`) devolve um **`CRITICAL`** sobre lógica: *"este par de requisitos cria um
loop — o terminal X é inalcançável"*. Você faz o fact-check **relendo a spec**, a contradição está
mesmo lá no texto, você **confirma** e escreve requisitos novos para consertá-la.

**O defeito não existe.** A spec era ambígua; a implementação nunca foi.

**O caso (tiatendo, 24/08/2026) — 4 rodadas, 6 achados fantasmas**

Frente `N36`, **`[5-T]` provada em produção**. Quatro rodadas de `analyze` (8-11) sobre a spec dela.
A rodada 8 acusou *"o terminal 'escala' é inalcançável"*. Fact-check contra a spec: **confirmado**.
Nasceram 3 requisitos novos, um requisito reescrito e uma spec-filha inteira.

Depois a **review R11** abriu o `.py`:

| "defeito" | realidade, com `arquivo:linha` |
|---|---|
| oferta viva não vence / não congela | **já existia**, com comentário explícito e **teste verde** |
| 3º pedido de fechar sem requisito | **já existia** (uma flag de congelamento) |
| ramo terminal não limpa contadores | **já existia** |
| *"3 de 5 classes de evento são inalcançáveis"* | **FALSO** — o evento é emitido **no topo** da função, **antes** do portão de incremento, e há teste parametrizado com uma das classes "inalcançáveis" |
| requisito novo sobre o gate de fechamento | **premissa errada** — outro gate intercepta antes, o fluxo nunca chega ali |
| subtrair 4 palavras do conjunto de afirmação | **quebraria um invariante** — o conjunto é COMPARTILHADO com outra família |

**Sobrou verdade em 3 itens pequenos** de 6. E o requisito criado para fechar o `CRITICAL` fantasma
**escalaria o cliente que respondeu certo** — fogo amigo que nenhuma das 4 rodadas viu.

**Por que acontece — e não é burrice do conselho**

**As pernas do `analyze` recebem UM arquivo: a spec.** Elas julgam o texto **por dentro**, coerente
consigo mesmo — é literalmente o trabalho delas. Ambiguidade no texto é indistinguível, dali, de
defeito no produto.

🔑 **O erro é do fact-check, não do conselho.** O R20 existe para impedir que o conselho ratifique
alegação não verificada — e reler a spec **não é verificação**, é a mesma leitura de novo. Quatro
rodadas independentes concordaram porque **todas liam a mesma fonte**.

**A regra**

> **`CRITICAL`/`HIGH` de `analyze` sobre COMPORTAMENTO só é confirmado abrindo o código.**
> Reler a spec confirma que o **texto** é ambíguo — que é achado de **redação**, não de produto.

**Obrigatório abrir o código quando o achado afirma que o sistema:**
faz / não faz · alcança / não alcança um estado · entra em loop · nunca emite algo · contradiz
outro requisito **em execução**.

**Dispensa código** (é achado de texto, e aí sim relê-se a spec): termo não definido, requisito sem
critério de pronto, vazamento WHAT→HOW, terminologia inconsistente.

**Como fazer, em 2 minutos:** `grep -n` pelo símbolo/fala do requisito → leia a função inteira, não
a linha → **procure o teste** que a cobre. Teste verde nomeando o comportamento é a prova mais
barata de que o "defeito" não existe.

**O agravante: se a frente está `[5-T]`, o estrago é na TAG**

**Spec de frente `[5-T]` é REGISTRO DO QUE ESTÁ NO AR.** Aplicar achado novo ali dentro converte,
**em silêncio**, uma tag de *"provado em turno real"* em *"aspiracional"* — e só percebe quem
conferir a evidência contra o texto **requisito a requisito**.

- Achado que descreve o que **já roda** → documente na spec-mãe, **com `arquivo:linha`**.
- Achado que pede comportamento **novo** → **frente-filha** ou achado na lista de pendências.
  **Nunca** emenda na mãe.

**E a lição sobre os instrumentos**

**O conselho não substitui a review.** `analyze` julga a spec **por dentro**; a review olha o
**diff contra o estado do projeto**. Aqui, 4 rodadas de conselho não viram o que a primeira review
viu — porque a pergunta *"este documento ainda descreve a produção?"* **não é uma pergunta sobre o
documento**.

🪤 **Corolário do split de specs:** quando a spec é partida para caber no teto de prompt, a perna só
enxerga a metade que você mandou — e reporta o que está na outra metade como *"nunca definido"*. No
caso, o mesmo `MEDIUM` reapareceu em **3 rodadas seguidas**, por 3 ângulos, sempre sobre algo que
estava no arquivo companheiro.

**Ref:** R11 (review cross-provider), R20 (nada de ratificar alegação não verificada), R23,
ADR-0015 do tiatendo (tag de frente de pipeline).
