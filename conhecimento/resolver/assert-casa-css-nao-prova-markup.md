## Assert que casa a classe no documento INTEIRO não prova markup — a folha de estilo mantém a string viva {#assert-casa-css-nao-prova-markup}

tags: assert, css, markup, template, mutacao sobrevivente, teste frouxo, html, seletor, style, snapshot

**Sintoma.** Você escreve um teste que garante a presença de um elemento (`assert "minha-classe"
in html`), roda a contra-prova de mutação removendo o elemento — e **a mutação SOBREVIVE**. O teste
fica verde com o elemento fora da página.

**Causa raiz.** A página tem CSS embutido, e a folha de estilo declara `.minha-classe{...}`. A
string continua no documento mesmo depois de o elemento sumir do corpo. O assert casou o **estilo**,
não o **markup** — são coisas diferentes que só por acidente compartilham o mesmo texto.

**Solução.** Recorte o documento antes de asserir presença de elemento:

```python
corpo = html.split("</style>")[-1]      # descarta a folha de estilo
topo  = corpo.split("id-do-form")[0]    # e, se importa ONDE, recorte a região
assert "minha-classe" in topo
```

A mesma classe de erro aparece em SQL: um assert `"coluna" in sql` continua verde quando a coluna
sai do `SELECT` mas permanece no `GROUP BY` — foi medido no mesmo dia, noutro teste. **Se o que
importa é a projeção, assere a projeção**:

```python
def _projecao(sql):
    up = sql.upper()
    return sql[up.index("SELECT"):up.index("FROM")]
```

**A lição que sobrevive:** um assert de substring casa o documento inteiro, e documento inteiro
contém regiões com propósitos diferentes (estilo × corpo, projeção × agrupamento). **Mutação
sobrevivente quase nunca é "teste fraco" no sentido vago — é o assert olhando a região errada.**

**Ref:** tiatendo, 2026-08-16 (S8 `/aplicacao` e D2 da F5b, dois casos no mesmo dia).
