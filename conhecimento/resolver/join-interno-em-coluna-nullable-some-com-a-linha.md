## Trazer o NOME junto: `outerjoin` sempre, porque `JOIN` em coluna nullable **apaga a linha** {#join-interno-em-coluna-nullable-some-com-a-linha}

`tags: sqlalchemy, async, MissingGreenlet, lazy load, join, left join, outerjoin, nullable, fila, multi-tenant, FK composta, ADR-0008, verde falso`

**Contexto:** uma fila de aprovação de pagamentos devolvia `pessoa_id`, `categoria_id` e `centro_custo_id` — três UUIDs. Quem abre a tela chega por link de capacidade e **não tem sessão**: não existe rota que troque id por nome para ele. Ele aprovava dinheiro sem saber para quem era. O conserto é trazer os nomes; e são as duas armadilhas do conserto que valem registro.

### Armadilha 1 — resolver o nome DEPOIS da query é `MissingGreenlet`

Em sessão async do SQLAlchemy, tocar um relacionamento não carregado fora do contexto do greenlet levanta `MissingGreenlet` — e a mensagem **não diz** que o problema é lazy-load. Some do log como erro genérico e manda o leitor caçar o lugar errado.

**Regra:** em sessão async, **nunca** resolver relacionamento depois da consulta. O nome vem na MESMA `select`.

### Armadilha 2 — e esta é a cara: `JOIN` interno em coluna nullable

Juntar as tabelas para pegar os nomes é o passo óbvio. Fazer isso com `join` em vez de `outerjoin` é o passo que destrói.

`categoria_id` e `centro_custo_id` são **nullable**. Com `JOIN` interno, **a linha sem categoria desaparece do resultado**. E o modo de falha é o pior que existe:

- ninguém recebe erro;
- não há log;
- a fila só fica **menor**;
- o título nunca é aprovado, fica `pendente` para sempre e sai dos números oficiais.

O sintoma aparece semanas depois, como "aquele título sumiu", e ninguém liga a um `JOIN`.

**Fix:**

```python
select(Titulo, Pessoa.nome.label("pessoaNome"), CategoriaPJ.nome.label("categoriaNome"))
  .outerjoin(Pessoa,      and_(Pessoa.id == Titulo.pessoaId,
                               Pessoa.empresaId == Titulo.empresaId))
  .outerjoin(CategoriaPJ, and_(CategoriaPJ.id == Titulo.categoriaId,
                               CategoriaPJ.empresaId == Titulo.empresaId))
```

**Use `outerjoin` mesmo quando a coluna é `NOT NULL`.** No caso acima `pessoa_id` é obrigatório e ainda assim entra por `outerjoin`: a fila decide pagamento, e nenhuma anomalia de dado deve poder **esconder** uma linha dela. Sumir em silêncio é pior que aparecer sem nome.

### O `and_` com o discriminante de tenant não é redundância

Casar só por `id` deixa o nome da contraparte **de outra empresa** aparecer se um id colidir. É a FK composta (ADR-0008) levada para dentro do JOIN — a RLS não cobre o `ON` de um join.

### O teste que pega — e o controle positivo que ele exige

Crie **dois** registros: um COM a classificação e um SEM. Afirme que os **dois** voltam.

⚠️ **Sem o controle positivo o teste é inútil:** afirmar só "o sem-categoria está lá" passa contra uma fila **vazia** — e fila vazia é justamente o defeito. O item COM classificação é o que prova que a consulta rodou.

### Sinal de alerta na revisão

Toda vez que um `select` ganha `join` para buscar rótulo, pergunte: **essa FK é nullable?** Se for, ou é `outerjoin`, ou alguém acabou de apagar linhas sem saber.

**Ref:** Empresa Milionária, `casos_uso/resgatar_link_aprovacao.py::filaDaEmpresa` (2026-08-22). Ver também [sqlalchemy-asyncpg-orig-nunca-e-a-excecao-nua](sqlalchemy-asyncpg-orig-nunca-e-a-excecao-nua.md).
