## O caso que ANCORA a ausência dá PASS por mérito do bug quando o caso irmão falha {#caso-ancora-da-ausencia-passa-por-merito-do-bug}

`tags: smoke, prova por ausencia, ancora positiva, acoplamento de estado entre casos, condicao inicial, INCONCLUSIVO, falso verde, caso A caso B, ordem dos casos`

**Contexto.** O padrão certo, e já consolidado: nunca asserte só por ausência — **ancore num
positivo medido na MESMA rodada**. CASO A = *"esta frase não pode escrever"*; CASO B = *"o caminho de
escrita está vivo quando a frase é legítima"*. Sem o B, o PASS do A também seria verdade se a
mensagem nunca tivesse chegado.

**O buraco que sobra.** Se os dois casos rodam sobre **o mesmo registro**, existe um acoplamento de
estado invisível:

```
CASO A  frase indevida  -> PASS exige  ativa / 200.00 / 0 lançamentos
CASO B  frase legítima  -> PASS exige  quitada / 0.00 / 1 lançamento
```

**Se o CASO A FALHAR, o próprio defeito já deixou o registro em `quitada / 0.00 / 1` — que é
exatamente o estado que o CASO B chama de sucesso.** O B passa sem exercitar nada, e o PASS do B é
justamente o que dá crédito à ausência medida no A. O relatório diz "1 falhou, 1 passou" quando na
verdade **nada foi medido**, e a metade que passou é a que sustenta a outra.

**Solução — guarda de CONDIÇÃO INICIAL.** Todo caso que depende do estado deixado por um caso
anterior lê o estado antes de agir e, se não for o esperado, registra **INCONCLUSIVO com a razão**,
nunca avalia o assert. `INCONCLUSIVO ≠ FALHOU ≠ PASS` — os três desfechos precisam existir.

```python
estadoInicial = lerEstado(alvo)
if estadoInicial != ESPERADO_APOS_CASO_A:
    registrar(caso, ok=False, inconclusivo=True,
              detalhe=f"condicao inicial degradada apos o CASO A: {estadoInicial}")
    return
```

**Meta-lição, e é metade do valor.** Este achado veio de um **review cross-provider** e era **REAL**.
A regra "confirme cada finding EXECUTANDO" existe porque o review erra muito — mas executar serve
**pros dois lados**: confirma os falsos e salva dos verdadeiros. Histórico de refutação não autoriza
ler o próximo finding com desdém.

Ver também [[dois-cards-no-mesmo-estado-a-ordem-dos-ifs-esconde-opcoes]] e
[[protecao-acidental-depende-do-comprimento-do-dado]].
