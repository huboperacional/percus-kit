## A suíte manda mensagem DE VERDADE: o stub era disciplina por arquivo, e furou no segundo caminho de envio {#stub-de-envio-por-disciplina-fura-no-segundo-caminho}

`tags: teste, fixture, monkeypatch, conftest, autouse, WhatsApp, GOWA, SMTP, e-mail, envio externo, suíte lenta, rede em teste, efeito colateral, notificação`

**Sintoma:** a suíte de testes fica **lenta** depois de uma feature nova — não vermelha, lenta. Cada
teste que passa por uma rota que "avisa alguém" abre uma conexão de verdade com o provedor de
mensagem. Numa máquina com credencial válida no `.env`, **a mensagem sai**, para o número ou
e-mail que estiver no fixture. Que costuma ser o telefone de alguém real.

**Causa raiz:** o stub existia, e existia no lugar errado. O primeiro caminho de envio foi escrito
com uma fixture no **próprio arquivo de teste**, muitas vezes com o aviso escrito nela mesma —
*"sem isso a suíte dispararia mensagem de verdade"*. Isso funciona enquanto quem escreve o próximo
arquivo lembrar. É **disciplina, não mecanismo**, e a diferença só aparece quando nasce o
**segundo** caminho de envio: outra feature, outro arquivo de teste, ninguém lembra.

**Por que passa despercebido:** não há asserção falhando. O teste continua verde — ele só demora, e
"a suíte está lenta" é atribuído a qualquer coisa antes de ser atribuído a rede.

**Fix — mover o stub para o `conftest.py` da RAIZ, `autouse`:**

```python
@pytest.fixture(autouse=True)
def _semEnvioDeVerdade(monkeypatch):
    from app.modules.whatsapp import gowa_client   # o MÓDULO
    async def _offline(numero, texto):
        return MessageResult(success=True, messageId="offline-suite", httpStatus=200)
    monkeypatch.setattr(gowa_client, "sendMessage", _offline)
```

🔑 **Patch no MÓDULO do cliente, não em cada consumidor.** Quem escreve
`from x import gowa_client` e chama `gowa_client.sendMessage(...)` resolve o atributo **na
chamada** — então um patch no módulo alcança todos os consumidores, inclusive os que ainda não
existem. Patchar `aviso_a.gowa_client` e `aviso_b.gowa_client` um a um reproduz o defeito original
num nível acima: o terceiro consumidor nasce de fora.

Quem precisa **inspecionar o conteúdo enviado** continua declarando a própria fixture; ela sobrepõe
a `autouse`, e o `monkeypatch` desfaz na ordem inversa.

⚠️ **Um stub que LEVANTA não serve como guarda aqui.** O módulo de notificação costuma ter
`except Exception` de propósito (a mensagem não pode derrubar a operação que já gravou), então o
`AssertionError` do stub é engolido e vira "não enviado" — verde, silencioso, e sem rede. Se quiser
detecção além da prevenção, conte as chamadas e afirme fora do `try`.

**Onde apareceu:** Empresa Milionária, 2026-08-20. O aviso de aprovação (M1-2) tinha stub por
arquivo; o convite do contador (M1-7) ligou o segundo caminho de envio e o arquivo de teste dele
não tinha. A suíte de convite saiu de ~17 s para minutos, abrindo conexão real a cada `POST`.
