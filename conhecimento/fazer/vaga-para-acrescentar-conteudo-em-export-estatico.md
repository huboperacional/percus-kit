## Deixar o cliente ACRESCENTAR item num site de export estático, sem build: vagas + manifesto {#vaga-para-acrescentar-conteudo-em-export-estatico}

`tags: export estatico, next export, cloudflare workers, kv, painel de admin, acrescentar item, galeria, vaga, manifesto publico, seo, sem rebuild`

**Quando usar:** o cliente já **troca** conteúdo por um painel (o storage devolve bytes novos atrás de uma URL que já existe), e agora quer **acrescentar** — mais uma foto na galeria, mais um depoimento. No export estático isso não é o mesmo problema: trocar muda bytes; acrescentar muda **HTML**, e HTML só muda em build.

**Três saídas, e o que cada uma custa** (medidas antes de escolher, 2026-08-19):

| Saída | Ganho | Custo real |
|---|---|---|
| **Vagas + revelação no navegador** | publica em ~2 min, sem build, sem depender da agência | o item acrescentado **não entra no HTML** → buscador não indexa, quem desliga JS não vê |
| Rebuild a cada adição | item indexável, igual aos demais | precisa de pipeline de build confiável; minutos por adição; falha silenciosa se o CI quebrar |
| Só a agência acrescenta | zero trabalho | é o problema que se quer resolver |

### Receita da primeira saída

1. **Declare N vagas no build**, como slots normais do painel (`extraPhoto1..N`). O `get`/`set` delas **não tocam os dados** — elas existem para dar **endereço** a um conteúdo que ainda não existe.
2. **Manifesto público** (`GET /api/gallery/extras`) que lista **só as vagas preenchidas**, lendo as chaves do storage. Sem sessão: o que ele expõe são endereços de arquivos já públicos.
3. **O componente busca o manifesto ao montar** e acrescenta os itens depois dos que vieram do build.
4. **Vaga vazia não vira item, e não pede bytes.** Pedir uma URL sem conteúdo devolve 404 e o painel/página desenha imagem quebrada — some `vaga: boolean` na API para o card saber que "sem override" ≠ "sem imagem".

### 🔴 Os dois furos que aparecem depois, e que valem mais que a receita

- **Seção que só existe quando há itens.** Se o componente faz `if (!itens.length) return null`, uma galeria vazia **não renderiza nó nenhum** — e a ilha de cliente não tem onde montar. O primeiro item que o cliente subir ali **nunca aparece**. A condição de saída tem de considerar os extras (`if (!doBuild.length && !extras.length) return null`). Foi o achado do pré-mortem do conselho, e era o caso real de uma página com galeria vazia.
- **Grade que exige contagem "redonda".** Se as colunas derivam de divisores da quantidade (ex.: maior divisor de {5,4,3}), um item a mais cai em fileira curta. **Meça antes de oferecer vaga naquela grade**: uma galeria com 12 tiles quebra em 13, e quem passa a decidir a contagem é o cliente, que não sabe de divisores. Ofereça vagas onde o layout é `repeat(auto-fill, …)`, que tolera qualquer contagem.

⚠️ **Escreva o custo na página de ajuda do cliente**, não só na spec: "foto acrescentada não é indexada pelo Google". Sem isso, o primeiro "sumiu do Google" vira chamado de suporte e parece defeito.

Relacionado: [regex-que-aproxima-conjunto-canonico-de-ids](../resolver/regex-que-aproxima-conjunto-canonico-de-ids.md) · [texto-legal-afirma-terceiro-que-o-site-nao-carrega-mais](../resolver/texto-legal-afirma-terceiro-que-o-site-nao-carrega-mais.md)
