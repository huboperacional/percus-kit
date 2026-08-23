## A evidência do turno some quando o container é substituído {#evidencia-de-turno-expira-com-o-ciclo-do-container}

`tags: evidencia, container, docker, log, deploy, observabilidade, llm, quality-event, prova, [5-T]`

**Contexto.** Um requisito de medição pedia nomear *por que* um componente falhou num turno
específico, e declarava a evidência admissível como **"o log de execução E o evento de qualidade, os
dois"** — o motivo escrito era que *"log sem evento não distingue 'não foi chamado' de 'chamado e
voltou vazio'"*. Quando a medição foi executada, a metade do log **não existia mais**.

**Causa raiz.** `docker logs` só enxerga a vida do container **atual**. O deploy seguinte cria um
container novo, e o anterior é removido — junto com todo o log dele. No caso medido, o turno era de
**20/08 12:32** e o container em pé tinha nascido no deploy de **22/08 22:48**: `grep` no log
retornava **zero** para o período, não porque nada aconteceu, mas porque a janela inteira era
anterior ao processo. A primeira linha do `docker logs` é o carimbo dessa fronteira.

⚠️ **O modo de falha perigoso não é perder a prova — é LER O VAZIO COMO RESPOSTA.** "Não há linha de
log do componente" parece dizer *"ele não foi chamado"*, e essa é exatamente a conclusão errada.

**Solução.**
1. **Meça a fronteira antes de concluir qualquer coisa:** `docker logs <cid> | head -2` dá o instante
   em que o container nasceu. Se o evento investigado é anterior, **o log não é evidência de nada** —
   nem a favor, nem contra.
2. **Prefira evidência que mora no BANCO.** Evento de qualidade e linha de mensagem sobrevivem ao
   ciclo do container; log, não. Requisito que exige log como metade obrigatória da prova nasce com
   prazo de validade embutido.
3. **A ORDEM DO CÓDIGO substitui o log, e é mais forte para a pergunta "foi chamado?".** Se existe um
   evento emitido **a jusante** da chamada — num caminho que só é alcançado *depois* dela e que um
   retorno não-vazio teria desviado —, a existência desse evento **prova** que a chamada aconteceu e
   voltou vazia. Foi isso que salvou a medição: evento a jusante + flag ligada + a fala que saiu
   eliminaram as três hipóteses sem uma linha de log.
4. **Emenda honesta, não afrouxamento:** se você trocar o critério de evidência, **escreva por que o
   substituto responde a MESMA pergunta** que o original protegia. Sem isso vira flexibilização
   silenciosa do gate.

🔑 **Regra prática:** *colha evidência de turno no MESMO ciclo de container em que ele aconteceu.*
Se a investigação atravessa um deploy, a parte de log já morreu — planeje a prova sem ela.

🪤 **Corolário para o caminho silencioso.** O componente investigado logava as três falhas e emitia
evento no sucesso, mas *"chamado, respondeu, e não selecionou nada"* **não logava nem emitia**. Essa
combinação — caminho sem rastro + log expirado — torna o caso **estruturalmente indeterminável** pela
instrumentação. Quando encontrar um, registre o resíduo: o próximo caso será igualmente invisível, e
o conserto costuma ser **uma linha**.

**Relacionado:** [alarme-falso-mata-o-alarme](alarme-falso-mata-o-alarme.md) ·
[guarda-que-mede-o-eixo-que-ela-mesma-escreve-e-inerte](guarda-que-mede-o-eixo-que-ela-mesma-escreve-e-inerte.md)

**Ref:** tiatendo, N36 `RF11`, 2026-08-23 — medição em PROD `0.326.0`.
