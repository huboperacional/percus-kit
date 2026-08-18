## `with TestClient(app)` dispara o lifespan em CADA teste: 4s de setup viram 13 minutos de suíte {#testclient-dispara-lifespan-por-teste}

tags: pytest, TestClient, FastAPI, lifespan, startup, suite lenta, performance de teste, durations, setup, fixture de escopo

Suíte de 408 testes levava **13m21**. A leitura fácil — "são muitos testes" — estava errada: `pytest --durations` mostrou **4,05s de `setup` e 0,03s de `call`**. O trabalho não estava nos testes, estava **antes** deles.

Causa: cada arquivo abre o app com `with TestClient(app) as c`, e é o **`with`** que dispara o lifespan do FastAPI. O lifespan checava conexão com um banco que não existe no ambiente de teste.

**Solução:** fixture `autouse` no `conftest.py` neutralizando a checagem — **um arquivo**, zero mudança nos arquivos de teste. Resultado medido: **801s → 6,6s**. Escopo de sessão para o `TestClient` parece mais elegante, mas obriga a rearrumar `dependency_overrides` em todos os arquivos para o mesmo ganho.

**Conexão recusada não é instantânea, e `localhost` custa o dobro:** medido, `127.0.0.1:<porta morta>` = **2,04s** e `localhost:<porta morta>` = **4,05s** — no Windows `localhost` resolve para `::1` **e** `127.0.0.1`, e cada família paga o atraso. Trocar o host no `.env` local "resolve" metade e é armadilha: mora em arquivo não versionado e some na próxima máquina.

**Por que isso é mais grave do que parece:** suíte de 13 minutos **ninguém roda**. Ela vira decoração, e a regressão passa por ausência de execução, não por falta de cobertura. No mesmo repo, um arquivo inteiro não coletava por dependência não declarada e o erro saía como `1 error` no fim — lido como ruído por semanas.

**Neutralizar em teste é uma mentira contada de propósito:** escreva no docstring *o que* a mentira esconde e *qual grep* provou que ninguém dependia da verdade. Sem isso, no dia em que alguém escrever um teste de health, ele vai medir a fixture em vez do código.

**Vizinhos, e a diferença entre eles:**
[#gate-marcador-antes-de-validar](gate-marcador-antes-de-validar.md) — lá o gate libera sem olhar; aqui o gate existe, é honesto, e **ninguém o executa** porque custa 13 minutos.

**Ref:** Micro Investors, 2026-08-16 — 801s → 6,6s; a mesma rodada destravou 9 testes que não coletavam (`respx` importado e nunca declarado).
