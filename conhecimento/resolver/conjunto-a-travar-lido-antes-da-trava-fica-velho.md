## O conjunto de linhas a travar, lido ANTES da trava, fica velho — trave o escopo largo e releia depois {#conjunto-a-travar-lido-antes-da-trava-fica-velho}

`tags: with_for_update, select for update, race condition, TOCTOU, edicao concorrente, read committed, releitura, populate_existing, lock escopo, sqlalchemy, postgres, sqlite mente, R11`

**Contexto:** Empresa Milionária, 17/09/2026, V2.3 Entregas, Task 5. Editar uma remessa de entrega troca a lista de
itens dela: item que saiu é apagado, o que ficou tem a quantidade atualizada, o que entrou é inserido. A escrita muda
somas por item, então passa pela trava por linha dos itens do pedido (`SELECT … FOR UPDATE`, ordenado por id). O
código fazia a coisa aparentemente certa:

```python
# 1. quais itens a remessa tem HOJE — para saber o que travar e o que apagar
atuais = {l.itemPedidoId: l for l in (await s.execute(
    select(ItemEntrega).where(ItemEntrega.entregaId == entrega.id))).scalars()}
# 2. trava os itens do corpo E os atuais
await travarItensDePedidos(s, pedidoIds=[pedido.id], itemIds=sorted(set(atuais) | idsDoCorpo))
# 3. relê a situação, soma, confere o teto, grava contra `atuais`
```

**O defeito** (achado pelo review cross-provider, não por teste): o passo 1 é leitura **sem trava** e decide **duas**
coisas, quais linhas travar e contra que retrato gravar. Duas edições simultâneas da mesma remessa leem o mesmo `atuais`.
A primeira pega a trava, grava e commita. A segunda acorda da espera **com o `atuais` de antes**:
- apaga ou deixa de apagar linha segundo um retrato que não existe mais;
- tenta inserir item que a primeira já inseriu (estoura a UNIQUE `(entrega, item)` como erro de banco cru);
- não trava nem vê item que a primeira acrescentou.

Reler a **situação** depois da trava (o que o código já fazia) não cura isso: o que ficou velho é o **conjunto**, e o
conjunto também determinou o que foi travado.

**Por que nenhum teste pegou:** o SQLite da suíte roda uma transação por vez e ignora `FOR UPDATE` calado. Toda
asserção sobre a edição fica verde. É a classe de *sqlite mente* aplicada à ordem de leitura, não à trava.

**Conserto:**
1. **Trave um escopo que não dependa da leitura:** aqui, `itemIds=None`, todos os itens do pedido. A remessa só pode ter
   item do próprio pedido, então esse escopo cobre qualquer item que ela tenha ou ganhe, sem precisar saber quais antes.
2. **Leia o conjunto DEPOIS da trava**, forçando dado fresco em vez do objeto da identity map:
   `select(...).execution_options(populate_existing=True)`.
3. A criação continua travando só os itens do corpo: não há conjunto prévio a ler.

**Regra geral:** se uma leitura decide **o que travar** ou **contra que estado gravar**, ela não pode vir antes da trava.
Quando o conjunto a travar só se descobre lendo, trave o **pai** que delimita o conjunto (ou todas as linhas do escopo)
e leia depois. É a mesma ordem global por id, só que com escopo mais largo. Travar mais linhas do mesmo pai custa
paralelismo **dentro** do pai, e não entre pais.

**Como procurar em código existente:** em todo caso de uso com `with_for_update`, veja se algum `select` **antes** da
trava alimenta o argumento da trava ou um laço de `delete`/`update`/`add` depois dela. Se alimenta, é este defeito.

**Relacionados:** `lock-no-pai-errado-soma-estoura.md` (travar a linha errada), `deadlock-por-ordem-de-lock-em-lote-do-corpo.md`
(ordem ditada pelo corpo). Este é o terceiro modo: a linha certa, na ordem certa, escolhida por uma leitura velha.
