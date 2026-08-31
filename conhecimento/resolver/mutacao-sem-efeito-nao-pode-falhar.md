## Mutação que produz o MESMO resultado não pode falhar — e o sintoma é idêntico a teste fraco {#mutacao-sem-efeito-nao-pode-falhar}

`tags: mutacao sobreviveu, mutation testing, falso verde, teste fraco, regra de escolha, max min, ordem de insercao, prova por mutacao, R11, instrumento de medida`

**Sintoma.** A mutação **aplica** (a âncora casou, o arquivo mudou), não há guarda redundante em pé,
e mesmo assim o teste segue verde. A conclusão automática é "meu teste não prova nada" — e ela leva
a reescrever um teste que estava correto.

**Antes disso, pergunte:** *a mutação chega a mudar o resultado para a entrada que o teste usa?*

**Caso medido (Plexco Tasks, 2026-08-30).** A regra sob teste era "vence o rótulo declarado em mais
PROJETOS DISTINTOS":

```python
mais_projetos = max(len(v["projetos"]) for v in variantes.values())
```

A mutação trocou por "pega o primeiro item":

```python
mais_projetos = len(next(iter(variantes.values()))["projetos"])
```

Verde. Mas a fixture inseria o vencedor primeiro, e dicionário em Python preserva ordem de inserção
— **o primeiro item JÁ ERA o vencedor**. A mutação produzia exatamente o mesmo output do original.
Ela não podia falhar, porque não mudava nada.

Trocada por `min(...)` — a **inversão** da regra —, ficou vermelha na hora.

**Regra prática.** Para provar uma regra de ESCOLHA (maior, mais recente, mais frequente, primeiro
por ordem), a mutação tem que **inverter o critério**, não substituí-lo por outro que possa
coincidir. Substituições que "parecem diferentes" mas convergem na fixture — pegar o primeiro,
pegar o último, ordenar por outro campo empatado — são mutações sem efeito.

**Por que isto é sério.** É o modo de falha do teste vácuo **um nível acima**: em vez de o teste
mentir sobre o código, o instrumento mente sobre o teste. E a conclusão errada é destrutiva —
reescrever ou "reforçar" um teste que já estava certo, gastando o orçamento no lugar errado.

Irmãos, e como distinguir dos três:
- [Mutação que não casa o padrão](mutacao-que-nao-casa-finge-que-o-gate-nao-reprova.md) — a
  ferramenta **não aplicou** (padrão errou, `sed`/`perl` saem 0). Aqui aplicou.
- [Mutação sobrevive por guarda redundante](mutacao-sobrevive-por-guarda-redundante.md) — aplicou,
  mas **outra guarda** segura o comportamento. Aqui não há outra guarda.
- [A sabotagem prova o que você imaginou](a-sabotagem-prova-o-que-voce-imaginou.md) — a amostra
  cobre a classe errada. Aqui a classe é a certa; o **valor** é que coincide.
