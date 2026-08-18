## `importlib.reload(config)` num teste polui a suite inteira (quebra testes que rodam depois) {#reload-config-polui-suite}

`tags: pytest, pollution, poluicao, importlib reload, get_settings, lru_cache, ordem de testes, falha fantasma, webhook, teste isolado passa suite falha, Settings, dependency_overrides`

**Contexto:** um teste novo passa isolado, mas rodando a suite completa aparecem N falhas **fantasma** em arquivos NÃO relacionados (ex.: webhook signature tests) que rodam DEPOIS dele. Remover só o teste novo → suite verde de novo.

**Causa raiz:** o teste faz `importlib.reload(app.core.config)` (ou de outro módulo core) pra reler env. Reload cria um **novo** objeto `get_settings`/`Settings`, mas todos os módulos já importados (`app.main`, routers, handlers) seguram a referência ANTIGA de `get_settings` (bound no import-time). Ficam DUAS caches `lru_cache` dessincronizadas + um `Settings` novo ≠ o que o app usa. Testes posteriores que leem settings (ex. um secret de webhook) pegam valores inconsistentes → assert falha.

**Solução:** **nunca `importlib.reload` de módulo core no meio da suite.** Pra testar binding de env/flags, instancie `Settings()` **direto** (fresh, lê o env no construtor), sem tocar o singleton nem a cache:
```python
def test_flag(monkeypatch):
    monkeypatch.setenv("MY_FLAG", "true")
    from app.core.config import Settings
    assert Settings().my_flag is True
```
`monkeypatch` reverte o env no teardown; zero estado compartilhado mutado. **Triagem:** teste isolado passa + suite falha em arquivo alheio ⇒ suspeite de poluição (reload / `dependency_overrides` não limpo / cache mutada), não do produto.

**Ref:** sessão Session Resume auth-service 2026-07-12 (11 falhas fantasma em webhook tests); fix commit `603759e`.
