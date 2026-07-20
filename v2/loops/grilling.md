# Loop: grilling — extrair intenção

**Quando:** antes de qualquer feature não-trivial ou projeto novo. O operador também dispara na mão ("me grelha", "estressa esse plano").

**Por quê:** o modo de falha caro não é código errado — é código **certo para o problema errado**. Este loop gasta 40 minutos de pergunta para poupar 3 dias de retrabalho.

## O loop

1. **Entreviste até haver entendimento compartilhado.** Não é questionário fixo: percorra a árvore de decisão resolvendo dependências na ordem — decisão que trava outras vem primeiro.
2. **Uma pergunta por vez.** Espere a resposta antes da próxima. Várias juntas confundem, e o operador responde só a última.
3. **Toda pergunta vem com a sua recomendação.** "Eu faria (a), porque X." Confirmar ou corrigir é muito mais barato que redigir do zero.
4. **Fato você descobre; decisão você pergunta.** Se dá para responder lendo o código, o `.env`, o git ou a API — leia. Perguntar o que você podia descobrir queima a paciência do operador e o crédito das perguntas que importam.
5. **Não aja até o operador confirmar** que chegaram no mesmo entendimento.

## O que precipita ao final

Grilling não termina em conversa — termina em artefato:

| O que emergiu | Vai para |
|---|---|
| Decisão difícil de reverter, surpreendente, com trade-off real | `docs/adrs/` |
| Termo de domínio ambíguo que vocês fixaram | `CONTEXT.md` |
| O que construir, com critério de pronto | spec (`loops/spec.md`) |
| O que ficou fora | spec, seção "não-objetivos" |

## Armadilhas

- **Parar cedo.** Se após 3 perguntas você "já sabe o que fazer", provavelmente entendeu o problema raso. Sessões reais chegam a 30-50 perguntas.
- **Perguntar o óbvio para parecer diligente.** Treina o operador a responder no automático — e aí a pergunta que importava passa batida.
- **Aceitar termo vago.** "Cadastro", "conta", "cancelamento": se o termo tem duas leituras possíveis, fixe agora ou pague depois.

> Adaptado de `grill-me` / `grilling` (mattpocock/skills, MIT).
