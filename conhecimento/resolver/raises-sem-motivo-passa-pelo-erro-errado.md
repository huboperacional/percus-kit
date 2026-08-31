## `pytest.raises(X)` sem asserir o MOTIVO passa pelo erro errado {#raises-sem-motivo-passa-pelo-erro-errado}

`tags: pytest.raises, ValidationError, pydantic, teste vacuo, falso verde, min_length, asserir motivo, mutation testing, construtor com N validacoes`

**Sintoma.** Um teste de validação está verde, e a mutação que remove a validação sob teste **não o
derruba**. O teste nunca exercitou o campo que dizia proteger — ele passava por outro erro.

**Caso medido (Plexco Tasks, 2026-08-30).** O teste queria provar que `terminal_kind` tem domínio
fechado:

```python
with pytest.raises(ValidationError):
    ProjectCreate(name="P", template="personalizado", custom_stages=[...])
```

Verde — mas `name` tem `min_length=2`, e `"P"` tem **um** caractere. O `ValidationError` vinha do
NOME. Alargar `terminal_kind` de volta para `str` livre não mudava nada: o construtor continuava
estourando, pelo motivo errado. O teste **vizinho**, pré-existente, tinha o mesmo defeito.

**Regra.** Um construtor com N campos validados tem **N causas** de levantar a mesma exceção.
`pytest.raises(X)` sozinho só afirma "alguma das N disparou". Sempre assere qual:

```python
with pytest.raises(ValidationError) as exc:
    ...
assert "terminal_kind" in str(exc.value)
```

**Onde isto morde mais:** modelos Pydantic (todo campo é uma causa), `HTTPException` genérica,
`ValueError` em função com várias pré-condições, e qualquer fixture "mínima" montada com valores
placeholder curtos (`"P"`, `"x"`, `""`) — que são justamente os que violam `min_length`/`pattern`
sem querer.

**Como pegar:** é invisível a olho nu e óbvio sob mutação. Se remover a validação sob teste deixa o
teste verde, o `raises` está capturando outra coisa.

Ver também: [Mutação sem efeito não pode falhar](mutacao-sem-efeito-nao-pode-falhar.md) ·
[Fail-open esconde teste vácuo](fail-open-esconde-teste-vacuo.md)
