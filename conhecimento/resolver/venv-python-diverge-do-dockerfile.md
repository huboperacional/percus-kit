## `pip install` falha compilando wheel nativa ("PyO3 não suporta esta versão do Python") {#venv-python-diverge-do-dockerfile}

tags: pip install falha, wheel nativa, maturin, cargo, PyO3, pydantic-core, asyncpg, cryptography, build failed, Python 3.14, 3.13, versao do interpretador, venv, Dockerfile, requirements pinado, nao suba as versoes

**Contexto:** projeto com `requirements.txt` pinado (ex.: `pydantic==2.9.2`, `SQLAlchemy==2.0.35`).
`pip install -r requirements.txt` morre tentando **compilar** `pydantic-core` e `asyncpg`, com
mensagem do tipo `the configured Python interpreter version (3.14) is newer than PyO3's maximum
supported version (3.13)`.

**Causa raiz:** o venv foi criado com o Python **default da máquina**, não com o do ambiente de
produção. Sem wheel pré-compilada para aquela versão, o pip cai no build a partir do fonte — e a
toolchain Rust do pacote não suporta o interpretador. **Não é problema de dependência: é do
interpretador.**

**Solução:** leia a versão no `Dockerfile` (`FROM python:3.12-slim`) e recrie o venv com ela.

```bash
py --list                      # Windows: veja o que existe
py -3.12 -m venv .venv         # ou python3.12 -m venv .venv
source .venv/Scripts/activate
python --version               # confirme ANTES de instalar
pip install -r requirements.txt -r requirements-test.txt
```

⚠️ **A tentação errada é subir `pydantic`/`SQLAlchemy` para uma versão que compile.** Num fork de
125 mil linhas isso é mudança de **comportamento**, não de ambiente, e o custo aparece semanas
depois. Alinhar o interpretador ao Dockerfile é mudança de risco zero e resolve a classe inteira.

**Sintoma irmão:** a suíte "passa" no venv errado porque o pacote faltante é importado de forma
lazy, e só um teste específico acusa. Confira `python --version` antes de acreditar em qualquer
baseline.

**Ref:** Empresa Milionária, Fase 0, 2026-08-11. O plano previa o risco e mandava "registre e
reporte"; a saída real era mais simples do que parecia.
