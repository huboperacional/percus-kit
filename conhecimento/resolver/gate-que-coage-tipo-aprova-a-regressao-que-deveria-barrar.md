## Gate que coage tipo APROVA a regressão que deveria barrar — e é pior que gate que quebra {#gate-que-coage-tipo-aprova-a-regressao-que-deveria-barrar}

`tags: gate, comparador, regressao, json, coercao de tipo, booleano, truthy, dry-run, R11, R23, falso negativo`

**Sintoma:** um comparador antes/depois (dry-run de perda, diff de métricas, gate de não-regressão)
roda, imprime "APROVADO" e ninguém olha de novo. A regressão que ele existia para pegar passou.

**Causa raiz:** o gate lê JSON de um produtor que ele não controla e **confia na verdade nativa do
tipo**. Em Python e JS, `not "false"` é `False` — a **string** `"false"` é *truthy*:

```python
if not d.get("temGasto"):        # d["temGasto"] == "false"  →  NÃO entra
    problemas.append("REGRESSAO: ...")
```

O campo diz literalmente que o gasto sumiu, e o gate conclui que continua lá. Mesma família:
`int("5.0")` estoura `ValueError` e **aborta** o gate no meio — e gate que aborta é lido como gate
que aprovou, porque o exit≠0 se perde num pipeline que ninguém acompanha.

**A assimetria que importa:** um gate que **quebra** é chato e visível. Um gate que **aprova
indevidamente** é invisível e definitivo — ele consome a única oportunidade de alguém olhar.

**Como resolver:**

1. **Coerção explícita e tolerante em TODA leitura de campo externo**, uma função por tipo:

   ```python
   _FALSOS = {"false", "0", "none", "null", "", "no"}
   def _bool(v): return v.strip().lower() not in _FALSOS if isinstance(v, str) else bool(v)
   def _num(v):
       try: return int(float(v))
       except (TypeError, ValueError): return 0
   ```

2. **Autoteste no próprio gate**, com uma flag (`--autoteste`), enumerando **um caso por tipo de
   regressão** e afirmando que cada um REPROVA — mais o caso "idêntico a si mesmo" que deve PASSAR.
   Sem esse último, um gate que reprova tudo também "passaria" no autoteste.
3. **Inclua o caso do tipo errado na lista** (`temGasto: "false"` em string). Foi exatamente o caso
   que o autoteste original não tinha.
4. **Rode o autoteste ANTES de rodar o gate de verdade.** O resultado do gate só vale depois de você
   ter visto o gate reprovando.

**Detalhe operacional:** o mesmo vale para a **origem do código que o gate mede**. Um caminho de
import configurável (`APP_PATH`, `PYTHONPATH`) sem validação faz a medição rodar contra o código
ERRADO e sair bonita. Valide a existência de um arquivo-marco do pacote antes de inserir no
`sys.path`, e **imprima contra o que está medindo**.

Achado em 2026-08-30 (Paid Media Automation, gate G1 da frente de Lead Ads). Os três buracos —
booleano coagido, numérico que aborta, caminho de código não validado — foram levantados por três
rodadas de review cross-provider **no próprio gate**, não no código de produção. Parente de
[[teste-pode-travar-uma-afirmacao-falsa]].
