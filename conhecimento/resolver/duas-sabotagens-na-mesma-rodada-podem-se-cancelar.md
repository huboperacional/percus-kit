## Duas sabotagens na mesma rodada podem se cancelar — e o teste que sobra verde parece cobertura {#duas-sabotagens-na-mesma-rodada-podem-se-cancelar}

`tags: sabotagem, mutation testing, guarda, falso verde, vacuidade, cobertura, teste de teste, RLS, contexto, R23`

**Sintoma:** você sabota dois pontos do código na MESMA execução para economizar rodada, esperando
que caiam dois conjuntos de testes. Caem quase todos — e **um teste fica verde**. A leitura óbvia é
"esse teste não discrimina, vou apagá-lo" (errado) ou "está tudo provado" (pior).

**Causa raiz:** as duas sabotagens não são independentes. Uma delas **remove a pré-condição** que
torna a outra observável.

**Caso medido (2026-09-10, consolidado de grupo sob RLS):** o caso de uso troca o contexto de tenant
a cada empresa do laço e **restaura o contexto de entrada** no fim. Sabotei os dois:

| # | Sabotagem | Esperado |
|---|---|---|
| 1 | a troca de contexto por empresa | os testes que atravessam N empresas caem |
| 2 | `_restaurarContexto` | o teste "o contexto volta ao de entrada" cai |

Resultado da rodada com as duas: **5 vermelhos e o teste do restauro VERDE**. Motivo, óbvio depois:
sem a sabotagem 1 o contexto **nunca sai do lugar**, então "ele volta ao de entrada" é trivialmente
verdadeiro. A sabotagem 1 tornou a 2 **inobservável**.

Aplicando a 2 **sozinha**, exatamente aquele teste caiu — e só ele.

**Correção:** sabotagem em lote só vale quando cada uma atinge um teste **diferente** e nenhuma pode
mascarar a outra. Quando duas mexem no MESMO mecanismo — tipicamente **uma que desliga a ida e outra
que desliga a volta** (setar/restaurar, abrir/fechar, adquirir/liberar, marcar/desmarcar) —, rode
isolado.

**A regra de leitura que economiza o erro:** numa rodada de sabotagem, o sinal de alerta é **o teste
que NÃO caiu quando você esperava que caísse**. É ele que precisa de rodada própria — não o que já
ficou vermelho. Contar o verde dele como cobertura é
[[a-guarda-que-nao-pode-falhar-mora-no-instrumento]] com outra roupa: a guarda que nunca cai é
confiança fabricada, e aqui quem a impediu de cair foi você mesmo, na mesma chamada.

Parente de [[a-sabotagem-prova-o-que-voce-imaginou]] — lá o limite é a classe que você não imaginou;
aqui é a classe que você imaginou e **apagou sem querer** antes de medir.
