## Sinal novo colocado antes de um `return` antigo herda a responsabilidade do caminho inteiro {#sinal-novo-nao-pode-piorar-coleta-que-ja-funcionava}

`tags: coletor, regressao, early return, excecao, review, R23`

**Sintoma:** uma feature nova, opcional, começa a derrubar execuções que antes eram sucesso — e o
erro aparece em contas ou dias que nada têm a ver com a feature.

**Como acontece.** Você precisa que a coleta nova rode mesmo quando o caminho antigo encerra cedo:

```python
insights = buscar_anuncios(...)
if not insights:
    return            # dia sem entrega: antes, sucesso trivial
...
```

Então você a move para **antes** do `return`. Correto quanto ao propósito — a plataforma pode ter
COBRADO num dia sem entregar impressão, e é justamente esse dia que a coluna nova existe para
mostrar. Mas nesse movimento, todo código que você põe ali passa a rodar num caminho que **antes não
executava nada**, e qualquer exceção dele agora reprova o dia inteiro.

**Caso real (2026-09-02).** Ao subir a busca de gasto de nível de conta para antes do short-circuit,
duas coisas viraram regressão de uma vez:

1. o *self-heal* de moeda, que subiu junto, passou a poder derrubar dias que antes retornavam cedo;
2. o `row` era resolvido como **argumento** da função de gravação — então a chamada à API ficava
   **fora** do `try/except` dela. E a busca do Meta faz `FacebookAdsApi.init` fora do próprio `try`
   interno, então o caminho existia de verdade.

**Correção — duas guardas, e uma delas é estrutural.**

- Envolva o bloco novo em `try/except`, com `logger.warning` e seguir adiante. Falta de sinal novo
  vira `—` na tela ("não medimos"), que é a verdade; derrubar a coleta seria pior que não ter o
  número.
- **Receba um CALLABLE, não o valor pronto.** Passando o resultado como argumento, a chamada é
  avaliada fora do `try` e a guarda não cobre a parte mais provável de falhar (a rede):

```python
# ⛔ a busca acontece FORA da guarda
_gravar(conta, dia, buscar_conta(...), moeda)

# ✅ busca e escrita sob a MESMA guarda
_gravar(conta, dia, lambda: buscar_conta(...), moeda)
```

**Regra que generaliza:** ao mover código para antes de um `return` existente, pergunte *"o que este
caminho fazia antes? nada?"*. Se a resposta for "nada", tudo que você colocar ali precisa ser
incapaz de falhar de forma propagante — porque você acabou de dar a ele o poder de reprovar
execuções que sempre passaram.

Corolário para a captura de exceção: numa função nova e **opcional** em cima de coleta que já
funcionava, capture largo (`Exception`), mesmo que as funções vizinhas do mesmo arquivo capturem
estreito. As vizinhas buscam dado que já existia; a sua, não — e a assimetria é o ponto, não uma
inconsistência.
