## Duas guardas que se cobrem mutuamente passam verdes sobre código quebrado — sabote uma de cada vez {#duas-guardas-que-se-cobrem-mutuamente-passam-verdes-sobre-codigo-quebrado}

`tags: teste, TDD, guarda, sabotagem, falso verde, isolamento multi-tenant, fuso horario, RLS, experimento, R23`

**Sintoma:** você escreve o teste que "prova" um comportamento, ele passa, você sabota o código
que ele deveria proteger — **e o teste continua verde**. Não é teste frouxo nem asserção errada:
a asserção está certa e o valor esperado está certo. O que está errado é o **desenho do
experimento**, e ele é invisível na leitura do teste.

**Causa raiz:** o cenário do teste aciona **duas** regras do código ao mesmo tempo, e as duas
produzem o mesmo resultado observável. Sabotar uma deixa a outra respondendo — o teste não
consegue distinguir qual delas o salvou. A asserção mede o resultado final, não o caminho.

Dois casos medidos no mesmo dia (2026-08-31), em domínios diferentes:

1. **Isolamento multi-tenant × guarda de ambiguidade.** Função que resolve "de qual empresa é
   este usuário", devolvendo `None` quando há mais de uma. O teste de isolamento criava um papel
   para OUTRO usuário — mas usava uma fixture que **já dava um papel** a esse outro usuário. Com
   o filtro `WHERE usuario_id = ...` removido, a consulta passava a ver **dois** papéis, a guarda
   de ambiguidade devolvia `None`, e o teste de **isolamento** ficava verde sobre código **sem
   isolamento nenhum**.

2. **Conversão de fuso × guarda de hora.** Função que só envia "segunda às 8h" no fuso do
   cliente. O teste "domingo 23h no Brasil não é segunda" usava um instante que, em UTC, era
   segunda **às 2h** — e a guarda de hora (`< 8`) reprovava antes de a data importar. Removida a
   conversão de fuso, o teste continuava verde. Quem realmente provava o fuso era outro caso:
   `10h59 UTC` = `7h59 em São Paulo`, onde a hora do UTC **passa** na guarda e só a conversão
   reprova.

**Como detectar:** **sabote uma regra de cada vez e anote QUAIS testes acendem.** Se o teste que
você escreveu para a regra X não acende quando X é sabotada, ele não prova X — prova outra coisa.
Isso é diferente de "ver o vermelho" do TDD: lá você vê o vermelho antes de o código existir, e
qualquer implementação errada também dá vermelho. Aqui o código existe e está certo, e a pergunta
é *"este teste específico protege esta regra específica?"*.

**Correção:** conserte o **cenário**, nunca a asserção. Construa o caso onde **só** a regra sob
teste pode reprovar:

- no caso 1: o banco tem **exatamente um** papel, e ele é de outra pessoa — a guarda de
  ambiguidade não tem o que mascarar;
- no caso 2: o instante escolhido **passa** na guarda de hora em UTC e só falha depois de
  convertido — a guarda de hora não tem o que mascarar.

**Rotule com honestidade depois.** No caso 2 o comentário do teste dizia *"é o teste que carrega o
arquivo inteiro"* sobre o caso que **não** provava nada. Docstring inflada é pior que ausente: ela
diz ao próximo leitor que aquela regra já está coberta, e ele não escreve o teste que falta.

**Sinal de alerta antes mesmo de sabotar:** o teste exercita um cenário em que **mais de uma**
condição de guarda é verdadeira. Se o caso tem uma coincidência ("é domingo E é de madrugada",
"tem dois papéis E um é de outro usuário"), separe em dois casos onde cada condição aparece
sozinha.

Ver também [[assercao-de-teste-com-comparacao-nula-nao-dispara]].
