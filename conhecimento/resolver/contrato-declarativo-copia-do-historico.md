## Contrato que manda o LLM REPETIR o estado inteiro copia da fonte errada quando há histórico {#contrato-declarativo-copia-do-historico}

`tags: llm, contrato declarativo, histórico, janela de contexto, alucinação, prompt, medição, isolar variável, recorte por tempo, lastro`

**Sintoma:** um contrato declarativo ("devolva o estado desejado COMPLETO, repetindo o que
permanece") passa a inventar itens quando a janela de contexto tem histórico de conversa. Um "oi bom
dia" cria um pedido de 3 itens; uma frase de encerramento adiciona um produto.

**Causa:** o prompt tem DUAS fontes do estado — o bloco estruturado autoritativo (`PEDIDO ATUAL:
(vazio)`) e as mensagens anteriores, onde o próprio bot RECITOU o estado ("Seu pedido: 1× X — R$ 80").
A instrução "repita o que permanece" não diz de ONDE repetir, e o modelo resolve a contradição
copiando do texto conversacional. Se a busca de histórico não tem recorte de TEMPO, a sessão de
ontem entra na janela de hoje.

**Como medir (isole UMA variável):** mesmo turno, mesmo estado, N rodadas, variando só o histórico.

    history=None            3/3 correto
    history=COMPLETO        3/3 alucina
    history=SÓ DO USUÁRIO   3/3 alucina — e de forma ESTÁVEL

🪤 **Filtrar por PAPEL não resolve, e engana.** As mensagens do usuário são justamente as que
NOMEIAM as entidades; tirar as do bot deixa o resultado determinístico, o que num teste parece
*mais estável* e continua 100% errado. O que resolve é o recorte por TEMPO, ancorado na vida do
objeto em edição (o rascunho/sessão), não num número de mensagens.

🪤 **Recorte por tempo não cobre o caso da MESMA sessão.** Se a alucinação nasce de um histórico de
minutos atrás, nenhum recorte razoável a remove — só uma guarda no lado da escrita. Subir só o
recorte faz o defeito sumir dos casos fáceis e **parecer resolvido**, que é pior que o estado
anterior, onde pelo menos se sabia que estava quebrado.

**Guarda no lado da escrita:** exigir LASTRO no turno para cada mutação. Cuidado com a assimetria
que engana: se a mutação tem uma dimensão de QUANTIDADE, um lastro booleano sobre a ENTIDADE não
fecha buraco nenhum — o modelo aluciná o número com a entidade corretamente nomeada. O lastro
precisa amarrar entidade **e** número, e o excesso deve ser CORTADO ao justificado em vez de
recusado inteiro.

Relacionado: {#fail-open-esconde-teste-vacuo}, {#strict-schema-campo-sem-instrucao}.
