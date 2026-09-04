## Cópia local de um dict compartilhado não chega no segundo leitor que relê o container original {#copia-local-de-dict-compartilhado-nao-chega-no-segundo-leitor}

`tags: dict compartilhado, mutacao in-place, copia local, dois leitores, mesma funcao chamada duas vezes, teste de call site vacuo, contra-caso revela o bug, python, referencia vs copia, res signals`

**Classe de sintoma:** duas partes do MESMO turno/requisição leem um valor do MESMO dict
compartilhado (ex.: `res["signals"]`) — uma delas na função A, outra na função B chamada por A
logo depois **com o dict inteiro como parâmetro** (`B(res=res)`, não `B(sig=sig)`). Um fix que
normaliza o valor em A funciona pros leitores DENTRO de A, mas o comportamento errado sobrevive
em B — porque B faz sua PRÓPRIA extração (`sig = res["signals"]`) e nunca viu a versão corrigida.

**O mecanismo:** em Python, `sig = res["signals"]` é uma REFERÊNCIA, não cópia — `sig` e
`res["signals"]` apontam pro mesmo objeto. Até aqui, mutar `sig["chave"] = novo_valor` e mutar
`res["signals"]["chave"] = novo_valor` são idênticos. O bug nasce quando o "fix" faz
`sig = dict(sig)` (ou qualquer outra forma de cópia) ANTES de mutar — a partir desse ponto `sig`
aponta pra um objeto NOVO, e `res["signals"]` continua intocado. Tudo que lê `sig` dali em diante
(dentro da mesma função) vê o valor certo; tudo que relê `res["signals"]` — inclusive uma função
como B, chamada com `res=res` — vê o valor ORIGINAL, errado.

**Por que passa despercebido:** o teste de call site que prova A geralmente mocka o efeito
colateral mais óbvio de A (ex.: uma função de persistência que A chama direto), e esse mock
FICA correto — o bug está no que B faz com o MESMO sinal, e B só é exercitado se o teste também
cobrir o caminho de B. Um contra-caso mal desenhado (que deveria provar "o comportamento
ANTIGO continua pro caso não afetado") pode mascarar isso: se o mock de B tem retorno FIXO
(`AsyncMock(return_value=[...])`), inspecionar o RETORNO do mock nunca revela o argumento que
ele recebeu — é preciso inspecionar `mock.call_args`, não `out`.

**Fix:** mutar o dict compartilhado NO LUGAR, nunca reatribuir uma cópia:
```python
sig = res["signals"]
if condicao:
    sig["chave"] = novo_valor        # certo -- MESMO objeto que res["signals"]
    # sig = dict(sig); sig["chave"] = novo_valor   # ERRADO -- corta a referência
```
Depois, `B(res=res)` (ou qualquer chamador que releia `res["signals"]`) vê o valor corrigido,
porque não existe cópia no meio — é o MESMO dict.

**Como pegar isso ANTES de confiar no fix:** escreva o teste de call site inspecionando o
ARGUMENTO recebido pela função B mockada (`mock.call_args.args`/`.kwargs`), não o valor que ela
RETORNA. Se B tem retorno fixo no mock, o retorno nunca vai denunciar isso — só o argumento
denuncia. Rodar o MESMO teste como mutação (reverter o fix e confirmar que ele volta a falhar)
prova que o teste realmente mede a costura, não o mock.

**Contraste com [[sqlalchemy-jsonb-mutar-in-place-antes-de-reatribuir-nao-persiste]]:** aquele
verbete é o mecanismo OPOSTO — lá, mutar in-place ANTES de reatribuir é o bug (o ORM perde o
rastro da mudança porque compara "antigo" contra "novo" e os dois viram o mesmo objeto); aqui,
mutar in-place é o CONSERTO (garante que o segundo leitor, que relê o container original, veja o
valor certo). A regra não é "sempre copiar" nem "nunca copiar" — é: se existe um SEGUNDO leitor
que releia o CONTAINER ORIGINAL (não a variável local), mutação no lugar é o que propaga; se o
mecanismo de detecção de mudança (ORM dirty-tracking) compara referências, cópia é o que revela.

**Ref:** tiatendo, 2026-09-03, `restaurantCommandOrchestrator._handleOrderTurnLLMInner` — fix do
sinal `sig["delivery"]` (normalizar pra `None` quando `delivery_enabled` está desligado). 1ª
tentativa copiava `sig` localmente; `_replyForResult(res=res)`, chamada logo abaixo, continuava
lendo `res["signals"]["delivery"]` sem correção e montava a fala "Anotado, vai ser entrega!"
mesmo assim. Achado pelo conselho (Cross-Claude), não pela 1ª leitura — a spec ficou BLOQUEADA
até o fix real (`res["signals"]["delivery"] = None`, mesmo dict) ser aplicado e testado via
`mock.call_args`.

**Ver também:** [[sqlalchemy-jsonb-mutar-in-place-antes-de-reatribuir-nao-persiste]]
