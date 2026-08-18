## O golden de regressão existe, está VERDE, e guarda um caminho MORTO {#golden-de-regressao-que-guarda-caminho-morto}

`tags: golden, regressao, teste verde inutil, contrato morto, caminho vivo, guarda inerte, calmGolden, deriva de arquitetura, bug que volta`

**Sintoma:** um defeito que já foi corrigido **volta em produção**, com a frase exata que tem teste
de regressão — e o teste continua verde. Ninguém desligou nada; ninguém mexeu no teste.

**Causa raiz:** o teste guarda um **contrato que deixou de decidir**. A arquitetura migrou (um
gerador novo, uma rota nova, um caminho declarativo substituindo um imperativo), o caminho antigo
virou fallback ou código morto, e o golden ficou apontado para ele. O teste segue exercitando a
função que ninguém mais chama no turno real.

**O caso (tiatendo, 2026-08-17):** o cliente escreveu *"quero fazer outro pedido"* e recebeu *"Não
encontrei quero fazer outro pedido no cardápio"*. Existe, em `tests/restaurant/calmGolden.py`, um
golden chamado `bugA_misroute` com a frase **`"quero fazer um pedido"`** e a nota *"bug A 22/06:
virava 'não encontrei no cardápio'"*. O bug já tinha acontecido, sido corrigido e ganhado teste.

O golden vive no conjunto `GOLDENS` — o contrato de VERBOS (`generateCommands`). E o **docstring do
próprio arquivo** avisa, com todas as letras: *"Desde a frente de 29/07 esse contrato não decide
nenhum turno de produção… verde aqui NÃO diz nada sobre o caminho vivo."* O caminho vivo passou a ser
o declarativo (`generateDesiredCart`), coberto por outro conjunto — que **não tem** caso para essa
frase.

🔑 **O aviso estava escrito e não bastou.** Alguém teve o cuidado de documentar que aquele conjunto
não decide mais nada, e ainda assim o golden seguiu lá parecendo proteção. **Comentário não é gate:**
enquanto o arquivo continuar sendo coletado pelo pytest, ele produz verde, e verde é lido como
cobertura.

**Solução:**
1. Ao migrar de contrato, **não deixe o golden antigo apenas documentado como morto** — ou migre os
   casos para o conjunto vivo, ou marque o arquivo inteiro de um jeito que o verde **não conte**
   (skip com motivo, marcador próprio fora da suíte padrão).
2. Para cada caso do conjunto que morreu, pergunte: *"que teste do caminho VIVO falharia se este
   defeito voltasse hoje?"* Se a resposta for nenhum, o caso precisa nascer no conjunto novo.
3. Ao investigar um bug que "já tinha teste", **confira em qual contrato o teste vive** antes de
   concluir que é regressão nova. A pergunta é *"este teste decide algum turno real?"*, não *"este
   teste está verde?"*.

⚠️ **A checagem barata:** procure no repo os conjuntos de golden/fixture e leia o cabeçalho de cada
um. Se algum docstring disser que aquele contrato não roda mais em produção, todo verde daquele
arquivo é decorativo — e cada caso ali é um defeito que pode voltar sem alarme.

**Ref:** tiatendo, achado do operador em 2026-08-17 (print de conversa real, `PENDENCIAS.md` §00c /
N20). Medido no container de PROD: `detectIntent` devolve `OFF_TOPIC` corretamente, mas
`detectOrderItems` fabrica um item fantasma com `namePhrase='fazer outro pedido'` que segue para o
matcher. Ver também `#guarda-medida-funcionando-fica-inerte-quando-o-dado-muda`.
