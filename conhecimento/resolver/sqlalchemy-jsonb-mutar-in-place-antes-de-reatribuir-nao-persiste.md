## Mutar dict de coluna JSONB in-place ANTES de reatribuir faz o UPDATE sumir em silêncio {#sqlalchemy-jsonb-mutar-in-place-antes-de-reatribuir-nao-persiste}

`tags: SQLAlchemy, JSONB, dirty tracking, mutação in-place, backfill, script de dado, dict aninhado, copy.deepcopy, prova por mutação`

**Classe de sintoma:** um script de backfill/migração de dado que mexe numa coluna `JSONB` (dict
aninhado, não escalar) roda, imprime "commitado"/sucesso, sem exceção — e metade do dado não muda.
Colunas escalares no MESMO objeto (`col.color = novo_valor`) persistem normalmente; só o campo
JSONB fica intocado. Rodar o script de novo (dry-run) depois do "sucesso" mostra os mesmos registros
"pendentes" de antes.

**O mecanismo:** `meta = col.meta` não copia — pega a MESMA referência que o SQLAlchemy guarda
internamente como o valor "antigo" (`history`) pra decidir se a coluna mudou. Se o código muta um
dict/lista aninhado dentro desse objeto (`meta["statuses"][i]["color"] = x`) e só DEPOIS reatribui
(`col.meta = dict(meta)` ou até `col.meta = meta`), a comparação final do unit-of-work compara
"antigo" contra "novo" — mas os dois são o MESMO objeto (ou objetos com conteúdo idêntico, já que o
"antigo" também foi mutado no caminho). SQLAlchemy conclui "sem mudança" e pula o `UPDATE` daquela
coluna. Nenhum erro, nenhum warning — o `commit()` roda normal porque as OUTRAS colunas escalares
tocadas no mesmo objeto (que não sofrem desse problema) realmente mudaram e geram um `UPDATE` real,
só que sem o campo JSONB.

**Fix:** `copy.deepcopy()` do valor ANTES de tocar em qualquer coisa dentro dele. Só mutar a cópia,
nunca o objeto original lido de `col.<campo_jsonb>`. Depois, reatribuir a cópia mutada:
```python
import copy
original = col.meta or {}
meta = copy.deepcopy(original)   # nunca mutar `original` a partir daqui
meta["statuses"][i]["color"] = novo_valor
col.meta = meta                  # reatribuição de objeto NOVO — dispara o UPDATE
```
Reatribuir sozinho (`col.meta = dict(meta)`) sem o deepcopy anterior NÃO resolve — o `dict(meta)`
cria um novo dict de nível superior, mas as listas/dicts ANINHADOS dentro dele continuam sendo os
mesmos objetos já mutados (shallow copy). O bug sobrevive porque a mutação in-place aconteceu antes
da cópia, não depois.

**Como pegar isso ANTES de confiar no script:** o "commitado."/print de sucesso do próprio script
não é prova — ele só reporta que passou pela lógica, não que o banco mudou. Rode o MESMO script em
modo dry-run (ou uma query independente) de novo, depois do apply. Se os números "pendentes" não
zerarem, o bug é este. Prova por mutação vale pra scripts de dado, não só pra testes automatizados.

**Ref:** Plexco Tasks, 2026-09-01, `backend/scripts/backfill_stage_colors_canon.py` — 1º `--apply`
reportou sucesso, `kanban_columns.color` (escalar) persistiu certo, `meta.statuses[].color`
(JSONB aninhado) não persistiu nada. Achado rodando o dry-run de novo, não por review de código.
Relacionado: `sqlalchemy-enum-grava-name`.

**Ver também:** [[copia-local-de-dict-compartilhado-nao-chega-no-segundo-leitor]] — mecanismo
OPOSTO: lá, um SEGUNDO leitor que relê o container original só vê a correção se a mutação for
IN-PLACE (cópia corta a propagação); aqui, é o ORM que só detecta mudança se ela vier por
REATRIBUIÇÃO de cópia (mutação in-place é invisível ao dirty-tracking).
