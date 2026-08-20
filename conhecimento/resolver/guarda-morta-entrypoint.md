## Guarda que o entrypoint real nunca alcança: teste de componente ISOLADO cria a ilusão {#guarda-morta-entrypoint}

`tags: guarda morta inalcancavel entrypoint teste isolado camadas subconjunto`

tags: guarda morta, codigo inalcancavel, teste isolado engana, entrypoint real, ordem das camadas, subconjunto de gatilho, defesa em profundidade falsa, fronteira entre guardas

**Sintoma:** você escreve uma proteção, testa, passa — e ela nunca roda em produção, porque outra
camada consome o evento um passo antes. Fica um código que LÊ como proteção e não protege nada
(veja também §"Cinto de segurança" extra CORTA o caso legítimo).

**Como achar:** compare os CONJUNTOS de ativação das duas camadas. No caso real, a de cima ativava
com `estado ∈ A` e `token ∈ B`; a de baixo, com `estado ∈ A'` e `token ∈ B'`, e valia
`A' ⊆ A`, `B' ⊆ B` — ou seja, toda vez que a de baixo ativaria, a de cima já tinha comido o turno.
Subconjunto é o sinal: se o gatilho da sua guarda é subconjunto do gatilho de quem vem antes, ela é
inalcançável.

**Por que o teste não pegou:** ele chamava o componente DIRETO, mockando o vizinho. O isolamento que
torna o teste rápido é o mesmo que apaga a ordem real das camadas.

**Como resolver:** apague a guarda morta (não a deixe "por garantia") e trave a FRONTEIRA com um
teste que exercita o **entrypoint de verdade**, provando qual camada atende cada janela. Documente a
relação de subconjunto no comentário — é ela que alguém vai quebrar sem perceber.

Visto em: tiatendo, correção do "número solto no bot admin" (2026-07-27).

Visto em: tiatendo, N19 (2026-08-05) — variante de BYPASS PARCIAL, não guarda morta total. O gate
de `bot_paused` (`messageRouter._stageLoadConversation`, Stage 2) funciona perfeitamente pra
mensagens que não casam nenhum intent do Stage 0b (`_maybeHandleRestaurantNiche`, que roda ANTES).
Mas o conjunto de ativação do Stage 0b (saudação/cardápio/horário/opt-out) é ORTOGONAL ao de
`bot_paused=True` — não subconjunto dele, mas também não disjunto — então pra QUALQUER mensagem que
caia na interseção (ex.: cliente pausado manda "oi"), o Stage 0b atende primeiro e o gate de pausa
nunca é alcançado nesse turno específico. Achado só ao FORÇAR o estado real via `pauseBot()` (não
SQL cru) e mandar uma mensagem real — nenhum teste unitário isolado (que mocka o vizinho) pegaria,
pelo mesmo motivo do sintoma original desta entrada. Generaliza o "Como achar": a pergunta certa não
é só "B é subconjunto de A?" (bypass total) — é "A ∩ B é vazio?" (query completa: existe qualquer
mensagem que ative as duas camadas?). Se não for vazio E a camada de cima roda primeiro E não
delega, a de baixo é inalcançável PRA ESSE SUBCONJUNTO, mesmo continuando viva pro resto.

Visto em: Empresa Milionária, P21 (2026-08-20) — variante **schema come a regra do domínio**, e o
que a expôs foi o TESTE-PRIMEIRO. Ao escrever o teste antes do código, `POST /titulos` com
`valor: 0` deveria bater na regra `ValorInvalido` do caso de uso; falhou dizendo que `detail` era
lista, não objeto — porque `TituloCriar.valor` declara `Field(gt=0)` e quem recusou foi o
**Pydantic**, uma camada antes. A regra do domínio não estava morta: continuava alcançável pela
rota de **aprovação**, cujo `AprovacaoCorpo.valor` não tem a restrição (os campos são correções
opcionais do aprovador). Duas lições que a entrada anterior não cobre:

1. **"Apague a guarda morta" é o conselho ERRADO nesta variante.** Ela está morta em uma rota e
   viva em outra, e a rota onde vive é a que mexe em dinheiro já lançado. Apagar por "estava
   inalcançável" — medido num endpoint só — abriria o buraco no outro.
2. **Teste-primeiro é o detector barato.** Escrito DEPOIS, o mesmo teste passaria: `422` é `422`,
   e ninguém olha se quem respondeu foi o schema ou o domínio. O verde teria medido o Pydantic e
   declarado coberta uma regra jamais exercitada. A pergunta que fica no bolso: *quando o teste
   verde recusa, QUEM recusou?* — em API com validação declarativa, a resposta raramente é a
   camada que você acha.
