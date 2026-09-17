## Equilibrar baldes por peso ganha menos que a simulação promete — os caros passam a disputar a máquina {#equilibrar-baldes-por-peso-ganha-menos-que-a-simulacao-promete}

tags: suite lenta, paralelismo por processo, balde mais lento, round-robin por nome, LPT greedy,
tempo de parede, contencao de cpu, simulacao superestima ganho, rodar-suite, teto de 10 min

**Sintoma:** a suíte roda em N processos paralelos e está encostando no teto de tempo da chamada.
A soma do tempo de todos os arquivos dividida por N diz que deveria caber folgado, mas o relógio
diz outra coisa.

**Causa raiz (duas, em ordem):** o tempo de parede é o do **balde mais lento**, não a média. E a
repartição costuma ser round-robin pela ordem do nome do arquivo, que é independente do custo — os
dois arquivos mais caros caem no mesmo processo por coincidência alfabética. Medido no `percus-kit`
em 2026-09-17, 76 arquivos em 4 processos: baldes de **492 / 360 / 546 / 355 s** para uma soma de
1.753 s. O balde ocioso terminava 3 min antes do outro.

**Solução:** repartir por peso medido — maior primeiro, sempre no balde mais leve (LPT guloso), com
um arquivo de pesos em segundos por arquivo de teste e mediana para arquivo sem medição. Peso velho
não quebra nada, só desequilibra; remeça quando o tempo voltar a subir.

**A parte que importa: o ganho real foi menos da metade do simulado.** A simulação com os mesmos
números dava **438 s** por balde; a execução deu **529 s** (de 598 s). O motivo é que a simulação
trata cada peso como constante, e ele não é: antes, os arquivos caros estavam empilhados num
processo e rodavam **em série**, sozinhos na máquina; depois de equilibrar, eles rodam **ao mesmo
tempo** e disputam CPU, disco e spawn de processo. Equilibrar não conserva o peso de cada tarefa —
ele muda a vizinhança de cada uma.

**Regra prática:** trate a simulação de balanceamento como **teto**, nunca como estimativa, e
sempre meça a parede depois. Se o ganho previsto é o que justifica a mudança, ele provavelmente não
vai aparecer inteiro — especialmente quando o custo dos testes é processo (spawn de shell, git,
hook), e não cálculo.

**Antes de tirar teste da suíte para ganhar tempo:** olhe *quais* são os arquivos caros. Neste caso
eram o teste do hook `pre-push` e os gates — exatamente o que não pode sair da suíte padrão. Ver
`#suite-verde-com-menos-arquivos`: rodar menos coisa é a forma mais fácil de ficar verde e a mais
cara de descobrir por quê.
