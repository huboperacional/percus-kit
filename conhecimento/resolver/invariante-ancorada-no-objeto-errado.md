## Invariante ancorada no objeto errado passa hoje e quebra na fase seguinte {#invariante-ancorada-no-objeto-errado}

`tags: invariante, soma zero, TDD, teste primeiro, modelagem, conta de compensacao, liquidacao, agregacao mascara erro, conselho, pre-mortem, ADR`

**Contexto:** um desenho previa contas que não são banco (compensação, permuta, carteira de cheques, adquirente) e uma invariante financeira para garantir que dinheiro não vazasse para o saldo real. A primeira redação foi: *"a soma dos movimentos de uma **conta de compensação** é sempre zero"*. Parece certa e é fácil de testar.

**Dois defeitos, e o segundo é o que mata:**

1. **O tipo de conta era o eixo errado.** `carteira_cheques` e `adquirente` têm saldo **legítimo e permanente** — um cheque não depositado e um recebível D+30 são saldo de verdade, só não são saldo em banco. A invariante amarrada ao *tipo de conta* passaria no teste da fase 1 e **quebraria no primeiro cheque da fase 2**. E aí ela seria relaxada sob pressão de entrega, perdendo exatamente a guarda que existia para dar.

2. 🔴 **Soma agregada mascara dois erros que se compensam.** Uma operação lançada a mais e outra a menos zeram juntas, e a conta parece sã. A agregação por *lugar* não distingue "nada errado" de "dois erros que se anularam".

**Correção:** ancorar no **FATO**, não no lugar. A soma dos movimentos de uma mesma **liquidação** é zero. O eixo passou a ser a operação, e um único teste parametrizado passou a valer para todos os tipos de liquidação — triangulação, permuta, endosso, repasse, transferência.

**O sintoma que denuncia o eixo errado, e serve como pergunta de revisão:** *existe algum caso legítimo em que este objeto viola a invariante?* Se existe, o eixo está errado — não é o caso que é exceção, é a âncora.

**Corolário para o alarme:** o mesmo erro se repete na monitoração. "Alerta quando o saldo da conta ≠ 0" tem exatamente o defeito 2 — deve ser "alerta quando existir **fato** desbalanceado". Foi possível escrever as duas coisas em seções diferentes do mesmo documento sem notar a contradição.

⚠️ **Isto foi pego por pre-mortem do conselho, não por revisão própria.** Invariante errada é especialmente difícil de ver de dentro, porque ela **passa no teste que o autor escreveu** — o autor escolheu o teste e a âncora ao mesmo tempo, com a mesma premissa.

**Ver também:** [[guarda-de-schema-cobre-por-tipo]].
