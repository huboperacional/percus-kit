## Escape que atravessa camadas de transporte pode virar troca de X por X — com "ok" mentiroso {#escape-atravessa-camadas-noop}

`tags: escape, backslash, heredoc, bash, python, em-dash, no-op, verificacao em bytes, assert do novo, encoding, fix fantasma, ok mentiroso`

**Sintoma:** script de fix (bash heredoc → python) imprime "ok", assert de `count==1` passa, testes verdes — e o arquivo continua EXATAMENTE igual. Dois reviewers independentes acharam o defeito "corrigido" ainda vivo.

**Causa raiz:** cada camada de transporte pode consumir um nível de backslash. No caso: `new = '") \\u2014 mesmo'` num heredoc chegou no Python como `—` — que É o próprio em-dash. O replace trocou em-dash por em-dash: no-op sintaticamente perfeito, com toda a aparência de sucesso (o assert checava o ANTIGO, que existia mesmo; o write escreveu o mesmo conteúdo).

**Solução:**
1. **Verificação de fix de encoding/escape é SEMPRE em bytes**, nunca em string de alto nível: `open(p,'rb').read().count(b'\xe2\x80\x94')` não mente; `'—' in line` depende de quantas camadas o literal do próprio CHECK atravessou (o meu check tinha o MESMO bug do fix).
2. Pra editar escape em arquivo, usar ferramenta que NÃO processa escapes (Edit tool / editor direto), não string através de shell.
3. Assert de fix não é "o padrão antigo existia" — é "o padrão NOVO existe e o antigo NÃO": `assert new in s and old not in s` teria pego na hora.

**Ref:** Paid Media cont.106.3, em-dash no template do loader (`proxy/router.py`). Só o quality reviewer batendo em bytes revelou.
