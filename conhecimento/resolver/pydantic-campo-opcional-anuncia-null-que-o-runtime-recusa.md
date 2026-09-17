## Campo `X | None` do Pydantic anuncia `null` no OpenAPI que o runtime recusa, e redigitar o schema deixa o anúncio para trás {#pydantic-campo-opcional-anuncia-null-que-o-runtime-recusa}

`tags: pydantic, fastapi, openapi, json schema, anyOf, null, PATCH, model_fields_set, json_schema_extra, WithJsonSchema, __get_pydantic_json_schema__, openapi-typescript, cliente gerado, contrato`

**Quando:** corpo de `PATCH` em que o campo precisa ser `X | None = None` no Python (o default `None` e o
`model_fields_set` separam "ausente" de "enviado"), mas o caso de uso **recusa** `null` com 422 — e o cliente é
gerado do `openapi.json` (`openapi-typescript`).

**Sintoma:** o OpenAPI anuncia `anyOf: [{type: string}, {type: null}]`, o tipo gerado vira `nome?: string | null`, e
um `null` que sempre volta 422 passa na compilação. A tela acaba estreitando o tipo à mão (`Omit<...> & {nome?:
string}`), e o contrato continua mentindo para todo outro consumidor. Em 15/09 (Empresa Milionária, `ContaEditar`).

**Causa:** o JSON Schema é derivado do TIPO Python, e o tipo precisa do `| None` por outro motivo. Quem mente é o
schema derivado — corrige-se ele, não o tipo.

**Passos:**

1. **Todos os campos da classe recusam `null`?** Use `__get_pydantic_json_schema__` na classe, tirando o ramo `null`
   de cada `anyOf` (é o `TituloEditar` do mesmo projeto).
2. **Só alguns recusam** (ex.: `nome: null` é 422, mas `banco: null` APAGA e precisa continuar anunciando)? Tire o
   ramo só no campo, sobre o schema que o próprio `Field` gerou:
   ```python
   def _semRamoNulo(schema: dict) -> None:
       alternativas = schema.get("anyOf")
       if not alternativas:
           return
       semNulo = [a for a in alternativas if a.get("type") != "null"]
       if len(semNulo) == 1 and len(semNulo) < len(alternativas):
           schema.pop("anyOf")
           schema.update(semNulo[0])

   nome: str | None = Field(default=None, min_length=1, max_length=120,
                            json_schema_extra=_semRamoNulo)
   ```
3. Teste do contrato com os DOIS lados: o campo que recusa anuncia só `string`, e os que aceitam continuam com
   `{"string", "null"}` (controle positivo — senão uma troca que tirasse `null` de tudo passaria). Os limites
   anunciados se comparam com os lidos do modelo (`Modelo.model_fields["nome"].metadata`, `MinLen`/`MaxLen`), nunca
   com literais.
4. Regenere `openapi.json` e o tipo gerado e confira que o diff só mexeu no campo.

**Armadilhas:**

- **`WithJsonSchema({...})` com o schema redigitado funciona hoje e apodrece amanhã:** repete `minLength`/`maxLength`
  do `Field`, e na primeira mudança de `max_length` o anúncio fica para trás com o teste verde, se o teste assertar os
  literais. Foi a 1ª versão do conserto e o review cross-provider pegou. Sabotagem que prova a guarda: `Field` com
  `max_length=80` e o anúncio forçado em 120 → vermelho em `assert 120 == 80`.
- O gancho de classe (`__get_pydantic_json_schema__`) é tudo-ou-nada: aplicado numa classe mista, apaga o `null`
  legítimo dos campos que o aceitam.
- A validação em runtime não muda com nenhum dos dois: o `null` continua chegando ao caso de uso, que é quem recusa.
  Não troque o tipo para `str` com `default=None` — mente para o type checker.
