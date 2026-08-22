## O NOME do modo promete o que o código não faz — e quem lê o painel é o cliente, não você {#nome-de-flag-promete-o-que-o-codigo-nao-faz}

`tags: flag, enum, modo, nomenclatura, promessa, copy, oferta comercial, guarda inerte, feature incompleta, painel, produto, teste que prova outra coisa`

**Sintoma:** existe uma flag com um enum de modos — digamos `off | screen | print | both`. O dono do
produto liga `print` no painel e **não sai papel**. Nenhum erro, nenhum log de falha: o modo
simplesmente não faz o que o nome dele diz.

**Causa raiz:** o enum foi escrito por inteiro na fase de **config** (a fase barata), antecipando
fases de execução que **não foram construídas**. No código, o único teste é contra o modo desligado:

```python
if modo == "off":
    ...comportamento legado...
else:
    ...comportamento novo...          # screen, print e both caem AQUI, iguais
```

`print` e `screen` são **o mesmo ramo**. O nome cria uma distinção que a implementação não tem.

**Por que sobrevive a review:** cada peça, isolada, está correta. A validação de transição existe e
é boa (recusa ligar `print` sem destino de fallback). O teste do modo `print` **passa** — mas o que
ele assere é o envio pelo canal antigo, não papel. Um revisor que lê o teste vê "modo print
coberto"; o que está coberto é outra coisa. E o docstring do módulo até declara a verdade em letras
miúdas (*"a flag governa só o que é NOVO — e, na fase F3/F4, tela e papel"*), mas quem lê o `<select>`
do painel é o dono do restaurante, que não lê docstring.

**O caso (tiatendo, 2026-08-21):** `comanda_mode` tinha os quatro modos. O modo `print` só fazia
duas coisas: exigir um destino de WhatsApp de fallback e mudar a palavra no log. O teste que o
"provava" (`test_modo_print_usa_a_cascata_ate_o_attendant`) asserta que a mensagem chegou a um **JID
de WhatsApp**. A fase que produziria papel automático tinha plano de 420 linhas e **zero commits**.
Agravante comercial: a página de vendas cobrava por *"configuração de impressoras"*, e o roadmap
público prometia, para o futuro, *"cozinha recebe **sem papel**"* — duas peças que, lidas juntas,
convencem o lead de que a impressora já existe.

**Como achar na sua base — três perguntas de um minuto cada:**

1. Para cada enum de modo, faça `grep` do valor literal (`"print"`) no código de execução. Se o
   valor só aparece na **definição**, na **validação** e em **strings de log**, ele não governa nada.
2. Abra o teste que "prova" o modo e pergunte **o que ele observa**. Se o assert é sobre o canal
   antigo, o teste prova que o modo não quebrou nada — não que ele faz o que promete.
3. Compare o vocabulário do enum com o vocabulário da **página de vendas**. Palavra que aparece nos
   dois lugares e em nenhum ramo de execução é dívida com o cliente, não com o código.

**Prevenção:** um modo só entra no enum quando o ramo que o executa existe. Antes disso, o nome do
modo é uma promessa a descoberto — e ela é feita para a pessoa que paga, no idioma dela. Se a fase
de config precisa mesmo ser entregue antes (é legítimo: valida cadastro, destrava o painel), o valor
deve se chamar o que ele **faz** (`whatsapp`, `alerta`) e não o que ele **pretende fazer**.

**Relacionado:** a família *"guarda medida funcionando fica INERTE quando o DADO muda"* (aqui a
guarda nunca funcionou — o nome é que sugeria) · [[teste-que-imita-o-produtor-nao-amarra-nada]]
(teste que parece provar e prova outra coisa) · [[alarme-falso-mata-o-alarme]].
