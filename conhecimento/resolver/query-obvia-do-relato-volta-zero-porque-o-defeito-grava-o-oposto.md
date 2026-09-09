## A query óbvia do relato volta ZERO porque o defeito grava o estado OPOSTO {#query-obvia-do-relato-volta-zero-porque-o-defeito-grava-o-oposto}

`tags: debugging, relato, produção, query, reprodução, ausência de população, schema divergente`

**Sintoma:** o relato descreve o que o usuário viu (*"o sistema não pede o endereço quando escolho
entrega"*), você traduz direto em SQL (`WHERE tipo='entrega' AND endereco IS NULL`) e o resultado é
**zero linhas**. A tentação é declarar "não reproduz" e devolver o relato.

**O que está acontecendo:** um defeito de ESTADO costuma produzir um registro **coerente e válido do
estado errado** — não um registro inválido do estado certo. No caso medido, o pedido era gravado
como *retirada*; aí o endereço **corretamente** não é pedido, e a validação (que existia e era
sólida em três camadas) nunca chegava a rodar. Procurar pelo "registro quebrado" pressupõe que o
fluxo chegou até a validação — e o defeito é exatamente não ter chegado.

**O que fazer, nesta ordem:**

1. **Procure a ausência de uma POPULAÇÃO inteira, não a presença de linhas ruins.** Foi o que
   fechou o caso: *"este canal não produz um pedido de entrega há 7 semanas"*, numa modalidade que
   existe e é oferecida. Ausência de população é sinal forte; linha ruim é sinal fraco, e some
   justamente quando o defeito grava algo válido.
2. **Compare caminhos/canais entre si na mesma janela.** Todas as entregas vinham de um canal e
   nenhuma do outro — a assimetria apontou o arquivo antes de qualquer leitura de código.
3. **Antes de filtrar por uma chave do JSON, descubra quantos SCHEMAS aquela coluna tem.** A mesma
   coluna guardava `{bairro,street}` de um produtor e `{raw,validated}` de outro; a primeira
   filtragem por `street` marcou linhas boas do schema antigo como defeituosas. Falso positivo do
   investigador, não do sistema — e ele contamina o diagnóstico se não for declarado.

🪤 **Corolário medido no mesmo caso: comentário que promete comportamento inexistente sobrevive a
correções inteiras.** Uma função trazia `// herda o toggle do topo` e não herdava nada; uma correção
anterior passou ao lado porque quem leu acreditou no comentário. Vale escrever um teste que falhe
enquanto a promessa não tiver lastro — e ele é útil de verdade: pegou o próprio autor quando ele
repetiu a frase antiga ao explicar que ela tinha saído.

Ver também [[ausencia-numa-tabela-so-e-prova-se-o-produtor-escreve-nela]].
