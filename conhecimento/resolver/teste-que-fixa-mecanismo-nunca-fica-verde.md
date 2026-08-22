## Teste que fixa o MECANISMO nunca fica verde sob o conserto certo {#teste-que-fixa-mecanismo-nunca-fica-verde}

`tags: tdd, xfail, contrato-alvo, teste de comportamento, mecanismo vs comportamento, migracao, consolidacao, red-green, deteccao de intent, estado de sessao`

**Contexto:** ao migrar um sítio para um contrato comum, você escreve primeiro um teste que fixa o
defeito atual (`xfail(strict=True)`), pra que ele vire `XPASS` no instante do conserto e cobre a
remoção do marcador. O padrão é excelente — desde que o teste afirme o **comportamento**.

**O erro:** o card dizia *"me diga o nome"* e o nome não chegava ao handler, porque o portão de
entrada (`_detectIntent`) devolvia `None` pra um nome solto. Escrevi o teste assim:

```python
assert ph._detectIntent("fone") is not None
```

Isso fixa o **mecanismo** pelo qual o defeito se manifesta hoje. Mas o conserto certo não passa por
ali: depois da migração o nome é lido pelo **estado de sessão**, e `_detectIntent` continua — com
razão — devolvendo `None` pra uma palavra solta. O teste jamais ficaria verde, e "consertá-lo"
significaria afrouxar um gate de entrada que existe por bons motivos.

**A regra:** o `xfail` de contrato-alvo tem de afirmar **o desfecho que o usuário observa**, não o
caminho interno que hoje o impede. Reescrito:

```python
_, sessao, candidatos = await _emitirCard(...)
resp = await sitio.processSelection(candidatos[1]["nome"], sessao, usuario, session)
assert resp, "responder o nome que o card pede não resolveu a escolha"
```

**Como perceber antes de gastar o ciclo:** pergunte *"se eu consertar isto do jeito certo, esta
asserção fica verde?"*. Se a resposta depende de o conserto passar por um símbolo específico, o teste
está preso ao mecanismo. Um contrato-alvo bom sobrevive a qualquer implementação que cumpra a
promessa da copy.

**Corolário:** o mesmo vale pra sonda de diagnóstico. Uma sonda que chama o handler **direto** mede
o handler, não o produto — se a pergunta é de roteamento, ela mente. Ver
[[sonda-que-pula-o-roteador-mente]].
