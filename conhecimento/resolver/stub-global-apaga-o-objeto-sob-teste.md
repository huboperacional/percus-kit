## Stub `autouse` que protege a suíte apaga o objeto sob teste — e os testes DELE viram verde vazio ou vermelho enigmático {#stub-global-apaga-o-objeto-sob-teste}

`tags: pytest, autouse, fixture global, monkeypatch, conftest, stub, dublê, objeto sob teste, verde vazio, mock global, marca, pytest.mark, isenção, suíte completa, falso vermelho`

**Contexto:** para impedir que a suíte dispare integração externa de verdade (WhatsApp, e-mail, gateway de pagamento), nasce uma fixture `autouse` no `conftest.py` da raiz que substitui a função do **módulo cliente** — não de cada consumidor. Isso é o certo: consumidor novo passa a ser coberto sem ninguém lembrar de nada.

**Sintoma:** a suíte completa fica vermelha em N testes do **próprio cliente**, todos com a mesma assinatura absurda — o resultado do dublê. No caso medido: 13 vermelhos em `test_gowa_client.py`/`test_gowa_throttle.py` dizendo `MessageResult(success=True, messageId='offline-suite')`, um valor que o cliente real nunca produziria.

**Causa raiz:** a proteção alcança **todo mundo**, e "todo mundo" inclui quem existe para testar aquele objeto. O stub não quebrou o cliente — ele **respondeu no lugar dele**. Se o teste do cliente afirmasse pouco, o desfecho seria pior: verde, silencioso, e "o cliente funciona" deixaria de ser uma pergunta que a suíte responde.

**Como reconhecer em 10 segundos:** o valor esperado é do dublê (um id fixo, um `success=True` sem rede). Todos os vermelhos são do mesmo arquivo, e é o arquivo cujo nome contém o do módulo patchado.

**Solução — isenção por MARCA, não por lista de nomes:**

```python
# conftest.py
MARCA_DONO_DO_CLIENTE = "dono_do_gowa"

@pytest.fixture(autouse=True)
def _semEnvioDeVerdade(monkeypatch, request):
    if request.node.get_closest_marker(MARCA_DONO_DO_CLIENTE) is not None:
        return          # este arquivo monta os próprios dublês de HTTP
    monkeypatch.setattr(cliente, "sendMessage", _offline)
```

```python
# test_gowa_client.py — primeira linha depois dos imports
pytestmark = pytest.mark.dono_do_gowa
```

Registre a marca no `pytest.ini` (senão vira warning) e explique a isenção **no arquivo de teste**, não só no `conftest`. Com lista de nomes no `conftest`, a declaração mora longe de quem depende dela e o arquivo de teste não tem como dizer que é um caso especial; com marca, quem abre o teste lê o porquê na primeira linha.

**Regra geral:** toda proteção global precisa responder *"quem eu não posso alcançar?"*. A resposta é sempre a mesma classe — **quem testa aquilo que eu substituo** —, e ela não aparece no recorte por task: aparece só na suíte inteira, porque o teste do cliente e a feature nova nunca rodam juntos num filtro por pasta.

**Ref:** Empresa Milionária, 2026-08-20. A fixture nasceu no mesmo dia em que a disciplina por arquivo furou ([[stub-de-envio-por-disciplina-fura-no-segundo-caminho]]) — as duas lições são as duas metades do mesmo problema, e a segunda só apareceu quando a suíte completa rodou pela primeira vez depois da primeira.
