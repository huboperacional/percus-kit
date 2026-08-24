## O fator de vencimento do boleto ESTOUROU em 22/02/2025 — a fórmula de sempre erra por 24 anos e ninguém reclama {#fator-de-vencimento-do-boleto-estourou-em-2025}

`tags: boleto, fator de vencimento, linha digitavel, codigo de barras, FEBRABAN, rollover, data-base 1997, data-base 2022, modulo 10, modulo 11, arrecadacao, convenio, DV, vencimento errado, dominio fiscal brasileiro`

**Sintoma:** o decodificador de boleto lê o vencimento e devolve uma data no passado — tipicamente **2002 ou 2003** — para um boleto que vence nas próximas semanas. Nada estoura: o valor sai certo, o banco emissor sai certo, os dígitos verificadores conferem, e a data é uma data válida. Só está errada por cerca de **24 anos e meio**. Em sistema que lança contas a pagar, isso vira título vencido há duas décadas, fora de qualquer janela de competência, e provavelmente filtrado da tela onde alguém veria o erro.

**Causa raiz:** o campo do fator de vencimento tem **4 dígitos** e conta dias corridos desde uma data-base. A data-base original é **07/10/1997**, e o campo ia de `1000` a `9999`. `1997-10-07 + 9999 dias` é **21/02/2025** — o campo acabou. A FEBRABAN definiu que em **22/02/2025** o fator volta a `1000`, com data-base nova **29/05/2022** (confira: `2022-05-29 + 1000 dias` = **2025-02-22**, exatamente o dia seguinte; as duas eras são **contíguas**, sem buraco e sem sobreposição).

Toda implementação escrita antes de 2025 — e todo modelo de linguagem que a reproduza de memória — usa `1997-10-07 + fator`. Para todo boleto **emitido de 22/02/2025 em diante**, isso está errado. Ou seja: para todo boleto que um cliente manda hoje.

**As duas datas-base distam exatamente 9000 dias.** É por isso que o erro é sempre o mesmo tamanho, e é o que dá o desempate abaixo.

**Fix — a fórmula é `base + fator` nas DUAS eras.** O que muda é só a data-base, nunca a aritmética. Um erro fácil aqui é escrever `base2 + (fator - 1000)`, subtraindo os 1000 duas vezes; ele produz uma data plausível e passa despercebido. O guarda que o pega é afirmar que as duas leituras distam **9000 dias** e que as eras são contíguas — se a sua conta não fecha esses dois números, ela está errada.

**Desempate, porque 4 dígitos não dizem de que era são:** depois de 22/02/2025 vale a era de 2022, **exceto** quando ela joga a data muito longe no futuro (uns 5 anos serve) — aí o fator é alto e o boleto é da era antiga, que é o caso do documento atrasado que o cliente manda para lançar. Como as duas leituras distam 9000 dias fixos, **nunca cabem as duas na mesma janela plausível**. Devolva a leitura alternativa junto com a escolhida, para a interface poder oferecer a correção em vez de o sistema fingir certeza.

**`fator = 0000` significa SEM VENCIMENTO**, não 07/10/1997. Boleto de valor aberto também existe: `valor = 0` é "sem valor informado", não R$ 0,00. Nos dois casos, devolver o zero como se fosse fato é o defeito.

**Arrecadação (convênio) NÃO é cobrança, e o DV diverge exatamente onde ninguém testa.** Linha de cobrança tem **47** dígitos; a de arrecadação, **48**, e começa com `8`. No layout de arrecadação o dígito verificador é módulo 10 **ou** módulo 11 conforme o **3º dígito** (identificador de valor). E o módulo 11 de arrecadação tem regra de resto própria, na letra do layout oficial: *"quando o resto for 0 ou 1, o DV é `0`; quando for 10, o DV é `1`"* — em cobrança esses mesmos restos dão `1`. Unificar as duas funções "porque são parecidas" quebra só nesses restos, que é o que quase nenhuma fixture cobre.

**Não discrimine cobrança de arrecadação pelo conteúdo dos dígitos.** Na linha digitável, o **comprimento** (47 × 48) já resolve. No código de barras, onde ambos têm 44, despache pela **validação do DV**: tente uma, caia para a outra, recuse se nenhuma fechar. Heurística de prefixo depende de saber quais códigos COMPE existem hoje e quais o Banco Central vai alocar amanhã.

**Como ancorar sem inventar fixture:** uma linha real de boleto passa em **quatro** dígitos verificadores independentes (três por módulo 10, um por módulo 11). Acertar os quatro por acaso é 1 em 10.000, então uma única linha real ancora as duas funções contra o mundo. Fixture "de exemplo" construída sem calcular os DVs passa no código errado e no certo — não prova nada. O layout oficial da FEBRABAN traz exemplos numéricos **resolvidos** para arrecadação, e é de onde tirar os casos de borda do resto.

**Ref:** Empresa Milionária, `empresa-api/app/modules/whatsapp/boleto.py` (2026-08-24). Layout Padrão FEBRABAN de Arrecadação v7 (01/03/2023). Verbete irmão sobre leitura de dinheiro: [parser-de-dinheiro-assume-locale](parser-de-dinheiro-assume-locale.md).
