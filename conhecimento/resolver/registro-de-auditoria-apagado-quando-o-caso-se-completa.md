## O registro de auditoria é apagado justamente quando o caso se completa — e a proteção existe, só que num caminho só {#registro-de-auditoria-apagado-quando-o-caso-se-completa}

`tags: auditoria, indice parcial, soft delete, limpeza de estado, maquina de estados, protecao em um caminho so, recuperacao apaga historico, review de marco, correcao ingenua tem efeito colateral, R23`

**Origem:** Paid Media Automation, 2026-09-06 — milestone review cross-provider **depois** do deploy
do vigia de conta inativa.

**O caso.** A tabela de contadores guarda `deactivated_at` — o carimbo de "o robô desativou este
cliente, e quando". A migration criou um índice parcial só para isso, com o propósito escrito no
próprio SQL: *"a auditoria 'quem o robô desativou, e quando'"*. A varredura de órfãos protege esse
registro **de propósito e com teste dedicado**:

```python
orfas = [s for s, linha in linhas.items() if linha.get("deactivated_at") is None]
```

Mas os **outros dois** caminhos que apagam linha não filtram nada — na recuperação
(`limpar = tuple(sorted(linhas))`) e na troca de sinal
(`outros = tuple(... if s != sinal)`), ambos consumidos por um `DELETE` incondicional.

🔑 **E o caminho desprotegido é o NORMAL, não o raro.** O ciclo completo é: cliente é desativado
pelo robô → um humano religa → o cliente volta a se comportar → no tick seguinte o sinal é bom →
"voltou" → **apaga tudo**. Ou seja: a linha de auditoria sobrevive enquanto o caso está em aberto e
morre exatamente no momento em que ele vira história — que é quando alguém iria querer consultá-la.
O índice parcial fica tecnicamente correto e praticamente vazio.

**O padrão a procurar (é o que generaliza):** quando um estado acumula duas responsabilidades —
*contador vivo* (some quando não vale mais) e *registro histórico* (deve ficar) — a limpeza escrita
para a primeira apaga a segunda. A proteção costuma ser adicionada no caminho onde alguém pensou no
problema, e **os caminhos irmãos ficam de fora**. Procure por: quantos lugares apagam esta linha? Um
deles tem um filtro que os outros não têm? Esse filtro é uma regra de negócio ou uma lembrança
isolada?

⚠️ **Por que a correção ingênua não serve — e por que isso vira decisão, não tarefa.** Filtrar
`deactivated_at is not None` no `DELETE` faz a linha **nunca morrer**; e como o mesmo código decide
"o cliente voltou" por *existir linha*, o job passaria a anunciar "voltou" **todo dia, para sempre**.
O ramo de linha zumbi (streak 0) reapaga pelo mesmo caminho, então também mudaria. A correção
honesta exige separar "linha viva" de "linha morta (só auditoria)" em três pontos de uma máquina de
estados — o que é caro em cima de código recém-deployado.

**Como aplicar.** Ao achar um defeito assim num review **pós-deploy**, resista aos dois extremos.
Não conserte às pressas (mexer em 3 pontos de uma máquina de estados recém-subida troca perda de
histórico por risco de desativação errada), e não anote "bug de auditoria" e siga (some). Registre
**o cenário concreto que dispara** + **por que a correção óbvia não funciona** — o segundo item é o
que impede a próxima sessão de tentar o filtro de uma linha, quebrar, e reverter. Severidade real
aqui: perda de histórico, não de segurança — ninguém é desativado a mais, a menos, nem com menos
avisos do que o prometido. Isso é o que autoriza adiar com a consciência limpa.

Relacionado: [[watchdog-de-ausencia-le-depois-do-produtor]].
