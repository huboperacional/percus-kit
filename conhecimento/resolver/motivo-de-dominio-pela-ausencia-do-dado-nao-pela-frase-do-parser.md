## Enum de domínio decidido por substring da mensagem de erro de uma biblioteca de terceiro troca de valor em silêncio quando a biblioteca muda a redação {#motivo-de-dominio-pela-ausencia-do-dado-nao-pela-frase-do-parser}

`tags: parser, biblioteca de terceiro, mensagem de erro, substring, enum, motivo, ofxparse2, OFX, FITID, discarded_entries, fail_fast, classificacao, fragilidade, review`

**Medido (Empresa Milionária, 2026-09-14, leitor de extrato OFX com `ofxparse2`).** Com `fail_fast=False`, o
`ofxparse2` separa a transação que não conseguiu montar em `statement.discarded_entries`, como
`{'error': <frase>, 'content': <bs4.Tag do bloco>}`. O leitor precisava distinguir dois motivos para a tela: **sem
identificador do banco** (FITID vazio ou ausente) e **ilegível** (valor ou data que não se leem). A primeira versão
decidia assim:

```python
motivo = SEM_IDENTIFICADOR if "FIT id" in erro else ILEGIVEL
```

As frases de hoje são `Empty FIT id (a required field)` e `Missing FIT id (a required field)`, e os testes
parametrizados passavam — porque casavam a frase de hoje. O review cross-provider apontou o defeito: se a biblioteca
trocar a redação (`FITID missing`, tradução, pontuação), a transação sem FITID passa a sair como "ilegível", **nenhum
teste falha**, e a tela nomeia o motivo errado para quem decide o que importar.

**O conserto:** decidir pelo DADO, não pela frase. O bloco descartado ainda está lá; o FITID está presente ou não:

```python
identificador = textoDoCampo(bloco, "fitid") or None
motivo = SEM_IDENTIFICADOR if identificador is None else ILEGIVEL
```

**A prova que discrimina:** um teste que chama a função com uma frase que a biblioteca **ainda não usa** e um bloco sem
FITID — tem de dar "sem identificador". Sabotado (regra de volta para a substring), esse caso quebra e o caso de
controle (erro de valor com FITID presente) continua verde.

**Como aplicar:**

- Mensagem de erro de biblioteca de terceiro serve para **exibir** e para **log**, nunca como chave de decisão de
  domínio. Se a decisão precisa de um motivo, procure o dado que o motivo descreve (campo ausente, tipo, valor fora de
  faixa) na estrutura que acompanha o erro.
- Quando não houver estrutura e a frase for a única fonte, isole a correspondência numa função com teste que cita a
  versão da biblioteca medida — e trate a queda no ramo "desconhecido" como sinal visível, não como classificação.
- Teste parametrizado com as frases de hoje **não** protege contra isto: ele confirma a redação atual, não a regra.
  O teste que protege usa uma frase que ainda não existe.

Primos: [zero-so-vale-como-prova-com-controle-positivo](zero-so-vale-como-prova-com-controle-positivo.md) (o caso de
controle é o que separa "a regra funciona" de "o teste não exercita nada").
