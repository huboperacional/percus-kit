## A guarda incapaz de falhar mora no INSTRUMENTO, não no código medido — e o instrumento é o último lugar onde se olha {#a-guarda-que-nao-pode-falhar-mora-no-instrumento}

`tags: guarda vazia, assercao vacua, or True, criterio que nao discrimina, instrumento de medida, teste do teste, checkpoint, zona, handoff, prosa nao passa por review, regra que sobrevive a premissa, R23`

**Origem:** Empresa Milionária, 2026-09-05 — duas sessões paralelas, dois casos no mesmo dia, os
dois no aparelho de medir e nenhum no código medido.

**Contexto:** você tem disciplina de sabotagem. Sabota o código de produção, vê a guarda ficar
vermelha, confia nela. E mesmo assim continua cego, porque o que não foi exercitado é a **guarda
em si** — ou, pior, o **critério em prosa** que decide quando ela vale.

**Os dois casos, medidos:**

1. **`assert <condição> or True`** num teste de isolamento, dentro do *único* teste que
   justificava o arquivo existir. Qualquer exceção o satisfazia — um `ProgrammingError` de coluna
   errada teria passado por "prova do zero silencioso". Pego pelo review cross-provider, não pela
   suíte: a suíte estava **verde**, e verde é exatamente o que uma asserção vácua produz.
2. **Um critério de sucessão entre sessões** escrito em dois artefatos de coordenação
   (`HANDOFF.md` e o JSON de zona): *"enquanto `<nome> [<ref>]` aparecer entre os peers, a
   sucessão não ocorreu"*. Se uma sessão encerrada permanece listada, o teste devolve **o mesmo
   resultado nos dois estados** — não discrimina nada. Duas sessões escreveram o mesmo critério,
   independentemente, no mesmo dia, dentro dos documentos que descreviam esse defeito.

🔑 **A regra que sai:** *quem revisa código raramente revisa o teste; quem revisa o teste quase
nunca revisa o critério escrito em prosa.* A cobertura de atenção decai a cada camada para longe
do produto, e a guarda vácua se aloja na camada mais externa — que é a que ninguém audita.

⚠️ **E documento pesa MAIS que código aqui**, ao contrário do que a intuição diz: `.md` e `.json`
não passam por review, não têm sabotagem, não têm controle positivo. São **afirmação pura**, e
quem os lê age sobre eles sem instrumento nenhum para desconfiar. Código errado eventualmente
fica vermelho; critério errado só é descoberto quando alguém já agiu sobre ele. No caso 2 o custo
foi **território entre sessões**: uma terceira sessão leu "zona livre", concluiu que o dono tinha
saído, e assumiu um arquivo que ainda tinha dono vivo — de boa-fé, porque o disco afirmava isso.

**How to apply:**

1. **Sabote a GUARDA, não só o código** — mas estenda isso ao critério: leia cada asserção
   perguntando *"que valor concreto faz isto falhar?"*. Se você não souber responder em dez
   segundos, ela provavelmente não pode falhar. `or True`, `assert x or y` com `y` sempre
   verdadeiro, `in range(...)` largo demais e `if not X: skip` acima do assert são as formas mais
   comuns.
2. **Critério em prosa também é guarda.** Todo "enquanto X, então Y" escrito em HANDOFF, zona,
   docstring ou plano merece a mesma pergunta. Se X é verdadeiro nos dois estados que você quer
   separar, o critério é decorativo.
3. 🔑 **Prefira a regra que SOBREVIVE à premissa ser falsa.** No caso 2, o conserto foi trocar
   *"aparece no `ListAgents`"* por *"mandei mensagem e a resposta cita hash/decisão que só o dono
   saberia"* — e este funciona nos **dois** mundos possíveis: se `/clear` remove da lista,
   funciona; se não remove, funciona igual. **Uma regra que precisa de uma premissa ser verdadeira
   é dívida escondida; uma que não precisa é só uma regra.** Quando você não puder medir a
   premissa (ali, medir exigiria dar `/clear` e observar de fora), essa é a saída — e declare a
   premissa como não medida em vez de repeti-la como fato.

**Relacionado:** [Guarda passa verde porque não mede nada](guarda-verde-porque-nao-mede-nada.md) — a família; aqui o recorte é
*onde* ela se aloja. [A sabotagem prova o que você imaginou, não o que esqueceu](a-sabotagem-prova-o-que-voce-imaginou.md), que é o limite
do método do item 1. E [Motivo escrito em lista de exceção não é motivo MEDIDO](motivo-escrito-em-excecao-nao-e-motivo-medido.md), a variante
em que o texto substitui a medição em vez de a simular.
