# Loop: drift — auditar o que apodrece calado

**Quando — por evento, nunca por calendário:** ao fechar milestone ou bumpar versão. Operador solo não cumpre ritual de agenda; amarre no que já acontece de qualquer jeito.

**Por quê:** sem revisor externo, ninguém percebe o arquivo que foi de 61 para 200 linhas. Deriva é silenciosa por definição.

## O que checar

| Verificação | Sinal de problema |
|---|---|
| Todo `{#slug}` tem `(#slug)` no índice? | verbete órfão — escrito e invisível |
| Todo verbete tem linha `tags:`? | invisível à busca de conhecimento |
| Loop passou de 60 linhas? | virou referência disfarçada |
| Artefato de retomada passou de 150? | está virando log |
| `.percus-version` do projeto × canon | defasagem de adoção |
| Log de escape de gate | reincidência = desenho errado |

## O que fazer com o resultado

**Reporte, não conserte sozinho.** Deriva quase sempre tem causa; corrigir o sintoma sem a causa devolve o problema no mês seguinte.

**Exceção:** item mecânico e inequívoco (entrada de índice faltando) você corrige na hora e menciona no relatório.

## O que a reincidência conta

Um loop que estoura o teto **uma vez** foi descuido. Que estoura **quatro vezes** não é um loop — é referência no arquivo errado. Proponha a partição, não mais disciplina.

## Armadilha

Auditoria que só produz relatório vira ruído em duas rodadas. Todo achado precisa **virar ação** ou ser **explicitamente aceito e registrado** — nunca ficar pairando. Aceito → linha no HANDOFF (`Desvio aceito: … — motivo`); se a aceitação é durável/estrutural → ADR. Pulos de TDD: conte `tdd: pulado` no PLANO.
