## Régua por conta só vale onde o carimbo chega — meça conversão÷contato e contato÷clique antes de alocar verba {#carimbo-quebrado-inverte-a-regua-nas-duas-pontas}

`tags: midia paga, atribuicao, google ads, crm, hubspot, custo por reuniao, alocacao de verba, carimbo, utm, regua, auditoria de conta, R23`

**Sintoma:** uma conta de anúncios aparece com custo por resultado absurdo (US$ 24 mil por reunião,
124× a mediana) e vira candidata óbvia a corte. Outra aparece barata e vira candidata a receber a
verba. A decisão parece bem fundamentada — é um número medido, dividido corretamente.

**Causa raiz:** custo por resultado **por conta** exige que o contato chegue ao CRM **carimbado com
a campanha que o gerou**. Quando o carimbo falha, o numerador não chega e o gasto continua chegando
— a conta parece cara sem ser. E o inverso existe: uma conta pode **herdar** contatos que não gerou
(nomes de campanha replicados entre contas, integração que resolve o clique pela conta errada) e
parecer barata. **As duas coisas acontecem ao mesmo tempo, cada uma para um lado, e a régua não
erra por ruído: ela inverte a ordem.**

Medido no D4U (2026-09-07), conta a conta:

| conta | conversões (tag do cliente) | contatos no CRM | conv/contato | contato/clique | veredito |
|---|---|---|---|---|---|
| Brasil, em real (2025) | 20.838 | 18.982 | **1,1×** | 2,30% | sadio |
| Brasil + YouTube, dólar (2026) | 6.668 | **220** | **30,3×** | **0,14%** | não carimba |
| EUA, em real (2025) | 1.307 | 3.238 | 0,4× | 3,44% | sadio |
| EUA, em dólar (2026) | 144 | 6.691 | 0,02× | **82,73%** | herda crédito |
| Colômbia, dólar (2026) | 1.095 | **2** | **547×** | 0,01% | não carimba |

**Os dois testes, em ordem:**

1. **conversão da plataforma ÷ contato novo no CRM**, por conta e por período. Perto de 1 é sadio;
   acima de 5 ou abaixo de 0,05, a conta não é comparável às outras por régua de CRM. A conversão
   serve como controle porque é medida pela **tag do próprio cliente** — não depende da nossa
   atribuição.
2. **contato ÷ clique** — o clique a plataforma conta sozinha, sem tag nenhuma. É o desempate: a
   mesma praça, no mesmo site, nas mesmas campanhas, caiu de 2,30% para 0,14%; e nada real passa de
   ~10%, então 82,73% é crédito de outra conta.

**O que fazer quando o carimbo está quebrado:** **não escolha entre as contas afetadas.** Meça no
último período em que ele estava sadio (aqui, coorte de criação do contato de jan–nov/2025) e ordene
as decisões por **certeza**, não por tamanho:

1. cortar o que é ruim **com** carimbo sadio (era o desperdício invisível: 3 praças, US$ 28 mil/mês
   comprando 4,6 reuniões/mês — realocado, +20 reuniões/mês sem gastar a mais);
2. escalar o que é bom **com** carimbo sadio (a melhor praça custava US$ 165/reunião rodando
   US$ 930/mês, e nenhuma versão do plano a via);
3. **adiar** a comparação entre as contas cegas — no período limpo elas empatavam (US$ 1.155 ×
   US$ 1.196), e a régua quebrada é que fazia uma parecer 20× pior.

Consertar o carimbo vira o **pré-requisito nº 1** do plano: é o item de maior alavancagem, e não é
de mídia — é de instrumentação.

⚠️ Duas armadilhas ao medir isto:
- o campo de data de criação do contato pode ser **ISO-8601** onde o código assume epoch-ms (bug já
  visto duas vezes neste projeto);
- a ponte campanha→conta tem de ser **por mês**: contas paralelas (moedas ou MCCs diferentes)
  carregam os **mesmos nomes de campanha**, e uma ponte pelo total joga tudo na que gastou mais no
  histórico — apagando exatamente a transição que se quer enxergar.

Ver [[aviso-no-topo-nao-neutraliza-tabela-acionavel-abaixo]].
