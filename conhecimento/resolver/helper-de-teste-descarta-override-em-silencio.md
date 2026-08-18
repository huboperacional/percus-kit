## Helper de teste aceita override e o DESCARTA em silêncio — os testes passam por coincidência {#helper-de-teste-descarta-override-em-silencio}

`tags: helper de teste, factory, fixture, **kwargs, override ignorado, INSERT com colunas hardcoded, teste passa por coincidencia, defaults do schema, falso verde, assinatura permissiva`

**Sintoma:** um teste novo, escrito pra exercitar um parâmetro específico, **falha** — e a
investigação mostra que o parâmetro nunca chegou no sistema sob teste. Pior: os testes **anteriores**,
que usavam o mesmo helper, estavam passando sem nunca terem exercitado nada.

**Causa raiz:** o helper/factory aceita `**overrides` (ou um dict de opções) na assinatura, mas a
lista de colunas/campos que ele realmente usa está **hardcoded** no corpo. Chave desconhecida entra
pelo `**kwargs`, é mesclada no dict de defaults, e simplesmente **não é lida** na hora de montar o
INSERT/objeto. Nenhum erro, nenhum aviso.

```python
def _insert_channel(conn, **overrides):
    defaults = dict(tenant_id="teste", channel_key="whatsapp-01", ...)
    defaults.update(overrides)                     # aceita timezone=...
    cur.execute(
        "INSERT INTO canais (tenant_id, channel_key, ...) "   # <- mas NAO insere timezone
        "VALUES (%(tenant_id)s, %(channel_key)s, ...)", defaults)
```

**Por que os testes anteriores passavam:** eles pediam justamente o valor que o **schema já usa como
default**. `_insert_channel(timezone="America/Campo_Grande")` produz uma linha com
`timezone='America/Campo_Grande'` — não porque o override funcionou, mas porque é o `DEFAULT` da
coluna. O teste afirma uma coisa e mede outra, e o verde é coincidência.

**Solução:** monte a lista de campos **a partir do dict**, e faça o helper **falhar alto** em chave
que ele não sabe aplicar. Aceitar em silêncio é o bug; recusar é barato:

```python
COLUNAS_OPCIONAIS = {"timezone", "active_start", "active_end", "enabled"}
desconhecidas = set(overrides) - set(defaults) - COLUNAS_OPCIONAIS
# `raise`, NÃO `assert`: sob `python -O` o assert é REMOVIDO do bytecode e o
# helper volta a descartar override em silêncio — reintroduzindo exatamente o
# defeito que esta entrada documenta. Guarda que só existe em modo debug não é
# guarda. (Achado da review cross-provider, 2026-08-13.)
if desconhecidas:
    raise ValueError(f"override(s) que o helper nao sabe inserir: {sorted(desconhecidas)}")
defaults.update(overrides)
colunas = ", ".join(defaults)
valores = ", ".join(f"%({k})s" for k in defaults)
cur.execute(f"INSERT INTO canais ({colunas}) VALUES ({valores}) RETURNING id;", defaults)
```

**Como achar sem sorte:** escreva pelo menos um caso cujo valor **difere do default do schema**. Foi
o que expôs este — 3 testes de fuso com `America/Campo_Grande` (o default) passaram; o 4º, com
`Asia/Tokyo`, reprovou e revelou que nenhum dos 4 estava configurando fuso nenhum. Vale como regra:
**se o teste existe pra provar que um parâmetro importa, o valor tem que ser diferente do default.**

**Irmão conceitual:** [#teste-passa-em-cima-do-defeito] e
[#teste-timezone-passa-por-coincidencia-da-maquina] — nos três o verde vem do ambiente/valor
escolhido, não do código estar certo.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-13, `tests/test_claim_queries.py::_insert_channel`.
Descoberto ao escrever `test_reagendamento_respeita_um_fuso_diferente_do_padrao`.
