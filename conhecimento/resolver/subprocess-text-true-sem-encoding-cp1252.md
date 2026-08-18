## `subprocess.run(text=True)` sem `encoding=` decodifica stdout como cp1252 no Windows — texto acentuado derruba a thread leitora {#subprocess-text-true-sem-encoding-cp1252}

`tags: subprocess, text=True, encoding, cp1252, UnicodeDecodeError, _readerthread, stdout None, AttributeError, SSH, ssh_runner, Windows, acento, PT-BR, PowerShell`

**Contexto:** função wrapper de SSH (`runRemote`/equivalente) que roda `subprocess.run([...], capture_output=True, text=True, timeout=...)` sem `encoding=` explícito, usada pra rodar `psql`/comandos remotos e capturar o `stdout`. Funciona meses a fio até um caller passar a puxar de volta um campo do banco com acento/emoji (ex.: `SELECT conteudo FROM whatsapp_logs` — resposta real de um bot em PT-BR).

**Sintoma:** dois erros distintos, dependendo de QUAL lado tem o não-ASCII:
1. Se o **stdout remoto** trouxer acento: `Exception in thread Thread-NNN (_readerthread) ... UnicodeDecodeError: 'charmap' codec can't decode byte 0x8d` — a thread interna do `subprocess` que lê o pipe crasha, `result.stdout` fica **`None`**, e o caller quebra em `result.stdout.strip()` com `AttributeError: 'NoneType' object has no attribute 'strip'` — **mascarando** o `RuntimeError` de SSH que o código já tratava.
2. Se o **texto que você tenta imprimir** (não o subprocess) tiver acento/emoji: erro diferente, ver [Fact-check INFUNDADO](fact-check-infundado-e-nao-verificado.md) (`print()`/`cp1252`) — sintoma irmão, causa e fix diferentes (esse aqui é sobre CAPTURAR output de outro processo, não sobre IMPRIMIR o seu).

**Causa raiz:** `text=True` sem `encoding=` usa `locale.getpreferredencoding()` pra decodificar `stdout`/`stderr` — no Windows isso é **cp1252**, não UTF-8, mesmo com o terminal/console em UTF-8. `psql`/SSH devolvem UTF-8 (o Postgres e o texto do banco são UTF-8); qualquer byte multibyte que não mapeia em cp1252 derruba a decodificação.

**Solução:** fixar `encoding="utf-8", errors="replace"` explicitamente no `subprocess.run(..., text=True, ...)`. `errors="replace"` evita crash mesmo em byte genuinamente inválido (troca por `�` em vez de explodir). Mesmo padrão já usado em scripts de deploy do mesmo projeto (`deploy_v2.py`) — mas `ssh_runner.py`/wrappers de SSH mais antigos costumam não ter isso, porque o bug só aparece quando alguém puxa texto PT-BR de volta pelo SSH, não em comandos puramente ASCII (`docker ps`, `SELECT count(*)`, etc.).

```python
result = subprocess.run(
    [...],
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
    timeout=timeout,
)
```

**Relacionado:** [Hook `.ps1` quebra com erro de parser / acento vira caractere estranho](ps51-ascii-hooks.md) — mesma família cp1252-no-Windows, causa raiz diferente (parser de `.ps1` sem BOM, não `subprocess.run`).

**Ref:** Família Milionária, sessão 2026-08-06 — achado ao vivo rodando `execution/smoke_dividas.py`
(smoke test conversacional via webhook real) contra produção; `execution/ssh_runner.py:runRemote`.
