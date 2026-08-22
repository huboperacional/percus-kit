## Subir o DADO antes do CÓDIGO que o lê deixa produção num estado que nenhuma das duas versões prevê {#dado-antes-do-codigo-deixa-prod-meio-aplicada}

tags: ordem de deploy, dado e codigo, update de configuracao, jsonb, seed, semeadura, vocabulario, prod meio-aplicada, rollback de dado, janela de inconsistencia, docker service update, deploy em duas metades

**Contexto:** feature em que o efeito vem de **dado de configuração** (linha de config, JSONB,
vocabulário, feature-flag em tabela) lido por **código novo**. O código é deployado por imagem; o
dado, por `UPDATE`. São duas metades, e alguém escolhe a ordem — quase sempre sem perceber que
escolheu.

**Sintoma:** depois de aplicar só o `UPDATE`, produção passa a se comportar de um jeito que **nenhum
teste cobre e nenhuma das duas versões pretendia**. No caso medido (2026-08-21, semeadura de
apelidos de nomenclatura): o `UPDATE` removeu uma entrada do vocabulário **porque o código novo
sabia lê-la de outro jeito** — só que o código no ar ainda era o velho, que não sabia. Resultado:
10 campanhas perderam a classificação e o token virou "não reconhecido"; outra peça virou "valor
novo" em vez de resolver no valor canônico. Nada quebrou, nada deu 5xx, nada foi gravado errado —
a tela simplesmente **mostrou outra coisa** por ~20 minutos.

**Causa raiz:** as duas ordens não são simétricas, e é fácil achar que são.
- **Código novo + dado velho** é exatamente o estado que os testes de não-regressão já provam. É a
  asserção "nada muda" — o *gate de raio zero* da feature. Esse estado é **projetado**.
- **Dado novo + código velho** não existe em teste nenhum, porque não existe em lugar nenhum a não
  ser nessa janela. Ninguém escreve fixture para ele.

A tentação de inverter é prática, não técnica: o `UPDATE` está pronto em segundos e o deploy dá
trabalho (build, guard de colisão, janela). Foi essa a razão real da inversão.

**Solução:**
1. **Código primeiro**, com a asserção *nada mudou* verificável em produção (fila, contagem, rota —
   algo que se olhe depois de subir).
2. **Só então o `UPDATE`**, cujo efeito passa a ser exatamente o que o dry-run mediu.
3. **Baixe um retrato do próprio banco ANTES de mutar** (`SELECT` da linha inteira para arquivo). Se
   algo bloquear entre as duas metades — guard de colisão, revisão, janela que fechou — é ele que
   permite **desfazer o dado** e devolver produção ao estado que alguém escolheu, campo a campo, em
   segundos. Deixar prod meio-aplicada "só até o deploy sair" é apostar que o bloqueio dura pouco.
4. Se as duas metades **têm** de subir juntas, então não são duas metades: pare de tratá-las como
   deploys independentes e faça a segunda imediatamente após a primeira, sem passar por revisão no
   meio.

**Regra geral:** ao planejar uma feature com dado + código, escreva a ORDEM no plano e trate a
inversão como defeito, não como atalho. E pergunte, para cada ordem: *"este estado intermediário é
provado por algum teste?"* — só uma das duas ordens responde sim.

**Ref:** Paid Media Automation, Fatia C′ de nomenclatura, 2026-08-21 (ADENDO 101 do `docs/STATUS.md`).
Espelho conhecido do mesmo eixo, no sentido oposto: imagem antiga que não consegue ler uma revisão
de migration mais nova, e o entrypoint fail-closed impede o boot.
