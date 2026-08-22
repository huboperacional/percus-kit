## Discriminador de smoke estreito demais confunde a rota IDEAL com "a mensagem não chegou" {#discriminador-de-smoke-estreito-confunde-rota-ideal-com-silencio}

`tags: smoke, discriminador, inconclusivo, prova positiva, prova por ausencia, classificador nao deterministico, roteamento, veredito, bloqueio, diagnostico`

**Contexto:** smoke cujo veredito é uma **ausência** ("nada foi escrito") precisa de uma **prova
positiva** na mesma rodada, senão "o produto se comportou" fica indistinguível de "a mensagem nunca
chegou". A defesa padrão é exigir um rastro específico — um log de recusa, uma linha de auditoria. O
erro sutil é escolher um rastro **estreito demais**: um que só existe em UM dos desfechos corretos.

**O caso medido (2026-08-22):** um smoke mandava a frase de um incidente antigo e exigia, como prova
positiva, a linha de **recusa do portão de escrita**. Em 3 de 5 rodadas o veredito veio
`INCONCLUSIVO`. Investigando: o classificador havia roteado a frase para uma **consulta** — o bot
respondeu *"contas pendentes até hoje: ..."*, que é o **melhor desfecho possível**, uma camada antes
do portão. Não havia decisão de portão a registrar porque o portão nem precisou opinar. O smoke
marcava o melhor caso como "não medi".

**Por que dói:** `INCONCLUSIVO` bloqueia igual a falha (e deve mesmo). Então o melhor desfecho do
produto passa a **barrar o deploy**, de forma intermitente, com um diagnóstico que aponta para o lugar
errado ("a frase não alcançou o portão" — alcançou o que devia alcançar).

**Correção — a âncora continua sendo um positivo, mas o conjunto de positivos é o de TODOS os
desfechos corretos:**

```python
if escritas:                      # escrita indevida continua FALHA, e vem primeiro
    registrar(FALHA, ...)
elif recusaDoPortao(desde):       # desfecho A: o portão avaliou e recusou
    registrar(PASS, ...)
elif respostaDeLeitura(resp):     # desfecho B: virou consulta — melhor ainda
    registrar(PASS, ...)
else:                             # nem um nem outro: aí sim, não mediu
    registrar(INCONCLUSIVO, ...)
```

**O que NÃO pode afrouxar:** o ramo de escrita indevida continua sendo FALHA e continua vindo
primeiro; e **silêncio** (nenhuma resposta na janela) continua `INCONCLUSIVO`. A propriedade de
segurança é a mesma; o que mudou é o smoke passar a reconhecer o segundo desfecho legítimo.

**Como escolher o positivo de leitura sem cair em prova por ausência:** liste os **cabeçalhos
próprios** dos cards de leitura do produto ("contas pendentes", "resumo —", "situação de", "tudo em
dia"). Marcadores específicos provam que a frase foi entendida como pergunta e respondida como
pergunta. Um `not pareceEscrita` seria ausência outra vez — exatamente o que o discriminador existe
para não aceitar.

**Regra para escrever o discriminador desde o começo:** antes de armar, pergunte *"quantos desfechos
CORRETOS esta frase tem?"*. Se a resposta for mais de um — e com classificador vivo no caminho quase
sempre é —, o discriminador precisa reconhecer todos, ou vai reprovar o produto por variação de rota.

**Ver também:** [[smoke-certo-mas-caminho-nao-rodou]] · [[smoke-degradado-vs-errado]] ·
[[smoke-verde-pode-nao-ter-exercitado-a-guarda]]
