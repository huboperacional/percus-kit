## Parser de "1/2" nascido numa pergunta numerada lê quantidade como sim/não no texto livre {#token-lista-numerada-vaza}

`tags: parser, sim/nao, yes/no, isYes, isNo, opcao numerada, lista numerada, texto livre, quantidade, numero da casa, falso positivo, helper reusado, opt-in, acao destrutiva, endereco apagado, par assimetrico`

**Origem:** tiatendo, 2026-07-31 — o bot descartou o endereço de um cliente porque ele pediu
"uma coca cola **2** litros".

Um parser de sim/não nasceu para uma pergunta com **opções numeradas** ("Responda: 1️⃣ Sim  2️⃣ Não")
e por isso tinha `"1"` em `_YES` e `"2"` em `_NO`. O mesmo helper passou a ser usado num fluxo de
**texto livre**, onde 1 e 2 não são opções — são quantidade, número de casa e nome de rua:

    isNo("quero uma coca cola 2 litros") -> True     isNo("rua 2 de setembro")  -> True
    isNo("apartamento 2")               -> True     isYes("1 marmita G")       -> True

- **A regra:** token de **opção numerada** só vale dentro da pergunta que **imprimiu a lista**. Fora
  dela, "2" é o número dois. Faça o modo numerado ser **opt-in** (`numbered=True`), nunca o default —
  assim o caller novo nasce seguro em vez de herdar a armadilha.
- **Como caçar:** não procure o helper; procure os **prompts numerados**
  (`grep -rn "1️⃣" --include=*.py`) e cruze com quem responde a eles. Depois varra os callers do
  helper no **repo inteiro** (inclusive `scripts/` e testes), não só no módulo.
- **Por que passa despercebido:** o dano não é exceção nem log — é uma decisão **plausível** tomada
  com a palavra errada. No caso medido, virou ação **destrutiva** (apagar endereço já coletado).
- **Espelho:** o mesmo projeto já tinha corrigido a direção oposta (o "1" do admin colidindo com a
  rotina matinal) e não olhou o outro lado. Corrigiu-se um lado do par assimétrico.

**Relacionado:** [Guarda contra ação destrutiva](guarda-destrutiva-testar-com-perguntas.md) — aqui o token errado ALIMENTA um guard cuja reação
ao "não" é destrutiva; os dois juntos transformam um pedido de bebida em perda de dado.
