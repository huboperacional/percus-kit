## Nome de campo de API montado por concatenação devolve ZERO em vez de erro — e zero é plausível {#nome-de-campo-de-api-concatenado-devolve-zero-em-vez-de-erro}

`tags: hubspot, crm, nome de propriedade, nome de campo, concatenacao, catalogo de propriedades, crm v3 properties, hs_date_entered, hs_v2_date_entered, higienizacao de id, sufixo numerico, id textual, falso negativo, zero plausivel, prefixo errado, api externa, descoberta vs construcao, frente cancelada por medicao errada`

**Sintoma:** você mede a API externa para saber se um campo existe, recebe **`0`**, e a frente que
dependia dele é declarada inviável. Não há erro, não há `404`, não há aviso — a chamada teve
sucesso e devolveu uma lista vazia. Zero é uma resposta perfeitamente plausível ("o portal não usa
esse recurso"), então ninguém desconfia.

**Caso medido (Paid Media Automation, HubSpot, 2026-08-21):** o `STATUS.md` do projeto registrava
**desde 18/08** que `hs_date_entered_<etapa>` **não existe** no portal — *"0 propriedades"*. Isso
quase matou uma frente inteira: contar SQL/appointment **gerados por período** depende de datar a
entrada em etapa, e sem essa data sobra apenas ocupação acumulada — que, dividida pelo gasto do
mês, produz um custo por lead falsamente barato (ver
[ocupacao-de-etapa-nao-e-geracao-no-periodo](ocupacao-de-etapa-nao-e-geracao-no-periodo.md)).

Re-medido em 21/08: **as propriedades existem**, com prefixo **`hs_v2_date_entered_`** — **57 em
`deals`** (de 554 propriedades) e **18 em `leads`** (de 232). A busca original procurou o prefixo
errado, e o prefixo errado devolve zero com a mesma cara que "não existe".

⚠️ **E a re-medição quase errou do mesmo jeito.** Procurar
`hs_v2_date_entered_qualified-stage-id` também devolve **zero** — porque o HubSpot **higieniza o id
textual** antes de virar nome de propriedade, em dois passos, e só o primeiro é adivinhável:

1. hífen vira underscore: `qualified-stage-id` → `qualified_stage_id`;
2. **entra um sufixo numérico que só o portal conhece**.

O nome real é `hs_v2_date_entered_qualified_stage_id_233247981`. Nenhuma leitura da documentação
produz esse `233247981` — ele só existe no catálogo daquele portal.

**Causa raiz:** nome de propriedade/campo de API externa foi tratado como algo que se **constrói**
(prefixo + id), quando é algo que se **descobre** (listar e casar). A concatenação **acerta** nos
ids numéricos — que são a maioria, e é por isso que a técnica passa despercebida por meses — e
falha **em silêncio** exatamente nos ids textuais, os que alguém nomeou à mão.

### Como resolver

1. **Liste o catálogo e case contra ele.** Nunca monte o nome:
   ```
   GET /crm/v3/properties/deals      → results[].name
   GET /crm/v3/properties/leads      → results[].name
   ```
2. **Filtre por FAMÍLIA, não por nome exato.** `startswith("hs_v2_date_entered_")` devolve os 57;
   `== "hs_v2_date_entered_qualified_stage_id"` devolve zero. Filtro de prefixo transforma o erro
   de nome num erro visível (nome parecido na lista) em vez de num vazio.
3. **Case o id higienizado por `contains`, e imprima os candidatos.** `_` no lugar de `-`, e aceite
   sufixo depois. Se casar mais de um, isso é informação — não escolha o primeiro calado.
4. **Afirme que a busca ACHOU algo antes de concluir ausência.** Uma varredura que devolve lista
   vazia é indistinguível de uma varredura que apontou para o lugar errado; exija um
   `total > 0` no catálogo bruto antes de deixar o filtro falar. Sem essa asserção de cegueira,
   `0` sempre significa "não existe".
5. **Ao registrar em doc de status, grave a QUERY junto do número.** *"0 propriedades"* é
   irrecuperável três dias depois; *"0 propriedades com prefixo `hs_date_entered_` em 554 de
   `deals`"* denuncia o próprio erro na primeira releitura.

🔑 **A regra, e ela é maior que o HubSpot:** vale para **qualquer API que derive nome de campo de
um id** — campo customizado de CRM, métrica/dimensão customizada, coluna gerada a partir de rótulo,
chave de payload montada a partir de slug. Se o nome é derivado, o derivador é o servidor, e o
catálogo dele é a única fonte. **Concatenar produz `0` em vez de erro, e `0` não parece bug.**

**Relacionado:** [lookup-normaliza-so-um-lado](lookup-normaliza-so-um-lado.md) e
[chave-normalizada-so-de-um-lado](chave-normalizada-so-de-um-lado.md) — a mesma assimetria, um lado
normalizado e o outro não; [contagem-zero-sob-rls-force-nao-e-fato](contagem-zero-sob-rls-force-nao-e-fato.md)
e [ausencia-por-design-vs-falha](ausencia-por-design-vs-falha.md) — outras duas formas de zero que
mente com cara de fato.

**Ref:** Paid Media Automation, 2026-08-21 — frente de closed-loop HubSpot; `docs/STATUS.md` do
projeto carregava a afirmação errada desde 2026-08-18.
