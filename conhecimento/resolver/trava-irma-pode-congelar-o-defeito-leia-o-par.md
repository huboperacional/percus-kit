## Trava irmã que reprova sua migração quase sempre está certa — mas quando ela CONGELA um defeito, o tell é o teste vizinho afirmando o contrário no mesmo arquivo {#trava-irma-pode-congelar-o-defeito-leia-o-par}

`tags: teste de contrato, trava irma, congelar defeito, bicondicional, implicacao, copy vs matcher, FR-8.1, migracao, consolidacao, regressao aparente, ler o par, teste que protege o buraco, refatoracao`

**Sintoma:** você migra um sítio para um contrato comum e uma trava antiga reprova. A regra
aprendida (com razão) é *"a trava irmã costuma estar CERTA: ensine a prova nova, não encurte a
copy"*. Você obedece — e acaba de reintroduzir o defeito que a migração tinha consertado.

**Contexto (Família Milionária, Fase 3 da consolidação de roteadores, 2026-08-21):** em cinco
migrações seguidas a trava irmã estava certa **quatro vezes** (TTL colapsando dois desfechos de
`NAO_ENTENDI`, matcher trocado em silêncio, stub que deixou de descrever o modelo). Na quinta ela
estava errada, e o custo de obedecer teria sido devolver o defeito à produção.

O caso: um card de baixa listava N parcelas e oferecia escolha *"por número ou pelo nome"*. A trava
`test_o_card_de_baixa_so_oferece_o_nome_quando_o_matcher_aceita` exigia que o card oferecesse o nome,
com a justificativa escrita no próprio assert: *"capacidade que existe tem de ser oferecida"*. Só que
a entrada dela eram **duas parcelas da MESMA compra** (`fone (1/5)` e `fone (2/5)`), cujas descrições
só diferem pelo sufixo — o nome casa com as DUAS, o matcher não desempata, e a resposta caía no
rodapé pedindo o número. **A capacidade não existia naquele caso.** A trava afirmava uma promessa
falsa como se fosse contrato.

**O tell, e ele é barato:** o teste irmão **logo abaixo**, no mesmo arquivo
(`test_caso11b_nome_ambiguo_no_menu_nao_escolhe_sozinho`), afirmava exatamente o contrário — que com
`Fone (1/5)` e `Fone (2/5)` o nome NÃO escolhe. Os dois conviviam há meses. A contradição não é
visível lendo um teste; só aparece **lendo o par**.

**Por que uma implicação sozinha não pega isso.** *"O card promete ⇒ o matcher aceita"* e *"o matcher
aceita ⇒ o card promete"* são direções diferentes, e cada teste cobria uma. Enquanto ninguém
escreveu a **bicondicional** sobre o mesmo par de entradas, os dois podiam estar verdes afirmando
coisas incompatíveis. É a forma parente de *"teste de contrato pode PROTEGER o buraco"*: aqui ele não
protege um vão, ele **certifica** um defeito.

**Procedimento quando uma trava irmã reprova a migração:**
1. **Leia a ENTRADA dela, não só o assert.** A justificativa (*"capacidade que existe"*) é uma
   afirmação sobre o mundo — confira se ela vale **para aquela entrada**, executando.
2. **Procure o teste vizinho sobre o mesmo eixo.** Se existir um afirmando o oposto, um dos dois está
   errado, e o que descreve o comportamento MEDIDO ganha.
3. **Se a trava estava errada, corrija a ENTRADA e ACRESCENTE a dimensão que faltava** — nunca
   afrouxe o assert. No caso: entrada virou nomes distintos (onde a capacidade existe de verdade), e
   entrou uma asserção nova para o caso "mesma compra".
4. **Registre no diff por que a trava estava errada.** Sem isso, a próxima pessoa lê o histórico e
   conclui que você encurtou a copy pra fazer o build passar — que é exatamente o anti-padrão.

**O que NÃO fazer:** tratar "4 de 5 vezes a trava estava certa" como "sempre obedeça". A regra
sobrevive; o que muda é o custo de verificar, que é ler duas entradas e rodar uma vez.

Ver também [[alargar-matcher-de-guarda-troca-miss-por-alvo-errado]] e
[[detector-de-trava-nasce-frouxo-e-vacuo-ao-mesmo-tempo]].
