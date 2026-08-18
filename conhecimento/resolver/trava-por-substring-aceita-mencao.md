## Trava mecânica validada por SUBSTRING passa com o símbolo citado em comentário {#trava-por-substring-aceita-mencao}

tags: trava por substring, mencao em comentario passa, teste fraco, verificacao textual, grep como gate

**Sintoma.** Um teste anti-bypass afirma "todo sítio de escrita consulta o portão" e está verde —
mas a garantia é `if "decidirERegistrar" not in corpo`. Um comentário (`# passa por
decidirERegistrar mais tarde`), uma docstring ou uma string literal com o nome satisfazem a
checagem sem que a função chame coisa alguma. A trava vira teatro no dia em que mais importa: a
sessão em que alguém **remove** a chamada e deixa a menção.

**Causa.** Substring mede TEXTO; a regra é sobre CHAMADA. É a mesma "heurística de co-ocorrência"
que costuma ser rejeitada no desenho ("o corpo contém X e também Y?") entrando pela porta dos
fundos na implementação do próprio guard.

**Fix.** Perguntar à AST se existe uma `ast.Call` cujo `func` (Name ou Attribute) tem o
identificador. Em 2026-08-14 (Família Milionária, FR-6 do portão de escrita) o helper certo já
existia no mesmo arquivo desde uma task anterior — era só reusar:

```python
def _nomeDaChamada(func):
    if isinstance(func, ast.Attribute): return func.attr   # gate.Foo.bar(...) -> "bar"
    if isinstance(func, ast.Name): return func.id
    return None

def _chamadasEmFonte(fonte, nome):
    return [no.lineno for no in ast.walk(ast.parse(fonte))
            if isinstance(no, ast.Call) and _nomeDaChamada(no.func) == nome]
```

**Regra durável.** Todo guard mecânico precisa de teste de MUTAÇÃO nos dois sentidos: que ele PEGA
o desvio e que NÃO acusa o caminho certo. Para este, os casos que separam substring de AST são
comentário, docstring e string literal — se os três passam, a trava é decorativa.

**Corolário (mesma sessão).** Um inventário fechado precisa da varredura INVERSA: entrada
registrada que não corresponde mais a nenhuma função real vira documentação que mente, e ninguém lê
inventário com lixo. E **isenção sem trava é porta**: quando um sítio é legitimamente isento
("protegido por construção"), sustente a isenção por um teste de COMPORTAMENTO das defesas próprias
dele — não por leitura de código —, e congele a lista de isentos com um teste de igualdade, para
que a segunda isenção obrigue alguém a justificar.
