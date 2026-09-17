## SDK da OpenAI: o timeout HERDA do erro de conexão, e o `timeout` da chamada é por operação, não teto total {#sdk-openai-timeout-herda-de-conexao-e-timeout-por-operacao-nao-e-teto}

`tags: openai, sdk, APITimeoutError, APIConnectionError, heranca de excecao, ordem do except, httpx, timeout por operacao, wait_for, max_retries, orcamento de tempo, registro de uso, R23`

**Sintoma:** o provedor de IA tem dois desfechos de falha distintos no produto — "tempo esgotado" e "provedor
indisponível" — e todo timeout aparece como "indisponível". Ou: uma chamada com `timeout=30` passa de 30 s sem
levantar nada, e o orçamento total de uma operação (ex.: 90 s) estoura sem ninguém ver.

**Causa raiz, medida no `openai` 1.55.3 (`openai/_exceptions.py:93-99`):**

1. `class APITimeoutError(APIConnectionError)` — o timeout **é** um erro de conexão. Um `except APIConnectionError`
   escrito antes do `except APITimeoutError` captura os dois, e o ramo do timeout nunca roda. E `APIError` é base de
   todos (`APIConnectionError`, `APIStatusError` com `RateLimitError`, e os de validação da resposta).
2. O `timeout` da chamada vira `httpx.Timeout(timeout)`, e a docstring de `httpx/_config.py:79` diz
   `Timeout(5.0)  # 5s timeout on all operations` — é **por operação** (conectar, ler cada pedaço…), não teto da
   chamada inteira. Uma resposta que pinga devagar passa dele. **Não medido contra servidor lento** — é leitura do código.
3. `DEFAULT_MAX_RETRIES = 2` (`openai/_constants.py:10`): o SDK repete sozinho, e quem tem orçamento de tempo não vê.

**Como resolver:**

```python
cliente = openai.AsyncOpenAI(api_key=..., max_retries=0)       # as tentativas são SUAS, contadas no orçamento
try:
    r = await asyncio.wait_for(cliente.chat.completions.create(..., timeout=t), timeout=t)   # teto total
except (openai.APITimeoutError, asyncio.TimeoutError):          # PRIMEIRO — herda de APIConnectionError
    raise FalhaDoProvedor("tempo_esgotado") from None           # from None: a mensagem do SDK pode trazer o pedido
except openai.APIError:
    raise FalhaDoProvedor("provedor_indisponivel") from None
```

🔑 **Armadilha vizinha, achada no review da mesma entrega:** com orçamento de tempo, "tempo esgotado" tem DOIS
significados — a chamada saiu e demorou, ou **nem saiu** porque não cabia. Se o registro de uso (custo) gravar
`chamou_provedor = true` para os dois, conta custo que não houve. A exceção precisa carregar se algum pedido saiu
(`FalhaDoProvedor(tipo, chamouProvedor=tentativa > 0)`).

**Caso concreto:** Empresa Milionária, leitura de boleto por IA (Task 15, 16/09/2026) — `app/modules/leitura_documento/provedor.py`
e `tests/test_leitura_documento_provedor.py` (o teste parametriza `APITimeoutError` → `tempo_esgotado` e
`APIConnectionError` → `provedor_indisponivel`; trocar a ordem dos `except` o deixa vermelho).
