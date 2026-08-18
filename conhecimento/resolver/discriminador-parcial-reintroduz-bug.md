## Reusar "o mesmo discriminador" de uma função irmã sem copiar TODOS os ramos reintroduz o bug que a irmã já corrigiu {#discriminador-parcial-reintroduz-bug}

`tags: discriminador, guard, confirmacao unica, endereco, address confirmed, reuso parcial, 4 vias vira 2 vias, regressao silenciosa, RF29, mode switch, funcao irma`

**Contexto:** uma função nova (`_handleModeSwitch`, tiatendo) precisava decidir se um endereço já
conhecido exige nova confirmação do cliente. O docstring dizia "reusa o MESMO discriminador que a
função-irmã (`_awaitConfirm`) já usa" — mas o código de fato só copiou 2 dos 4 ramos da irmã
(`validated OR formatted → pergunta`), sem a trava "já confirmado pra ESTE pedido"
(`_ADDR_CONFIRMED_KEY == draft.id`) que a irmã tinha nos outros 2 ramos.

**Causa raiz:** "reusar o mesmo discriminador" foi entendido como "usar as mesmas duas condições
de teste" (`validated`/`formatted`), não "replicar a MÁQUINA DE ESTADOS inteira" (validated+
confirmado / validated+não-confirmado / formatted+não-confirmado / formatted+confirmado). A trava
de confirmação-única-por-pedido vivia justamente na dimensão que ficou de fora. Resultado: um
cliente que troca de modo IDA E VOLTA dentro do mesmo pedido (A→B→A) seria perguntado a confirmar
de novo um endereço que ele já tinha confirmado — exatamente o defeito que a função-irmã foi
escrita para evitar, reintroduzido pela função nova.

**Solução:** ao declarar "reuso do mesmo discriminador" de uma função existente, copiar/chamar a
LÓGICA COMPLETA (todos os ramos, não só a condição de entrada), ou fatorar a lógica compartilhada
num helper único que as duas chamam. Revisão que pega isso: comparar as duas funções LADO A LADO,
ramo por ramo — não só "elas testam a mesma variável?", mas "elas têm o MESMO NÚMERO de ramos?".
Teste que prova a correção: construir o cenário "já confirmado para este pedido" explicitamente e
assertar que a função nova NÃO pede confirmação de novo (não só que ela pede quando
não-confirmado).

**Ref:** revisão de qualidade da Task 6, plano C11/C12 (tiatendo, 2026-08-03) —
`_handleModeSwitch` vs `_awaitConfirm` em `execution/engine/restaurantOrderFlow.py`; fix no commit
`0611949`.

**Relacionado:** [#abandonar-duplicado-sem-trilha-e-estado-efemero] — mesma classe, achada 1 dia
antes no mesmo projeto: uma função nova/irmã que reusa "a mesma lógica" de outra mas só copia
PARTE dos passos/ramos, reintroduzindo o bug que a lógica completa já evitava. Lá era um cleanup
de pedido abandonado (3 passos, uma função só fazia 1); aqui é um discriminador de confirmação de
endereço (4 ramos, a função nova só cobria 2).

**3ª ocorrência, projeto diferente (Família Milionária, 2026-08-07):** `extrairPagamentoDivida`
(bot WhatsApp) já tinha corrigido um "leak" de nome vazando os verbos "quero"/"vou" pra dentro do
campo extraído (achado de review anterior, comentado no próprio código como "Leak 3"). A função
IRMÃ `extrairDividaDeCriacao` — mesmo arquivo, mesma responsabilidade de extrair um nome de texto
livre, só que pro fluxo de CRIAÇÃO em vez de PAGAMENTO — nunca recebeu o equivalente: sua
stopword-list (`_STOP_WORDS_CRIAR`) não tinha "quero"/"cadastrar"/"criar"/"tenho". Sintoma em prod
(print real do usuário): "tenho uma dívida de 5000 mil com o banco, quero cadastrar" virava
nome="Mil Banco Quero Cadastrar" em vez de "Banco". O comentário no código JÁ apontava a lição
("Leak 3") — só não tinha sido replicado pra irmã. Fix + teste: `familia-api/app/modules/whatsapp/
divida_handler.py`, commit `4b6d127`. **Reforça o padrão:** ao corrigir um leak/discriminador numa
função, sempre perguntar "existe uma função IRMÃ com a mesma responsabilidade que também precisa
desse fix?" — grep pelo nome da constante/lista (`_STOP_PAGAMENTO_DIVIDA` vs `_STOP_WORDS_CRIAR`)
teria achado isso em segundos.
