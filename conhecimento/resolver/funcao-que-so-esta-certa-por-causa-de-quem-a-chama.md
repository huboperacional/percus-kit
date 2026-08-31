## Função que só está certa por causa de QUEM A CHAMA mente quando lida isolada {#funcao-que-so-esta-certa-por-causa-de-quem-a-chama}

`tags: predicado, guarda, ordem dos gates, call site, precedencia, funcao pura, teste de funcao, teste de call site, acoplamento invisivel, armadilha pro proximo leitor, deteccao, classificador`

**Sintoma:** um predicado passa em todos os testes, o turno sai certo em produção, e mesmo assim a
função **devolve a resposta errada** quando alguém a chama de outro lugar. Ninguém percebe, porque
todo teste existente exercita o CALL SITE, onde um gate anterior já filtrou os casos que ela erra.

**A forma abstrata:** a função é correta **só dentro de uma ordem de execução**. Um gate anterior
consome os casos em que ela erraria, então o erro é inobservável — até que a função seja reusada,
reordenada, ou testada sozinha. O acoplamento não está no código: está na **sequência**, que
nenhuma assinatura declara.

**Caso medido (tiatendo, N22, 2026-08-31):** `looksLikeExistingOrderTalk` devia responder *"esta
frase fala do pedido que JÁ existe?"*. Ela devolvia `True` para `"quero um pedido"` — pedido NOVO,
resposta errada. Não quebrava nada porque, no call site, `looksLikeOrderIntentOnly` rodava **antes**
e já tinha devolvido o convite para esse caso. O teste de call site passava; o de função não
existia. A review externa só achou porque testou a função **sozinha**.

**Como isso nasce:** você escreve a função DEPOIS do gate que já existe, e desenha a regra para "o
que sobra". "O que sobra" é uma definição relativa à ordem, não ao domínio — e some no primeiro
refactor, no primeiro reuso e no primeiro teste unitário.

### O que fazer

- **Escreva um teste da FUNÇÃO, isolada, para os casos que o gate anterior filtra.** É barato e é o
  único que pega. Se você não consegue afirmar o que a função deve responder sem citar quem a
  chama, a regra ainda não está escrita.
- Faça a regra ser do **domínio**, não da posição: em vez de "o que sobra depois do convite", diga
  "substantivo X com determinante Y". No caso medido, a correção foi mover a decisão do regex
  (onde ela dependia de qual verbo o stripper tinha comido antes) para o corpo da função, com o
  discriminante explícito.
- Suspeite quando o docstring precisar da palavra **"depois"** para explicar a correção: "só é
  consultada depois que X disse não" é a assinatura desta classe.

### Contra-prova

Mutação que **inverte a ordem dos gates** no call site, ou simplesmente um teste unitário da função
com os casos que o gate anterior engole. Se a suíte inteira segue verde com a ordem trocada, a
função está carregando um acoplamento que ninguém declarou.

**Parente:** [funcao-que-responde-duas-perguntas-tem-status-load-bearing](funcao-que-responde-duas-perguntas-tem-status-load-bearing.md)
— lá o problema é a função ter dois leitores com perguntas diferentes; aqui é ter **um** leitor cuja
ordem a função silenciosamente assume.
