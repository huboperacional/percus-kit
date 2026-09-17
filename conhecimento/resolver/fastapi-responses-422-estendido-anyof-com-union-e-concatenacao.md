## FastAPI: publicar um 422 com campo extra SEM perder as outras formas — `model` como `Union` e `anyOf` no `content` {#fastapi-responses-422-estendido-anyof-com-union-e-concatenacao}

`tags: fastapi, openapi, responses, 422, anyOf, Union, deep_dict_update, $ref irmao, contrato, cliente gerado, openapi-typescript, HTTPValidationError, envelope de erro, R23`

**Sintoma:** a rota recusa com um corpo maior que o envelope padrão (ex.: `{"detail": {"mensagem", "campo", "codigo"}}`), e
o cliente gerado não enxerga o campo extra — porque o 422 foi declarado como `anyOf [RespostaDeErro, HTTPValidationError]`
escrito à mão no `content`. Trocar pelo `model` da subclasse promete o campo extra também no 422 de validação do Pydantic,
que é lista.

**Causa raiz, lida no FastAPI 0.115.0 (`fastapi/openapi/utils.py:355-397` e `fastapi/utils.py:187-202`):**

- Em `responses={422: {...}}`, se há `model`, o FastAPI gera o schema dele e faz `deep_dict_update(schema_do_content, schema_do_model)`.
- `deep_dict_update` **mescla dicts** e **concatena listas**. Um `model` de classe única gera `{"$ref": ...}` — que cai AO
  LADO do `anyOf` já escrito. Em JSON Schema, `$ref` irmão de `anyOf` é **E**, não OU: o contrato passa a exigir as duas.
- Só `model` põe a classe em `components` (os `response_fields` entram nas definições); um `$ref` escrito à mão para uma
  classe que nenhum `model` registrou fica pendurado.

**Como resolver:**

```python
{
    "model": Union[RespostaDaRecusa, RespostaDeErro],     # gera {"anyOf": [$ref, $ref]} e registra as duas classes
    "content": {"application/json": {"schema": {
        "anyOf": [{"$ref": "#/components/schemas/HTTPValidationError"}]}}},   # concatenado às duas acima
}
```

Resultado: `anyOf [HTTPValidationError, RespostaDaRecusa, RespostaDeErro]` (mais um `title`, que é anotação). Monte o
dicionário **novo a cada rota**: o FastAPI escreve dentro do `content` com `setdefault`, e um dicionário compartilhado
acumula as alternativas de todas as rotas.

**Guarda que discrimina:** afirme o conjunto de `$ref` do `anyOf` E que o schema não tem `$ref` irmão; sabote com `model` de
classe única (fica `$ref` + `anyOf`), com a rota sem o modelo estendido e com o `content` compartilhado — as três ficam vermelhas.

**Caso concreto:** Empresa Milionária, leitura de boleto (Task 16, 16/09/2026) — `empresa-api/app/modules/pj/erros.py`
(`_resposta422Estendida`) e `empresa-api/tests/pj/test_detalhe_de_erro.py`.
