## Conselho acerta a conclusão e erra a premissa {#conselho-acerta-a-conclusao-e-erra-a-premissa}

`tags: conselho, cross-provider, fact-check, maioria 2/3, alucinacao, premissa falsa, R11, revisao, divergencia declarada`

**Contexto:** conselho de 3 provedores sobre uma decisão de implementação. Maioria clara numa
opção — e a **razão** dada pela maioria não sobrevive a trinta segundos de conferência no código.

**O caso que gerou o verbete:** perguntado como evitar deadlock ao travar N recursos numa
transação, 2 de 3 escolheram "ordenar o laço" e um deles justificou descartando a alternativa com
*"pré-travar é redundante, o caso de uso já faz `FOR UPDATE` por item"*. A frase é verdadeira e a
conclusão dela é invertida: travar por item **na ordem do corpo** é justamente a **origem** do
deadlock. A maioria acertou que ordenar resolve; errou ao afirmar que a outra opção não fazia nada.

**Por que acontece:** o conselho vê **texto**, não código. Ele reconhece o padrão ("já existe
lock, logo lock extra é redundante") e o aplica sem simular a concorrência. É o mesmo mecanismo do
incidente de ratificação de alegação falsa: três provedores concordando sobre uma premissa que
nenhum deles verificou é **um palpite repetido três vezes**, não três evidências.

**Como usar sem se machucar:**

- **Separe conclusão de razão** ao ler cada perna. Contar votos na conclusão e ignorar a
  justificativa é o que faz maioria virar carimbo.
- **Fact-check é sobre a premissa, não sobre a opinião.** Toda afirmação factual do conselho
  (*"o código já faz X"*, *"esse campo é opcional"*, *"essa rota devolve 404"*) é conferível em
  segundos, e é onde ele erra.
- **Divergir de 2/3 é legítimo — declarando.** Quando a razão da maioria cai no fact-check, a
  maioria perdeu o peso que a tornava maioria. O que **não** é legítimo é divergir em silêncio:
  escreva no código e no commit qual foi a contagem, qual foi a razão da maioria e por que ela não
  se sustentou. Sem isso, a próxima sessão relê o log do conselho e "corrige" de volta.
- **Finding refutado também se registra.** Um membro apontou vazamento multi-tenant que não
  existia — o filtro de tenant já estava dentro da consulta. Registrar a refutação com o
  arquivo/linha impede que o mesmo finding volte na rodada seguinte e vire código defensivo contra
  um problema imaginário.

**Contraponto que continua valendo:** convergência de 3/3 num ponto que **nenhum** deles precisou
inventar (*"esta decisão está em aberto e trava o requisito"*) é sinal forte — porque é uma
observação sobre o texto que você mesmo escreveu, não sobre um código que eles não viram.

Ver também [[conselho-contexto-incompleto]], [[perna-conselho-nao-e-perna-morta]],
[[deadlock-por-ordem-de-lock-em-lote-do-corpo]].
