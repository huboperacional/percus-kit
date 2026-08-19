## Meça a premissa antes de escrever a justificativa da mudança {#medir-antes-de-escrever-a-justificativa}

`tags: premissa, medicao, deprecacao, alias, modelo de API, custo, justificativa, commit message, R23, verificacao, deepseek`

**Contexto:** chega um pedido com a razão embutida — *"troque `X` por `Y`: o `X` foi descontinuado e
custa 3,9× mais na saída"*. A mudança é de uma linha e a razão parece autoevidente.

**O que a medição mostrou:** perguntando à API viva, **os dois nomes respondem HTTP 200** e o antigo
devolve `model = "<o nome novo>"` no corpo. O fornecedor já **redirecionava** o nome antigo
server-side. Não estávamos pagando mais nada; a chamada já ia para o modelo novo, no preço dele.

**Por que isso importa mesmo com a mudança sendo certa:** a troca continua valendo — depender de um
alias de compatibilidade é depender de um redirecionamento que o fornecedor pode reapontar ou remover
sem aviso, e aí a falha aparece em produção. Mas a razão REAL é outra, e a razão errada teria virado
a mensagem de commit, o comentário no código e a memória de quem ler depois.

**Regra prática:** quando a justificativa de uma mudança é uma afirmação sobre o mundo externo
(preço, deprecação, comportamento de terceiro), ela é **testável** — e normalmente por uma chamada
só. Meça antes de escrevê-la. Custa um minuto e evita propagar uma premissa falsa por três artefatos.

**Corolário sobre deploy:** confirmar que a mudança tem efeito **zero** hoje também muda a decisão de
*quando* subir. Se o serviço que a carrega está com imagem velha, deployar por uma linha inerte leva
junto todo o resto — ver [[imagem-velha-transforma-mudanca-pequena-em-deploy-grande]].
