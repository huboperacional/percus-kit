## Teste que verifica ESTADO FINAL não pega regressão de ORDEM entre duas chamadas assíncronas {#teste-estado-final-nao-pega-ordem}

`tags: teste, ordem de chamada, call order, mock, AsyncMock, side_effect, estado final, race, regressao silenciosa, park antes de consumir, TDD, subagent-driven-development`

**Sintoma:** um teste assíncrono mocka duas funções (A e B) chamadas em sequência dentro da função
sob teste, e só verifica o ESTADO FINAL de um dict/contexto compartilhado (ex.: "o valor X foi
gravado?") — não a ORDEM em que A e B rodaram. O teste passa mesmo se a implementação trocar a
ordem das duas chamadas, porque o efeito do mock (`dict.update()`) acumula independente de
sequência.

**Causa raiz:** quando o efeito colateral do mock é cumulativo (um dicionário que recebe
`.update()` de múltiplas chamadas), a asserção de estado final é insensível a QUAL chamada rodou
primeiro — só prova que ambas rodaram, não em que ordem. Se a correção depende de ordem (ex.:
"parkear o valor ANTES de chamar a função que vai consumi-lo"), esse teste não é uma trava real
contra a regressão que ele nomeia no docstring.

**Solução:** trocar a asserção de estado final por uma asserção de ORDEM, usando uma lista
compartilhada e `side_effect` que anexa um marcador em cada mock:
```python
ordem = []
async def _upd(cid, customerContext=None):
    if customerContext and customerContext.get("chave_alvo"):
        ordem.append("park")
async def _consome(*a, **kw):
    ordem.append("consome")
    return [...]
# patch com AsyncMock(side_effect=_upd) / AsyncMock(side_effect=_consome)
assert ordem == ["park", "consome"]
```
Prova real da trava: troque as duas linhas da implementação de lugar (mutação manual) e confirme
que o teste fica vermelho antes de aceitar como pronto — se ficar verde com a ordem trocada, a
asserção não protege nada.

**Ref:** revisão de qualidade da Task 6, plano C11/C12 (tiatendo, 2026-08-03) —
`test_metodo_de_pagamento_ja_escolhido_sobrevive_a_troca` em
`tests/restaurant/test_handleModeSwitchC1220260803.py`; achado por um code-quality-reviewer
subagent que mutation-testou a asserção antes de aprovar.
