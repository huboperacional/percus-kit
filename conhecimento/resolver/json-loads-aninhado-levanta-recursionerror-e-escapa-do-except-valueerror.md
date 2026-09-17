## `json.loads` de JSON muito aninhado levanta `RecursionError`, que NÃO é `ValueError` — o `except` do parser deixa passar {#json-loads-aninhado-levanta-recursionerror-e-escapa-do-except-valueerror}

`tags: python, json, json.loads, RecursionError, ValueError, JSONDecodeError, parser, entrada hostil, llm, resposta de modelo, webhook, 500, except`

**Sintoma:** o parser de uma entrada não confiável (resposta de modelo de linguagem, corpo de webhook, arquivo enviado)
faz `try: json.loads(texto) except ValueError: recusa_com_motivo()`. Os testes com JSON quebrado passam — `JSONDecodeError`
é subclasse de `ValueError`. Uma entrada de colchetes aninhados atravessa o `except` e sobe como exceção sem nome: 500,
log com stack trace, e o motivo nomeado ("fora do formato") nunca aparece.

**Medido** (Python 3.12.10, limite de recursão 1000, 2026-09-15): `json.loads("[" * 100000)` e
`json.loads('{"a":' * 100000)` levantam **`RecursionError`**, e `isinstance(erro, ValueError)` é **`False`**. Custa
milissegundos para quem envia — não é caso de DoS por CPU, é caso de tratamento de erro furado.

**Causa raiz:** o decodificador do `json` desce recursivamente em arrays e objetos. Estourar a profundidade é
`RecursionError` (subclasse de `RuntimeError`), não erro de sintaxe; o `except ValueError` foi escrito pensando só em
JSON malformado.

**Fix:** capture `(ValueError, RecursionError)` no ponto de parse e converta no erro de domínio. Se a regra pede
profundidade limitada de verdade, meça a profundidade depois de decodificar, não confie no limite do interpretador.
Teste com os dois formatos (`"[" * 100000` na raiz e aninhado **dentro de um campo** esperado) e sabote trocando o
`except` de volta para `ValueError` — o teste tem de mostrar o `RecursionError` cru.

**Onde mais morde:** validação com Pydantic sobre o resultado não ajuda, porque o `json.loads` explode antes; parsers de
resposta de LLM que "limpam cercas de markdown e fazem `json.loads`"; qualquer webhook que decodifica o corpo à mão.

**Ref:** Empresa Milionária, `empresa-api/app/casos_uso/leitura_boleto_ia.py` (2026-09-15, Task 5 da leitura de boleto).
Irmão sobre entrada hostil: [teto-de-bytes-do-arquivo-nao-limita-o-texto-extraido](teto-de-bytes-do-arquivo-nao-limita-o-texto-extraido.md).
