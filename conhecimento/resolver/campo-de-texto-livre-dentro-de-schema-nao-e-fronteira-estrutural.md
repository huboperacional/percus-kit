## Campo de texto livre dentro de um schema "estruturado" não é fronteira estrutural — JSON Schema restringe sintaxe, não conteúdo {#campo-de-texto-livre-dentro-de-schema-nao-e-fronteira-estrutural}

`tags: llm, schema, structured-output, tool-calling, alucinacao, guardrail, seguranca, R23`

**Sintoma:** um desenho de "correção estrutural" pra impedir um LLM de alucinar afirmações factuais
propõe trocar texto livre por um objeto JSON com um campo `reply_kind`/`intent` (enum) **mais** um
campo `free_text`/`message` (string). A alegação é que isso torna a alucinação "impossível por
construção", porque agora "há um schema".

**Por que isso não protege nada:** o schema valida a FORMA do valor (é uma string, cabe no enum
permitido), nunca o CONTEÚDO semântico dessa string. O modelo pode devolver
`{"reply_kind": "chitchat", "free_text": "Seu pedido: 1x Feijoada — R$30 — nunca pedido por
ninguém"}` com schema 100% válido. Pior: se a classificação (`reply_kind`) é decidida pelo MESMO
modelo que gera o `free_text`, um erro conjunto de classe+conteúdo passa despercebido — o campo que
deveria "provar" que a resposta é segura é escrito pela mesma fonte que pode estar mentindo.

**Medido em tiatendo (2026-08-26, `grupo-de-discussao/032`→`033`):** um agente propôs
`{"reply_kind": "faq|chitchat|handoff", "free_text": "string"}` como correção pro atendente
conversacional de um bot de pedidos, que tinha alucinado um carrinho inteiro (itens nunca pedidos,
itens reais omitidos) em texto livre. Um segundo revisor (Codex) apontou, corretamente: *"`free_text`
é EXATAMENTE esse campo [que devia deixar de existir]. Não basta mover o mesmo texto livre pra
dentro de JSON."*

**A correção real:** o schema de saída não pode ter NENHUM campo onde o modelo escreva a prosa
factual final. Ele só pode SELECIONAR de enums fechados (que ação tomar, qual conteúdo pré-cadastrado
usar, qual tom aplicar) — e um renderizador determinístico, fora do alcance do LLM, monta 100% do
texto que cita dado real (preço, item, status, subtotal) a partir de dados verificados. Se sobra
alguma superfície de geração livre (ex.: um "smalltalk" de tom, sem conteúdo transacional), ela
precisa ser: (a) uma chamada **separada**, (b) **sem acesso** aos dados que ela poderia citar
incorretamente (não recebe o carrinho/cardápio no prompt), e (c) o risco residual (alucinação de
conteúdo FICTÍCIO, não fundamentado em nada real) declarado explicitamente — nunca escondido atrás
de "impossível por construção".

**Regra que fica:** *"tem um schema" não é a pergunta certa. A pergunta certa é "existe algum campo,
em qualquer lugar do schema, cujo VALOR poderia se tornar prosa factual despachada ao usuário sem
passar por um renderizador determinístico?"* Se a resposta é sim, o schema não é uma fronteira — é
decoração. A fronteira real é a ausência do campo, não a presença de um schema ao redor dele.

**Contra-regra (não superaplique):** enums que SELECIONAM conteúdo pré-validado (ex.: `faq_id` que
escolhe qual resposta de FAQ cadastrada usar, `menu_item_ids` restrito a um enum de IDs reais que já
existe — como `generateDesiredCart` do mesmo projeto já fazia corretamente, e por isso nunca alucinou
item inexistente) SÃO fronteira estrutural de verdade — a diferença é que o valor final vem de uma
tabela/enum fechado, não de geração livre do modelo. O problema é sempre e só o campo do tipo
`string` sem enum, usado pra prosa final.

Irmãos: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]] (mesma classe de erro —
confundir "existe uma camada de proteção" com "a camada de proteção cobre este caso específico").
