## Quem restaura o estado não pode ser o teste {#quem-restaura-o-estado-nao-pode-ser-o-teste}

`tags: guarda, sabotagem, falso verde, teste que mede o proprio setup, RLS, contexto de transacao, rollback, postgres, vacuidade, teste de teste`

**Contexto:** um teste que **re-estabelece à mão** o estado que vai assertar mede o próprio setup,
não o sistema. O verde é real, o mecanismo pode estar desligado, e nenhuma leitura do teste
denuncia — porque o código dele parece exatamente o de um teste correto.

**Caso medido (2026-09-05).** Cinco testes contra **PostgreSQL real** provavam que uma porta de
escrita cross-empresa restaurava o contexto de RLS (`app.empresa_id`) ao sair do bloco. Placar:
`5 passed`. Com o `finally` da porta trocado por `pass` — a sabotagem que devia derrubar tudo —
o placar foi **`5 passed` de novo**. Nenhum dos cinco tocava o mecanismo.

Três formas do mesmo erro, e a segunda é a que engana melhor:

1. **Dois testes re-setavam o contexto à mão** depois do bloco, antes de conferir qualquer coisa.
   Mediam o `set_config` do próprio teste.
2. **Um fazia `rollback()` antes de perguntar o contexto** — e o `rollback` mata o GUC local de
   qualquer jeito. Havia um **comentário racionalizando** essa asserção, o que a fazia parecer
   deliberada em vez de errada.
3. **Um terceiro tinha a mesma propriedade por outro motivo** (`commit` encerra a transação).

**Como reescrever, e as duas metades importam:**

- pergunte o estado **logo depois da ação, sem tocar nele**;
- ponha o **controle positivo DENTRO do bloco** (*"aqui o contexto tem de ser B"*) — senão uma
  porta que não trocasse nada passaria na asserção de saída.

Reescritos assim, a mesma sabotagem derruba 2, e um deles exibe o vazamento literal
(`assert 1 == 0`: a linha da empresa B visível sob o contexto da empresa A).

**A armadilha do placar agregado.** Um dos testes **continua** passando com o `finally` sabotado,
e isso não é defeito dele — ele protege outra coisa (que o GUC é local à transação). Some-se ele
aos outros e o placar esconde o buraco. A saída é **declarar no docstring** o que cada teste não
prova, para ninguém contá-lo como prova do que ele não mede.

**Por que "escrever mais asserções" não resolve:** o problema não é quantidade, é **quem produz o
valor asseverado**. Se o setup do teste produz o estado, o teste é uma tautologia cara.

**Generaliza muito além de RLS.** É a forma geral de "a asserção mede o próprio setup": fixture
que grava o registro que o teste vai procurar, mock que devolve o que a asserção espera, `refresh()`
que recarrega do lugar onde o próprio teste escreveu.

**O que discrimina, e é a única coisa que discrimina:** sabotar. Comentário que explica uma asserção
errada é indistinguível de comentário que explica uma asserção certa — ver
[[a-sabotagem-prova-o-que-voce-imaginou]] para o limite dessa técnica, e
[[conte-os-vermelhos-guarda-que-passa-vazia]] para o caso irmão.
