## "A cobertura da guarda é parcial" não é ordem de alargar — meça o que o alargamento QUEBRA, não só o que ele pega {#alargar-matcher-de-guarda-troca-miss-por-alvo-errado}

`tags: guarda, matcher, cobertura parcial, miss, falso positivo, prefixo, fuzzy, plural, normalizacao, correspondencia exata, pendencia que nao deve ser implementada, medir antes de codar`

**Sintoma:** existe uma pendência escrita como *"a guarda cobre só parcialmente — o caso X a
desliga em silêncio"*, e ela parece um TODO óbvio. O reflexo é afrouxar a correspondência
(prefixo, fuzzy, plural, substring) pra fechar o furo.

**Contexto (tiatendo, guarda de ancoragem de prato, 2026-08-12):** a pendência listava duas
sub-classes de miss — plural (`duas feijoadas` ≠ `Feijoada`) e nome parcial (`carne de panela` ≠
`Carne de Panela c/ Mandioca`).

**Causa raiz do engano:** a pendência media **só o que a guarda deixa passar**, nunca **o que o
alargamento passaria a pegar errado**. São duas direções, e só uma estava no texto.

**Medido, sobre 291 mensagens distintas de cliente em 60 dias + o cardápio real:**
- **plural: 0 ocorrências.** A sub-classe existia como mecanismo, não como fato.
- **nome parcial: 3 ocorrências**, nenhuma sendo o caso descrito na pendência.
- Alargar **por prefixo** resolvia o caso alvo e passava a casar **prato ERRADO** em
  `Strogonoff de Carne` → `Strogonoff de Frango` e `bife a milanesa` → `Bife a Cavalo` — pratos que
  **não existem naquele cardápio**, ou seja o cliente falava de outra coisa. **2 erros para 1
  acerto**, e o erro é exatamente o defeito que a guarda existe pra impedir.
- ⚠️ A saída "só aceita o prefixo quando ele casa com **um único** item" **não salva**: `strogonoff
  de` casa com exatamente um prato e mesmo assim é o prato errado. (Era a terceira via proposta por
  um membro do conselho, falsificada pela medição.)

**Solução:** antes de alargar qualquer matcher de guarda, rode as duas medições e compare:
1. **quantas ocorrências reais** a sub-classe tem no corpus (não quantas você imagina);
2. **o que o alargamento passa a casar ERRADO** — inclua de propósito frases que citam coisas
   *parecidas e inexistentes* no domínio (outro sabor, outro corte, outro prato).

Decida pela **assimetria de custo**, não pela cobertura: numa guarda que **falha aberta**, miss é
barato (o sistema segue como já seguia) e falso positivo é caro (a guarda age sobre algo que o
usuário não pediu). Cobertura parcial numa guarda fail-open pode ser o **projeto correto**, não
dívida. Feche a pendência com a medição anexada — senão alguém reabre daqui a três meses e
implementa o dano.

**Ref:** tiatendo, guarda C18, 2026-08-12. Conselho `consult` 3/3 por não implementar.
Irmão: [#rotulo-casa-dentro-de-palavra] (casamento curto demais pega a coisa errada no caminho do
dinheiro) e [#guarda-redundante-tesoura-ou-morta]. R23.
