## Sabotagem num caso de uso compartilhado dispara pelo caminho errado — vermelho na pré-condição não prova a asserção-alvo {#sabotagem-em-caso-de-uso-compartilhado-dispara-pelo-caminho-errado}

`tags: sabotagem, teste, r1, playwright, e2e, pre-condicao, caso de uso compartilhado, verde falso, asserção-alvo, prova por sabotagem, leitura pura, grava ao abrir`

**Sintoma:** você sabota a fonte para provar que uma asserção de R1 discrimina ("abrir a grade não grava nada", conferido
por foto do banco na `:233`). O teste fica **vermelho** — mas numa linha **anterior** (`:200`, a pré-condição montada pela
API), com o sintoma exato da sabotagem (`Received "2|...,6:1.00:copiado"`). Parece prova. Não é.

**Causa raiz:** a sabotagem foi posta no **caso de uso de leitura**, que também é chamado pela rota de **escrita** que o
próprio teste usa para montar o cenário (`PUT` da célula relê a grade). A sabotagem disparou no preparo, não em "abrir a
grade". A asserção-alvo nunca chegou a rodar. Medido em 2026-09-16 (Empresa Milionária, janela R20 B).

**Solução:**

1. **Sabote no ponto que só o caminho-alvo atravessa** — aqui, a **rota GET** e não o caso de uso compartilhado.
2. **Faça a sabotagem não mudar o que a tela confere antes da asserção-alvo**: gravar DEPOIS de montar a resposta, e num
   dado que o teste não afirma antes dela (dezembro, quando o teste só confere junho). Senão ela fica vermelha numa
   asserção de tela intermediária, de novo antes do alvo.
3. **Prove que a pré-condição passou** na rodada sabotada (o log do teste e a linha em que parou). Na segunda tentativa a
   `:200` passou — o que prova que a sabotagem estreita não disparou no `PUT` —, mas o teste parou por timeout no menu
   (`:207`), outra vez antes do alvo: registrado como **não provado**, com a causa não isolada.
4. **Regra de registro:** vermelho antes da asserção-alvo se escreve "a sabotagem mudou o caminho — não prova a `:N`".
   A marca que dependia da prova não sobe. Prima de [[a-sabotagem-prova-o-que-voce-imaginou]].
