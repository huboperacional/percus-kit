## O alvo de mutação pode NASCER podre — mascarado por uma evidência irmã que você mesmo acabou de escrever {#alvo-de-mutacao-pode-nascer-podre}

`tags: mutacao, alvo podre, falso verde, guarda com duas evidencias, OR, discriminante, contra-prova, teste do teste, deteccao`

**Sintoma:** você escreve a guarda **e** a contra-prova de mutação na mesma sessão. O alvo mira
exatamente o discriminante que importa. Ele **sobrevive** — ou pior, ele *morre* por acidente e você
nem percebe que morreu pelo motivo errado.

**Causa raiz:** a guarda aceita **duas ou mais evidências alternativas** (um `or`), e a evidência
que você mutou é coberta pela irmã. O alvo não apodreceu com o tempo, como na lição clássica de
*"re-aponte o alvo a cada refactor"*: ele **nasceu podre**, no mesmo commit em que a guarda nasceu.

Isto é traiçoeiro porque a intuição diz que alvo podre é coisa de código velho. Não é. Todo `or`
dentro de uma condição de guarda é um mascarador em potencial **no dia zero**.

**O caso (tiatendo, frente N27, 2026-08-21):** o detector de eco de carrinho exigia duas evidências.
A evidência 1 estava escrita como:

```python
temItem = bool(_ITEM_RE.search(raw) or _NOTA_RE.search(raw))
```

`_ITEM_RE` era o discriminante forte — a linha `1× Nome — R$ 0,00` com tipografia que só sai de
copiar-e-colar. `_NOTA_RE` era a linha de observação com emoji, adicionada "por completude". O alvo
de mutação nº 1 trocava `×` por `x` no `_ITEM_RE` e deveria matar o teste. **Não matava:** o texto
real também tinha a linha de nota, e a irmã satisfazia a condição sozinha.

O defeito de método apareceu na **primeira** rodada da contra-prova, ~10 minutos depois de a guarda
existir. O conserto foi tirar a nota da evidência 1 (ela passou a valer como evidência 2, onde não
carrega o peso do discriminante sozinha) — e aí o alvo passou a matar 13 testes.

**Como achar:** para cada guarda com `or` numa condição, pergunte **qual evidência é o
discriminante** e mute só ela. Se o alvo sobreviver, você tem uma de duas coisas — e as duas são
achados:

- a evidência irmã é **forte demais** e a guarda não depende do discriminante que você achou que ela
  dependia (foi o caso aqui); ou
- as duas são redundantes de propósito, e aí o alvo precisa mutar **as duas juntas** para medir algo
  — e isso tem de ficar **escrito**, senão o próximo leitor conclui "guarda coberta" de um alvo que
  nunca testou nada.

**Regra prática:** escrever a contra-prova de mutação **no mesmo dia** que a guarda não é zelo
excessivo — é o único momento em que o alvo nascendo podre ainda é barato de consertar. E o sinal de
que valeu a pena não é "N/N mortos": é **um alvo que sobreviveu e te obrigou a mexer no desenho**.

**Relacionado:** [[mutacao-sobrevive-por-guarda-redundante]] (sobrevivência por guarda redundante a
jusante; aqui a redundância é *dentro da mesma condição*) · [[mutacao-que-nao-casa-finge-que-o-gate-nao-reprova]] ·
[[fixture-que-mente-faz-a-mutacao-mentir-junto]] · [[teste-que-imita-o-produtor-nao-amarra-nada]].
