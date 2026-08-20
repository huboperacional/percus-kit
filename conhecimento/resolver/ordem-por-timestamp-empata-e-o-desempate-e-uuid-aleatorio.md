## Ordem por timestamp empata, e o desempate por UUID sorteia a lista {#ordem-por-timestamp-empata-e-o-desempate-e-uuid-aleatorio}

`tags: flaky, ordenação, timestamp, uuid, relógio, sqlite, postgres, timeline, auditoria, teste intermitente`

**Sintoma:** um teste de ordenação falha "às vezes" — 1 em 5, 1 em 10 — e passa quando você o roda
sozinho para investigar. A lista volta embaralhada de um jeito que não é nem a ordem de inserção nem
a inversa: `['primeiro', 'terceiro', 'segundo']`. Como o teste passa na maioria das vezes, ele é
rotulado "flaky de ambiente" e ninguém olha de novo.

**A armadilha:** a consulta ordena por `criado_em DESC, id DESC`, o que parece cuidadoso — há
desempate. Mas:

1. **O relógio não tem a resolução que você supõe.** Registros criados na mesma requisição recebem
   o **mesmo** carimbo. Medido no Windows em 2026-08-19: **2000 chamadas** de
   `datetime.now(timezone.utc)` devolveram **DOIS** valores distintos — granularidade de ~1,1 ms.
2. **O desempate é UUIDv4**, que é aleatório e não tem relação nenhuma com a ordem de inserção.

Com o tempo empatado, a ordem sai **sorteada**. Para 3 registros, a chance de saírem na ordem certa
por acaso é 1 em 6 — o que casa exatamente com uma falha a cada 5 ou 6 execuções.

**Por que importa além do teste:** se a lista é uma timeline de auditoria, o usuário vê os eventos
fora de ordem. Não há erro, não há log, e a única pessoa que percebe é quem conhece os fatos — em
geral um contador ou um auditor, meses depois.

**Como confirmar em dois minutos**, antes de mexer em qualquer código:

```python
from datetime import datetime, timezone
vals = [datetime.now(timezone.utc) for _ in range(2000)]
print('distintas:', len(set(vals)))          # se vier 1 ou 2, o relógio empata
difs = sorted({(b-a).total_seconds() for a, b in zip(vals, vals[1:]) if b > a})
print('granularidade (ms):', difs[0]*1000)
```

**O que fazer:**

- **No produto** (a correção de verdade): dê **ordem total**. Uma coluna de sequência
  (`BigInteger` autoincremento) como desempate resolve com uma migration numa tabela que já existe.
  UUIDv7 também ordena por tempo, mas troca a geração de id de uma tabela de auditoria e **não
  conserta as linhas já gravadas**.
- **No teste**, enquanto o produto não muda: faça os registros acontecerem em instantes **de
  verdade** distintos (`await asyncio.sleep(0.005)` entre eles). Isso devolve ao teste a capacidade
  de exercer a cláusula `DESC` — que é o que ele promete no nome.
- **Prove que o teste voltou a medir algo**: remova o `.desc()` da consulta e veja o vermelho;
  restaure e confira que o `git diff` do arquivo de produção ficou vazio.

⚠️ **O conserto óbvio pode ser barrado pelo produto, e a barreira costuma estar certa.** Carimbar
`criado_em` à mão depois de criar o registro parece o caminho curto — e numa tabela de auditoria bem
feita ele levanta `EventoImutavelError`: evento de timeline não se edita. Quando a guarda recusa seu
conserto, a guarda está fazendo o trabalho dela.

**Não faça:** afrouxar a asserção para "contém os três itens" ou ordenar em memória no teste. As
duas apagam o sintoma e deixam a lista do usuário sorteada.

**Relacionado:** [[estado-atual-nao-prova-evento-passado]].
