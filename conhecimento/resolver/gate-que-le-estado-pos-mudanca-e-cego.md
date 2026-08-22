## Gate que INSPECIONA o estado depois da mudança não vê o que a mudança consumiu {#gate-que-le-estado-pos-mudanca-e-cego}

tags: gate cego, raio zero, nao-regressao, teste de igualdade, inspecao pos-fato, pipeline, parser, medicao que autoriza desenho, falso verde, vacuidade

**Contexto:** mudança que acrescenta um passo no MEIO de um pipeline (parser, normalizador, ETL) e
que se quer provar **inócua** no dado atual — o clássico "raio zero": *"isto não muda nada hoje; o
efeito só vem da configuração nova"*.

**Sintoma:** o gate de raio zero fica **verde** enquanto o comportamento muda em produção. No caso
medido (2026-08-21), o gate afirmava *"nenhuma peça não classificada dos 1.173 nomes casa em valor
de eixo"* e lia `parsed.looseTokens` / `parsed.theme` **depois** de rodar o parser **já com a
mudança**. Só que o passo novo **consome** a peça: o que ele classificou some dessas listas. O gate
inspecionava justamente as sobras — e a mudança tirava coisas de lá. Passaram 13 registros mudando
de classificação, inclusive para clientes que não tinham optado por nada.

⚠️ **E a mesma cegueira estava na MEDIÇÃO feita antes de escrever código** — a que autorizou o
desenho. Ela olhou o campo final do pipeline, e o passo novo agia num ponto **anterior** àquele
campo. Medição e gate erraram igual porque observavam o mesmo ponto errado. Não foi falta de
cuidado: foi o mesmo raciocínio aplicado duas vezes.

**Causa raiz:** "isto não muda nada" é uma afirmação sobre a **diferença entre duas execuções**, e
foi escrita como uma afirmação sobre **uma execução**. Inspeção pós-fato pergunta *"sobrou alguma
coisa que casaria?"*; o que se quer perguntar é *"o resultado é o mesmo com e sem?"*. Quando a
mudança REMOVE itens do conjunto inspecionado, ela se esconde do próprio gate.

**Solução:**
- Gate de "isto não muda nada" compara **duas execuções** — com e sem a mudança — e exige igualdade
  profunda sobre o corpus real. É falseável; inspeção pós-fato não é.
- Se a mudança age **no meio** do pipeline, olhar a saída final não vê o intermediário. Pergunte
  explicitamente: *"em que ponto eu observo, e o que já foi consumido antes dele?"*.
- Quando não dá para rodar as duas versões (o "antes" é código que não existe mais), **congele o
  retrato do estado anterior** num módulo próprio e compare contra ele. Medir o "antes" com a
  configuração CORRENTE faz o gate comparar a mudança consigo mesma e ficar verde sobre a metade que
  ele deveria vigiar.
- Gate de inspeção continua útil como **complemento barato que localiza a peça** — mas escreva o
  ponto cego dentro dele, apontando para o gate de igualdade que é a proteção real. Sem isso, o
  próximo leitor confia no gate errado.

**Regra geral:** um gate que só pode ficar mais verde quando a mudança age não é um gate, é um
termômetro quebrado. Se a mudança **remove** elementos do conjunto que o gate examina, o gate está
do lado errado da mudança.

**Ref:** Paid Media Automation, Fatia C′ de nomenclatura, 2026-08-21. Quem pegou a regressão foram
os testes de IGUALDADE da fatia anterior (`parse(x, p, eixos)` deep-equal `parse(x, p)` sobre os
1.173 nomes reais), não o gate escrito para ela.
