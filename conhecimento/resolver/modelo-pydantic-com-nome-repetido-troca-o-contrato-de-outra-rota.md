## Modelo Pydantic com o MESMO nome de outro, em outro módulo, troca o schema publicado da OUTRA rota — com a suíte verde {#modelo-pydantic-com-nome-repetido-troca-o-contrato-de-outra-rota}

`tags: fastapi, pydantic, openapi, components schemas, nome de modelo, colisao, contrato, openapi-typescript, cliente gerado, DTO local, suite verde, R23`

**Contexto:** Empresa Milionária, 17/09/2026, V2.3 Task 8. Rotas novas de entrega com DTOs declarados no próprio módulo
de rota (padrão da casa). Um deles se chamava `ConclusaoCorpo`. Já existia **outro** `ConclusaoCorpo`, em
`app/modules/pj/producao/schemas_do_chao.py`, corpo da conclusão de ETAPA, com campos diferentes (`horas_observadas`,
`observacao`).

**O sintoma — só no diff do contrato:** regenerar o `openapi.json` (`app.openapi()`) mostrou linhas REMOVIDAS de uma rota
que ninguém tocou: o `"$ref": "#/components/schemas/ConclusaoCorpo"` da rota de etapa e o bloco do schema com
`horas_observadas`. Toda a suíte ficou verde: testes de rota exercem o handler, não o documento publicado, e o harness de
isolamento não lê `components`.

**Causa:** o OpenAPI do FastAPI registra os modelos em `components.schemas` **pelo nome da classe**. Dois modelos
distintos com o mesmo `__name__` disputam a mesma chave, e o gerador resolve a colisão reescrevendo as referências. O
schema e o `$ref` publicados da rota **antiga** mudam só porque uma rota **nova** nasceu. **Medido depois (M27, 17/09):**
o FastAPI troca **os dois** para o nome qualificado pelo módulo, com `.` virando `__`
(`app__modules__pj__producao__rotas_ordens__EtapaResposta`). Nenhum dos dois fica com o nome curto.

**Por que machuca:** o cliente TypeScript gerado (`openapi-typescript`) muda o tipo que a tela da etapa consome — renomeado
ou fundido — sem que o código da etapa tenha mudado. O erro aparece longe, na próxima regeneração de tipos do frontend.

**Não é caso isolado:** medido no mesmo app, já havia `EtapaResposta` (`rotas_etapas` × `rotas_ordens`) e `MembroResposta`
(`rotas_equipes` × `rotas_papel`) colidindo desde antes.

**Como medir (serve de guarda):**

```python
def modelosDasRotas(app):
    vistos = set()
    def descer(tp):
        if tp is None: return
        for arg in typing.get_args(tp): descer(arg)
        if isinstance(tp, type) and issubclass(tp, BaseModel) and tp not in vistos:
            vistos.add(tp)
            for campo in tp.model_fields.values(): descer(campo.annotation)
    for rota in app.routes:
        if isinstance(rota, APIRoute):
            if rota.body_field is not None: descer(rota.body_field.type_)
            descer(rota.response_model)
    return vistos
# colisão = mesmo __name__ com (__module__, __qualname__) diferentes
```

Controle positivo com duas classes sintéticas de mesmo nome e módulos diferentes, criadas por `type(...)`. Sem ele, uma
varredura que não achasse modelo nenhum passaria para sempre.

**Segunda leitura, pelo contrato que o cliente recebe:** nenhuma chave de `app.openapi()["components"]["schemas"]` contém
`__`. Pega também o modelo que a varredura acima não alcança (por parâmetro ou dependência). O controle positivo tem de
usar um `FastAPI()` **de verdade** com duas classes de mesmo nome: se uma versão futura qualificar de outro jeito, é ele
que fica vermelho, e não a guarda que silencia.

**Conserto:** nome com o domínio no nome (`ConclusaoDaEntregaCorpo`). **Pague a dívida antiga em vez de listá-la** (M27,
conselho 3/3): renomear só um de cada par devolve o nome curto ao outro, muda apenas nome de schema (nenhum campo, nenhum
path) e deixa a guarda valer para o app inteiro **sem lista de exceção**. Antes, meça que ninguém usa os nomes gerados
fora do arquivo gerado (`rg` no frontend), regenere os tipos e rode `tsc --noEmit`. Lista de exceção só se algum nome
tiver consumidor externo.

**E, sempre:** ao regenerar o `openapi.json`, compare **por JSON** e não pelo `git diff` de texto. Todo path e todo schema do
HEAD têm de estar idênticos, e só os novos podem aparecer. O diff de texto tem remoções falsas quando schemas novos entram em
ordem alfabética no meio dos antigos, e é fácil dar de ombros para a remoção verdadeira no meio delas.

**Relacionados:** `anotar-handler-fastapi-cria-response-model-e-muda-o-contrato.md` (outra mudança de contrato por efeito
colateral), `fastapi-responses-de-modulo-compartilhado-vaza-titulo-e-duplica-anyof.md`.
