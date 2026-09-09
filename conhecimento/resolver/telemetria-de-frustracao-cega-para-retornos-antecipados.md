## Telemetria de frustração cega para retornos antecipados: o caminho rápido é o bem-resolvido, e o dashboard fica bonito pela pior razão {#telemetria-de-frustracao-cega-para-retornos-antecipados}

`tags: telemetria, vies de selecao, fast-path, retorno antecipado, detector de frustracao, bot conversacional, diario de turno, saida unica, teste de mutacao, grupo de estudos`

**Sintoma:** a métrica de insatisfação do bot não quebra e não dispara; ela só descreve um mundo melhor
que o real. Ninguém percebe porque um número que existe parece um número que mede.

**Causa raiz, medida em 2026-09-06 em dois projetos:** o detector de frustração (`detectInsatisfacao`
+ `registrarFrustracao`) mora dentro do despachante de texto, e o pipeline tem **retornos antecipados
que respondem ao usuário antes dele**: na Família Milionária, 9 `return`s entre o início de
`_processMessage` e a chamada do despachante (card de confirmação aberto, flush do debounce, usuário
desconhecido, mídia que falhou, senha de PDF, onboarding); na Empresa Milionária, 6. Zero menções a
frustração nesses trechos (awk sobre a faixa de linhas). Cada porta de saída é uma decisão que ninguém
tomou explicitamente.

🔑 **Não é "um fast-path esqueceu de instrumentar": é viés de seleção embutido na arquitetura.** O caminho
rápido é o caminho bem-resolvido; toda métrica colhida depois dele descreve só o subconjunto pior
atendido pelo roteamento lento. E o caso contraintuitivo: **quem responde "errado" a um card de
confirmação está no pico da frustração e é tratado antes do detector**. O momento de maior sinal de
insatisfação é o que menos chance tem de ser registrado, justamente porque é o mais bem atendido.

**Como achar no seu projeto (dois greps):** (1) onde o detector é chamado; (2) `return` que envia
resposta (`send`, `sendMessage`, `_sendAndLog`) em linhas ANTERIORES a essa chamada, na mesma cadeia.
Procure pelo **`return` cedo**, não pela ausência da chamada: o adaptador da Empresa chamava o registro
e mesmo assim retornava antes dele.

**Solução que fecha a classe (não a instância):** emitir o registro no **ponto de saída único** por
onde toda resposta passa (o `_sendAndLog`/dispatcher de envio), nunca dentro de handler; um diário de
turno com `caminho`, `desfecho` (enum fechado) e `retorno_antecipado`. Critério mecânico: **teste de
mutação em que um `return` novo antes da saída não some do diário**. Remendar cada retorno antecipado
conserta os 9 de hoje e deixa o 10º nascer cego.

⚠️ **Corolário para qualquer métrica de qualidade de conversa:** antes de confiar em um número, pergunte
quantas portas de saída existem antes do instrumento. Se a resposta é "não sei", o número está errado
para o lado bonito.

Relacionado: [codigo-morto-plausivel-com-teste-verde-parece-vivo](codigo-morto-plausivel-com-teste-verde-parece-vivo.md)
(a mesma pergunta "quem chama isto, e esse caminho roda em produção?", aplicada ao instrumento em vez
de ao código).
