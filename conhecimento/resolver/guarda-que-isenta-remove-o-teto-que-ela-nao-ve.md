## Guarda que ISENTA casos remove o teto que ela não vê — todo isento precisa de teto irmão {#guarda-que-isenta-remove-o-teto-que-ela-nao-ve}

`tags: contador, teto, escalacao, isencao, loop sem saida, guarda que abre buraco, review pegou, mutacao mirando o fio, R23`

**Sintoma:** você conserta um contador que estava punindo o usuário injustamente — passa a **isentar**
as classes de entrada que eram válidas e estavam sendo contadas como erro. Os testes ficam verdes, a
mutação mata todos os alvos, e o conserto está certo. **E mesmo assim você acabou de abrir um buraco
pior que o defeito original.**

**Causa raiz:** aquele contador não era só um contador de erros — ele era **o único teto do loop**.
Ao isentar as classes que um usuário confuso **mais repete**, você tirou o teto exatamente de quem
mais precisava dele. Quem repete a entrada isenta agora gira **para sempre**, sem chegar a piso
nenhum.

**Medido em tiatendo (2026-08-23, frente N36):** o contador de "respostas não entendidas" numa
desambiguação escalava para humano na 3ª. A medição em produção mostrou que as respostas contadas
eram **válidas** — recusa explícita (*"nenhuma dessas"*), pedido de outro item, observação sobre um
ingrediente. Isentá-las era claramente certo. Mas: um cliente que diga *"nenhuma dessas"* cinco vezes
passou a **nunca escalar**, e a re-pergunta girava indefinidamente. É o **oposto** do loop que aquele
contador existia para fechar.

**A pergunta que expõe isto, e ela é barata:** *"depois da minha isenção, o que ainda leva este
usuário a um TERMINAL?"* Se a resposta for "nada, se ele repetir a entrada isenta", o conserto está
pela metade.

**Procedimento:**
1. Antes de isentar, **enumere os terminais** do fluxo e prove que **todos** continuam alcançáveis
   depois da isenção. Terminal inalcançável é loop.
2. **Todo isento precisa de um teto IRMÃO**, com escopo diferente do que você esvaziou. No caso
   medido: o contador de erros passou a contar só erro, e nasceu um contador de **TURNOS**, que conta
   tudo — inclusive o que é isento do primeiro.
3. **O teto irmão precisa ser MAIOR que o original**, senão ele rouba o gatilho do outro e o
   comportamento antigo nunca mais acontece. Valor **exato**, não faixa: "decidido na implementação"
   deixa duas implementações corretas com comportamento diferente para o mesmo usuário.
4. **Não improvise o teto irmão fora do requisito que o define.** Consertar requisito a requisito
   cria a próxima ambiguidade: na frente medida, cinco correções pontuais abriram cinco buracos
   novos, e o que quebrou o ciclo foi escrever a **máquina inteira numa tabela só** — contadores,
   escopo, o que incrementa, teto, terminal, mais precedência e congelamento.

⚠️ **Enquanto o teto irmão não existir, o conserto NÃO PODE IR A PRODUÇÃO** — e isso precisa estar
escrito em dois lugares: no plano **e** no docstring da função, porque quem mexe no código nem sempre
lê o plano.

🔑 **Quem pegou, no caso medido, foi a review cross-provider — não a suíte e não a mutação.** Faz
sentido: teste e mutação verificam o que o código **faz**, e este defeito é sobre o que ele **deixou
de fazer**. Ausência de terminal não tem alvo de mutação óbvio. **Revisor que olha o desenho pega
classe que a suíte não tem como pegar.**

**Irmãos:** [[guard-sem-caminho-alternativo]] · [[guarda-inalcancavel-meca-o-alcance]] ·
[[mutacao-sobrevivente-pode-acusar-codigo-morto]] ·
[[funcao-que-responde-duas-perguntas-tem-status-load-bearing]]
