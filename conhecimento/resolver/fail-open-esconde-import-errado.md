## Guard `try/except` fail-open esconde import errado: a feature vira no-op silencioso {#fail-open-esconde-import-errado}

tags: fail-open, try except, import errado, no-op silencioso, review cross-provider, teste de wiring, migration aplicada, testes verdes

**Contexto:** salvaguarda nova, plugada num caminho crítico (gate que não pode quebrar). Envolvi a chamada num `try/except` fail-open — correto em si: uma falha ali não podia impedir de salvar a mensagem do cliente. Só que o import dentro da função apontava pra um caminho **inexistente** (`execution.integrations.whatsappNotifier` em vez de `execution.notifications`).

**Causa raiz:** o `ModuleNotFoundError` estourava no **import**, antes de qualquer lógica, e o fail-open engolia com um `logger.warning`. Resultado: **100% das execuções viravam no-op**, com migration aplicada, suíte verde (4729 testes) e deploy "saudável". A feature inteira não existia em produção e nada denunciava. Os testes cobriam só a função PURA de decisão — nunca o wiring.

**Solução:** (a) todo caminho protegido por fail-open precisa de **um teste que chame a função de verdade** (monkeypatch só nas bordas de I/O) — é o único que pega import/NameError; no nosso caso esse teste pegou, além do import, um `NameError` de módulo fora de escopo; (b) **review cross-provider antes do commit** achou o import — verificação por leitura de outro modelo pega o que o próprio autor não vê; (c) se o fail-open engolir algo que já consumiu estado (contador, flag), logue **ERROR**, não `warning`.

⚠️ **Corolário medido:** perda silenciosa também acontece no envio. No smoke em prod o WhatsApp rejeitou o alerta (`429 WA_REACHOUT_TIMELOCK`) **depois** do contador já commitado → aquele aviso se perderia pra sempre. Fix: consumir o contador, e **devolver** (UPDATE condicional) se o envio retornar falso. Assimetria proposital: alerta repetido ao operador é inofensivo, mensagem repetida ao cliente é spam.

**Ref:** tiatendo `0.249.0`/`0.250.0` (2026-07-25); `execution/core/messageRouter.py::_handoffNudge`, `tests/restaurant/test_handoffNudge.py`. Parente de [#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md) e [#red-nunca-visto-embarca-fossil](red-nunca-visto-embarca-fossil.md).

---
