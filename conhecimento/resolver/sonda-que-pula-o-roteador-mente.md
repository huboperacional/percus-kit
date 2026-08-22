## Sonda que chama o handler direto MENTE quando a pergunta é de roteamento {#sonda-que-pula-o-roteador-mente}

`tags: diagnostico, sonda, roteador, dispatch, handler, smoke, falso negativo, reproducao, bot conversacional, gate lexical`

**Contexto:** um smoke ao vivo reprovou uma frase (*"corrige o valor que paguei da divida do
fornecedor pra 200"*) com uma resposta que não tinha nada a ver (*"Você não tem recorrências
ativas"*). Pra diagnosticar, escrevi uma sonda local que chamava `divida_flow.handleDivida(frase, …)`
direto.

**A sonda disse "passa".** Localmente o bot respondia *"Qual valor você pagou?"*, que era um desfecho
aceitável — e eu quase concluí que a reprovação era do harness.

**Por que ela mentiu:** chamando o handler direto, pulei o **roteador**. Em produção, quem via a
frase primeiro era outro handler: `command_handler` chama o gestor de recorrências ANTES do fluxo de
dívida, e o gate lexical dele abre com a palavra `"paguei"` (`_MANAGE_ACTION_KEYWORDS`). A frase nunca
chegava ao `handleDivida`. O produto estava errado; a sonda é que olhava para o lugar errado.

**A regra:** *a sonda tem de entrar pela mesma porta que a mensagem real entra.* Se a pergunta é
"por que a resposta foi essa?", o caminho tem de incluir o dispatch — mesmo que custe mais setup.
Chamar o handler direto só responde "este handler, se receber isto, faz o quê?", que é uma pergunta
diferente.

**Sintoma de que você caiu nisso:** a sonda local e a execução real discordam, e você começa a
suspeitar do ambiente. Antes de culpar rede, cache ou harness, confira **em que profundidade** a
sonda entra.

**Achado colateral que vale sozinho:** um gate lexical de handler que roda cedo no dispatch define o
**raio** dele. `"paguei"` numa lista de palavras-ação faz TODA frase com "paguei" passar primeiro por
aquele handler — e ela só segue adiante se o parsing de lá desistir. É o argumento mais forte a favor
de uma tabela de ENTRADA única ("esta mensagem é para mim?") em vez de gates espalhados.

**Relacionado:** [[teste-que-fixa-mecanismo-nunca-fica-verde]] — mesma família: medir o lugar errado
e concluir com confiança.
