## Mutação que SOBREVIVE pode ser guarda redundante, não teste fraco — meça antes de fabricar teste {#mutacao-sobrevive-por-guarda-redundante}

tags: mutacao sobreviveu, teste nao morre com a mutacao, teste decorativo, mutation testing verde, guarda redundante, ancora e match redundantes, test-fitting, fabricar teste pra fechar placar, defesa em profundidade nao pinada

**Sintoma.** Você especifica uma mutação pra provar que um teste tem dentes ("tire a âncora `^` da
regex e o teste deve ficar vermelho"), aplica, e **a suíte segue verde**. A conclusão automática é
"o teste é decorativo, preciso escrever um que mate essa mutação".

**Antes disso, meça POR QUE sobreviveu.** Em código com defesa em profundidade, duas guardas
independentes frequentemente protegem a mesma propriedade. Mutar **uma** deixa a outra em pé, e o
teste continua verde **corretamente** — ele testa o comportamento, e o comportamento não mudou.

Dois casos reais na mesma sessão (tiatendo, C17):
- regex `^\s*\d+×\s.+\s—\sR\$…`: tirar as âncoras não matou os controles negativos, porque quem
  protege as frases-alvo é o prefixo `\d+×` — nenhuma delas contém o caractere `×` (U+00D7). A
  mutação fiel ao risco documentado (tirar o **prefixo**) derrubou os dois controles na hora.
- a mesma regex com `.match()`: trocar `.match` por `.search` também sobreviveu, porque `^`
  continuava lá — `^` + `.match` são redundantes entre si. A mutação que desancora de verdade é
  tirar os dois.

**O anti-padrão a evitar.** Fabricar um teste só pra fazer a mutação especificada ficar vermelha é
**test-fitting**: você acopla o teste à implementação (à regex, ao método) em vez de ao
comportamento, e ele passa a quebrar em refactor legítimo. Se nenhum texto real do sistema exercita
a mutação, o teste que a mataria seria inventado — e um teste inventado é pior que a lacuna.

**O que fazer.** (a) Descubra qual guarda de fato protege; (b) rode a mutação **fiel ao risco que o
comentário/doc do código declara**, não a que você imaginou; (c) se a guarda redundante não tem
teste e existe um produtor REAL que a exercitaria, escreva o teste sobre **esse produtor**; (d) se
não existe produtor real, registre como defesa em profundidade não-pinada e siga — é honesto.
