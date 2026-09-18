## pytest com um arquivo E a pasta que o contém na mesma chamada coleta SÓ o arquivo — o resto da pasta some calado {#pytest-arquivo-junto-da-pasta-que-o-contem-coleta-so-o-arquivo}

`tags: pytest, coleta, collect-only, keep-duplicates, prova falsa, N passed, suite, recorte, R23`

**Sintoma:** medido em 18/09/2026 no tiatendo (§00as), pytest **8.3.4**. O implementador rodou o arquivo de teste novo
junto com a pasta dele "para garantir" e o placar veio pequeno e verde. Aferido com `--collect-only -q`:

| argumentos | coletados |
|---|---|
| `tests/commercial` | **521** |
| `tests/commercial/test_novo.py tests/commercial` | **5** |
| `tests/commercial tests/commercial/test_novo.py` (ordem inversa) | **5** |
| `--keep-duplicates tests/commercial/test_novo.py tests/commercial` | 526 (521 + o arquivo repetido) |
| `tests/commercial/test_novo.py tests/scripts` (pasta que NÃO contém o arquivo) | 104 (5 + 99, correto) |

Nenhum aviso, nenhum erro, exit 0 — o `N passed` sai verde e mede só o arquivo.

**Causa:** a deduplicação de caminhos de argumento do pytest 8 (o arquivo aparece duas vezes: sozinho e dentro da
pasta) colapsa a coleta da pasta para o arquivo. A causa interna exata não foi investigada; o comportamento foi medido
nas duas ordens.

**Solução:**
- **Nunca** passe um arquivo junto com a pasta que o contém. Para "o novo + o recorte do domínio", passe **só a pasta**
  (o arquivo novo já está dentro dela).
- Se precisar dos dois por outro motivo, use `--keep-duplicates` e saiba que o arquivo roda duas vezes.
- Em evidência de suíte, confira a contagem contra um `--collect-only -q <pasta>` sozinho — placar muito menor que o
  esperado é este verbete, não "o recorte é pequeno".

**Verbetes relacionados:** `prova-de-teste-precisa-provar-que-o-teste-existe-e-foi-coletado.md`,
`o-recorte-do-dominio-nao-e-a-suite.md`.
