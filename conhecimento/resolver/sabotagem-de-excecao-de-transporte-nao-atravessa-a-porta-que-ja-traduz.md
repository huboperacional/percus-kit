## Sabotar "capture só a falha da porta" não pega erro de transporte que a porta já traduz {#sabotagem-de-excecao-de-transporte-nao-atravessa-a-porta-que-ja-traduz}

`tags: sabotagem, teste, porta, adaptador, httpx, HTTPError, ReadError, RemoteProtocolError, except Exception, respx, job, robustez, plano, R23`

**Sintoma:** o plano prevê que, trocando `except Exception` por `except FalhaDaPorta` em volta de uma chamada externa, o teste
parametrizado com `httpx.ReadError`, `httpx.RemoteProtocolError` e `RuntimeError` fica vermelho **nos três**. Só o
`RuntimeError` fica.

**Causa:** o adaptador HTTP real (`ClienteDoDriveHttp._pedir`) já captura `httpx.HTTPError` — de que `ReadError` e
`RemoteProtocolError` são subclasses — e o converte na exceção da porta. Com o `respx` injetando o erro no transporte, a
exceção que chega ao chamador já é `FalhaDaPorta`, e o `except` estreito a pega. Só a exceção **crua**, fora da hierarquia do
`httpx`, atravessa o adaptador.

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, guarda do documento, Task 14 — anonimização revoga a credencial
do Drive):** sabotagem 5 do plano vermelha só no parâmetro `runtime-error`
(`test_job_anonimizacao_revoga_drive.py:84`); tradução em `app/modules/guarda_documento/cliente_http.py:133-135`.

**Como aplicar:** antes de prever o vermelho de uma sabotagem sobre `except`, leia o adaptador e liste o que ele já traduz.
Mantenha os parâmetros de transporte (provam que o adaptador traduz) e um parâmetro de exceção crua (prova o `except
Exception` do chamador) — e escreva no docstring qual parâmetro discrimina qual coisa, para ninguém "enxugar" o teste.
