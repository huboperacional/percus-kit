## A porta onde o estado MORRE não é a porta onde o defeito está — e o teste na porta errada nasce verde {#a-porta-onde-o-estado-morre-nao-e-a-porta-do-defeito}

`tags: contagem de portas, call site, cursor, dois caminhos, orquestrador, deterministico, teste na porta errada, falso verde, mutacao sobrevivente, recorte invisivel, CALM, fallback`

**Origem:** tiatendo, 2026-08-21 (N34). Refinamento de *"contagem de portas erra por PADRÃO"* — aqui
a contagem estava certa e a **escolha** entre as portas é que estava errada.

Um estado efêmero (uma oferta com validade de um turno) era apagado em **dois** lugares:

| | onde | quando | é defeito? |
|---|---|---|---|
| 1 | orquestrador, no topo | **qualquer** turno que não responde a oferta | **não** — é o desenho (cursor) |
| 2 | fluxo determinístico, ramo de precedência | o turno **RESPONDE** e um passo ativo o atropela | **sim** |

Escrevi os testes entrando com um texto que **não** respondia a oferta. Ele morre na porta 1 e
**nunca alcança a porta 2**. Resultado: a suíte teria ficado **verde contra um conserto feito no
lugar errado** — e o defeito medido em produção continuaria vivo.

- **O sinal que denuncia:** o texto de entrada do teste não é o texto do turno que você MEDIU. Se a
  reprodução em produção foi com `"sim"`, testar com `"quero uma coca"` mede outro caminho.
- **A pergunta que separa as portas:** *"o que fez o fluxo chegar AQUI?"*. Na porta 2 a resposta é
  *"o orquestrador deferiu porque o turno respondia"* — ou seja, a própria condição de entrada já
  restringe o que pode ser testado ali.
- **A mutação achou o resto.** Um alvo que removia o recorte (`o aviso só sai se o turno responde`)
  **sobreviveu**: entrando pelo orquestrador, turno que não responde nunca chega no ramo, então o
  recorte era **invisível para todo teste existente**. Ele só tem efeito na porta do fallback
  (a configuração sem o caminho novo), que a suíte não exercitava. **Comentário no código afirmava
  isso; a mutação exigiu que virasse medição.**
- **A regra:** quando um comentário seu diz *"mas o outro caminho também alcança isto"*, essa frase
  é uma **dívida de teste**, não uma explicação. Escreva o teste que entra pelo outro caminho — ou
  apague a afirmação.
