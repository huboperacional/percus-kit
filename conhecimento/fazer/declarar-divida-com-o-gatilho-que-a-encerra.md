## Declarar dívida com o gatilho que a encerra, não com uma promessa de voltar {#declarar-divida-com-o-gatilho-que-a-encerra}

`tags: divida tecnica, escopo declarado, spec, comentario de codigo, TODO, gatilho, R11, handoff entre sessoes, YAGNI`

**Quando usar:** você identificou um buraco real, decidiu **não** fechá-lo agora (com razão — o
caso ainda não existe), e vai escrever isso em algum lugar. O jeito como você escreve decide se a
dívida fecha no dia certo ou vira um `TODO` de dois anos.

**O padrão que funciona: declare a CONDIÇÃO que encerra a isenção, não a intenção de voltar.**

Ruim, e é o formato que quase todo mundo usa:

> ⚠️ TODO: tratar colisão de nome aqui depois.

Bom — o formato que fez a dívida fechar sozinha quatro dias depois, por uma sessão diferente:

> ⚠️ Sem tradução de colisão de nome: isto é escopo legítimo **enquanto** não existir rota nem
> caso de uso que crie `TipoPeca` manualmente (verificado em 02/09, `rg` no repo). **Deixa de ser
> escopo legítimo no dia em que QUALQUER um dos dois acontecer**, e o que aparece é 500 cru:
> (1) um segundo nicho ganhar bloco `pecas` com nome repetido; ou (2) o R10 abrir CRUD manual.
> Quem fizer qualquer um dos dois fecha isto **antes**, reusando `NomesDeTipoEmConflito`.

Quatro elementos, e cada um faz um trabalho:

1. **A condição de validade, medida e datada** — "enquanto não existe X, verificado em DD/MM". Sem
   isso a dívida é opinião; com isso, é um fato que alguém pode re-medir.
2. **O gatilho, enumerado** — o que exatamente encerra a isenção. Duas ou três alternativas
   concretas, não "quando ficar relevante".
3. **A consequência, em voz alta** — "e o que aparece é 500 cru". Sem ela, quem puxa o gatilho não
   sabe o tamanho do que está soltando.
4. **O mecanismo do conserto** — o nome da função que já existe e resolve. Transforma "pesquisar
   como fazer" em "chamar aquilo ali".

**Onde escrever:** no **código**, junto da linha que carrega a dívida — não só na spec, e nunca só
no chat ou na review. Quem vai puxar o gatilho está lendo o arquivo, não o histórico. O comentário
que descreve a dívida é o único que sobrevive à sessão que a encontrou.

⚠️ **Ao fechar, o comentário que a declarava passa a ser FALSO — reescreva na mesma entrega.**
Comentário defasado que afirma um defeito já corrigido é a próxima armadilha: uma varredura que
procure o defeito encontra o comentário que o descreve, e os dois são indistinguíveis para quem lê.

🔴 **O gatilho é puxado por quem entrega o CAMINHO, não por quem escreve o código.** Achado de um
R11: uma fatia criou o caso de uso do CRUD manual mas **não** a rota, e declarou as dívidas
fechadas. O revisor recusou, e com razão: *"sem rota que exponha o CRUD, o gatilho não foi puxado
do ponto de vista de quem usa, e o fechamento fica apoiado numa premissa que a entrega não torna
verdadeira"*. A regra que sai daí: **o que fecha a dívida entra no MESMO commit que a torna
alcançável** — senão a árvore fica num estado onde o texto diz "fechado" e o usuário ainda encontra
o defeito. Mesma família de `conhecimento/resolver/campo-de-schema-sem-editor-na-tela-e-inalcancavel.md`
— citado por CAMINHO, e não por `[[wikilink]]`, porque o gate resolve link só DENTRO da mesma
área: ele monta o alvo no diretório do próprio arquivo (`d = FILENAME` sem a folha), então
`fazer/` → `resolver/` nunca resolve.

**Quando fechar, feche pelo que é alcançável — e declare o que sobrou.** Fechar "a classe inteira"
costuma ser desproporcional. No caso medido, a metade alcançável (rótulos duplicados dentro do
mesmo pedido) fechou em memória, sem janela de corrida; a outra metade (rótulo que colide com
registro **já gravado**) exigiria índice funcional sobre `lower()`, que é migration — e ficou
declarada **com o gatilho dela**, que é a rota de acrescentar componente a peça existente. Dívida
parcial declarada é honesta; dívida parcial anunciada como fechada é o defeito seguinte.
