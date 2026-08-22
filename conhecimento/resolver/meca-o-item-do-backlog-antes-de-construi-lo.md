## Meça o item do backlog antes de construí-lo — a premissa erra nos dois sentidos {#meca-o-item-do-backlog-antes-de-construi-lo}

tags: backlog, medição, processo, prioridade

Peguei um item que estava na fila havia dias: *"a faixa X soma registros duplicados, visto 6× em 10
dias"*. Antes de escrever teste, medi. **A premissa estava errada de três formas diferentes**, e
duas delas em direções opostas:

1. **A frequência estava errada.** Não eram "6 vezes em 10 dias". Eram **9 dos 10 dias com ZERO
   ocorrência**, e num único dia **todos os 17 sujeitos duplicados de uma vez**. É *raro e total* —
   o oposto operacional de "às vezes acontece", e muda completamente o risco.
2. **Eu errei a minha própria primeira medição**, e cheguei a reportar "2× todo dia": agrupei por
   `(data, cliente)` e contei como duplicata o cliente que legitimamente tem dois registros (duas
   plataformas). Contar a chave errada infla exatamente como o bug que se procura.
3. **E o defeito já estava corrigido em produção**, nos dois consumidores que o próprio item citava.

⇒ Se eu tivesse "atacado o item", teria reescrito código correto com uma premissa falsa.

**O que sobrou era real e era OUTRA coisa:** as correções existentes estavam protegidas por
comentário, e faltava gate. O gate achou um terceiro consumidor com o defeito vivo. **O trabalho
certo não era o que estava escrito no item — mas só apareceu porque eu fui medir o que estava.**

**Procedimento:**

- Todo item de backlog com número dentro (*"6× em 10 dias"*, *"701 de 701"*, *"47%"*) tem **data de
  validade**: o número foi medido uma vez e o mundo continuou. Remeça antes de agir.
- Meça **a chave certa**: enuncie em voz alta o que é uma ocorrência legítima antes de contar. Dois
  registros do mesmo cliente podem ser duas plataformas, não uma duplicata.
- Confira se **já está corrigido** — `git log -S` no símbolo, e se o commit é ancestral do que está
  em produção.
- Quando a premissa cair, **não descarte o item**: pergunte o que sobrou. Aqui sobrou a diferença
  entre "corrigido" e "protegido contra regressão", que valia mais que o item original.

Ver também [[comentario-nao-e-gate]].
