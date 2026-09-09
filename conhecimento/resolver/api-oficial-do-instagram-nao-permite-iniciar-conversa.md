## A API oficial do Instagram NÃO permite iniciar conversa — cold DM não é limitação de ferramenta, é a regra da Meta {#api-oficial-do-instagram-nao-permite-iniciar-conversa}

`tags: instagram, meta, api oficial, dm, cold dm, private reply, janela de 24h, prospeccao, banimento, liliflow, R23`

**Sintoma:** alguém propõe uma automação de prospecção que envia DM no Instagram para uma lista de
perfis — extraída de um site de concorrente, de uma planilha, de um scraping. A ideia parece
trivialmente implementável porque a ferramenta já manda DM todo dia. **Não é.**

**Causa raiz:** pela API oficial da Meta, **a conversa tem que ser iniciada pela pessoa**. Mensagem
automatizada só alcança quem interagiu — comentário, resposta de Story ou DM — nas últimas **24
horas**. Cada nova interação reabre a janela. Existe exatamente uma exceção: a **private reply a um
comentário**, que abre uma DM mesmo sem conversa prévia, **uma única vez por comentário**.

Fora disso não há caminho oficial. "Cold DM para lista raspada está fora do que a API permite", e é
descrito pela própria documentação de compliance como o caminho mais rápido para restrição
permanente da conta. A tag `HUMAN_AGENT` estende a janela para 7 dias, mas a Meta **proíbe
explicitamente** usá-la para mensagem automatizada e detecta o abuso.

**O erro de raciocínio que isso corrige:** confundir "a ferramenta manda DM" com "a ferramenta pode
mandar DM para qualquer um". O que a ferramenta faz é **responder**. O gatilho sempre nasce do outro
lado.

**Solução — inverter o fluxo em vez de forçar o envio:**

1. **Abordagem humana, volume baixo.** Recrutamento de parceiro e prospecção B2B funcionam melhor
   assim de qualquer forma: 20 mensagens escritas à mão convertem mais que 2.000 automatizadas.
2. **Fazer a pessoa comentar.** Conteúdo que provoca comentário é o gatilho legítimo — e é a própria
   mecânica do produto funcionando como marketing.
3. **Anúncio click-to-message** segmentado na lista. O clique **abre a janela legitimamente**, e a
   lista vira público de segmentação em vez de destino de disparo.

**Agravante de posicionamento:** quando o produto se vende como "API oficial, sem scraping, sem
automação de navegador" — que é o caso do Liliflow contra ManyChat e afins —, ser flagrado fazendo
cold DM destrói exatamente o ativo que está sendo vendido. E influenciador printa.

**Mapear a lista continua válido.** Arrobas expostas publicamente na vitrine de um concorrente são
inteligência competitiva legítima e uma lista qualificada de gente que já paga por automação de
Instagram. O que muda é o **canal de abordagem**, não o direito de coletar.

Ver também a decisão de precificar por trabalho de IA, e não por contato (verbete ainda não escrito).
