## Não confie em invariante de outro módulo sem CHECK constraint — conte pela condição real, não pelo proxy {#nao-confie-em-invariante-de-outro-modulo-sem-check-constraint}

`tags: invariante, defesa em profundidade, CHECK constraint, situacao, saldo, contagem, aviso de corte, review cross-provider, R23`

**Sintoma:** um aviso de "mostrando N de M" (ou qualquer contagem que serve de proxy pra outra
coisa) infla ou desinfla silenciosamente no dia em que outro módulo — que NÃO tem constraint de
banco garantindo a relação — deixa de manter a invariante que o primeiro código assumia.

**Causa raiz:** duas colunas relacionadas por regra de negócio (`situacao == APROVADO` ⟺
`saldo > 0`, neste projeto) mas SEM `CHECK constraint` no banco amarrando as duas. A relação é
mantida por um único caso de uso (`aplicar_baixa.py`, que move pra `LIQUIDADO` no instante em que
`saldo` chega a zero) — e é fácil escrever, em OUTRO lugar do código, uma contagem que filtra pela
coluna mais barata de indexar (`situacao`) em vez da condição que realmente importa (`saldo >
0`), confiando que as duas sempre coincidem. Elas coincidem enquanto TODO caminho de escrita
passar pelo caso de uso que mantém a invariante — e um teste que fabrica dado direto no ORM (sem
passar pelo caso de uso) já rompe essa garantia amanhã, sem avisar.

**Medido no Empresa Milionária (2026-08-27, D6/D11):** um review cross-provider apontou que o
aviso de corte de página ("mostrando 200 de N em aberto") contava `situacao == APROVADO` como
proxy de "aberto", quando o correto é contar `saldo > 0` — as duas coincidem hoje porque
`aplicar_baixa.py` sempre transiciona pra `LIQUIDADO` ao zerar o saldo, mas essa é uma invariante
de OUTRO módulo, sem `CHECK constraint` que a imponha no banco. Corrigido trocando a contagem pra
`saldo > 0` explícito — e o teste de regressão fabrica DE PROPÓSITO um título `APROVADO` com
`saldo = 0` (fora do caminho normal de `aplicar_baixa`) pra provar que a contagem não confia na
invariante.

**Como generalizar:** ao escrever uma contagem/agregado que existe só como PROXY de uma condição
mais cara ou mais difícil de expressar, perguntar "essa relação é garantida por `CHECK
constraint`, ou só por um caso de uso que sempre mantém as duas juntas?" — se for a segunda, o
teste de regressão precisa fabricar o caso em que a invariante NÃO vale (dado direto, fora do
caso de uso), não só o caminho feliz onde as duas colunas concordam.
