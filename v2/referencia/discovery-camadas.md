# Catálogo de camadas de discovery — detalhe do `loops/grilling.md`

Não é checklist rígido nem questionário fixo — é referência de cobertura, lida sob demanda
durante o grilling, pra garantir que nenhuma categoria de alto impacto fique de fora só porque
ninguém lembrou de perguntar. `loops/grilling.md` continua sendo o procedimento (uma pergunta por
vez, sempre com recomendação); este arquivo é o detalhe.

**Origem:** adaptado de um framework de entrevista de requisitos que o operador discutiu com
GPT (14 camadas, priorização por impacto/incerteza, rodadas, estado estruturado), cross-validado
contra os blocos 0/A-N do MDS (Modular Development Style) e contra o gap que o `grilling.md`
original já tinha. Três fontes independentes convergindo na mesma forma — sinal de que a
estrutura em camadas é real, não coincidência de uma fonte só.

## Priorização — qual pergunta vem primeiro

```
Prioridade = Impacto da resposta × Incerteza × Risco de erro ÷ Custo de perguntar
```

| Nível | Significado | Exemplo |
|---|---|---|
| **P0** | Bloqueia a definição da solução — muda arquitetura | "Os 200 leads disparam simultâneos ou em fila?" |
| **P1** | Pode causar retrabalho ou prejuízo se errado | "É multi-tenant, ou só parece que não vai precisar?" |
| **P2** | Necessária pra implementar, não muda desenho | "Qual biblioteca de fila vocês já usam?" |
| **P3** | Necessária pra acabamento | "Qual texto vai no toast de sucesso?" |
| **P4** | Preferência ou melhoria futura | "Qual cor tem o botão?" |

Pergunte P0/P1 da camada atual antes de abrir a próxima camada. P3/P4 podem esperar até o fim ou
nem chegar a ser perguntadas se o tempo for curto — não bloqueiam nada.

## As camadas

Cobertura ampla, não formulário linear — uma resposta costuma abrir ramos novos dentro da mesma
camada (ex.: "quantos números de WhatsApp?" → "dois" → "cada um tem fila própria? credenciais do
mesmo cliente?"). Pule camada irrelevante ao tipo de projeto (nem todo projeto é máquina de
estado, por exemplo) — "N/A, motivo" é resposta válida, silêncio não é.

1. **Problema** — qual dor, quem sofre, como é resolvido hoje, por que agora (não em outro momento).
2. **Objetivo/Resultado** — o que precisa existir no fim; critério de sucesso mensurável; o que é
   obrigatório vs. só desejável.
3. **Atores** — quem opera, quem administra, quem recebe o resultado, quem aprova, quem **não**
   pode acessar o quê.
4. **Aposta/Horizonte** *(camada própria desta sessão — não vem do GPT nem do MDS)* — é aposta
   estratégica de longo prazo ou validação rápida pra descartar se não vingar? Existe prazo/evento
   externo que force uma data? Entre "lançar rápido e feio" e "mais devagar e sólido", qual dói
   mais errar?
5. **Escala/Porte** *(idem)* — poucos usuários internos ou escala real esperada? Projeção pro fim
   do 3º/6º/12º mês? Uso concentrado (pico) ou distribuído? Se "poucos" virar "um cliente grande
   topou usar amanhã", qual seria a maior surpresa hoje na arquitetura?
6. **Gatilhos estruturais** — persistência? multi-tenant? dado regulado (LGPD/HIPAA/PCI)?
   endpoint público? **Estes 4 sempre precipitam pra mini-tabela do `CLAUDE.md`** (ver
   `templates/CLAUDE.template.md`), independente do resto da entrevista.
7. **Fluxo principal** — caminho normal, etapas, qual sistema executa cada uma, o que entra/sai.
8. **Regras de negócio** — o que pode/não pode, limites, horários, prioridades, exceções.
9. **Estados** — que estados uma entidade assume (pendente/processando/concluído/falhou/cancelado)
   — só relevante se o projeto tem itens com ciclo de vida.
10. **Exceções e falhas** — API cair, duplicidade, usuário mudar algo no meio, sistema reiniciar,
    operação durar dias.
11. **Integrações** — quais sistemas participam, quem inicia a comunicação, autenticação, quem é
    a fonte oficial de cada dado.
12. **Operação** — quem configura, quem monitora, como pausar/retomar/corrigir/reprocessar.
13. **Segurança e conformidade** — dados sensíveis, quem vê, onde ficam credenciais, obrigação
    legal ou contratual (aprofunda o gatilho "dado regulado" da camada 6).
14. **Critérios de aceite** — que teste prova que terminou, o que nunca pode acontecer, quais
    casos extremos testar.

## Tipos de pergunta (além da factual)

Perguntas de **cenário** ("imagine 200 leads pendentes às 18h50 — o que acontece?") e de
**consequência** ("se o operador mudar a mensagem no meio da campanha, quem já está na fila
recebe o texto velho ou o novo?") revelam requisito que o próprio operador ainda não tinha
percebido — usar quando a pergunta factual direta não tira a incerteza.

## Rodadas

5-8 perguntas por rodada, cada rodada com objetivo de 1 frase declarado antes de perguntar
("Rodada atual: horizonte do projeto. Objetivo: decidir se isso é aposta ou validação."). P0/P1
da rodada resolvidos antes de abrir a próxima camada.

## Critério de parada (mensurável, substitui "sensação de que já perguntou bastante")

- Cobertura ≥85% das camadas relevantes ao projeto (camadas puladas por N/A não contam contra).
- Zero lacunas P0.
- Riscos P1 com decisão ou mitigação registrada — não precisam estar resolvidos, precisam estar
  **decididos ou com plano**.
- Fluxo principal descritível ponta-a-ponta.
- Critérios de aceite escrevíveis.

## O que não foi adotado do material original

O objeto de estado em JSON validado por schema de API (útil quando existe uma segunda IA
auditando via chamada de API, como no material que o operador trouxe) foi descartado aqui —
overkill de engenharia pra uma conversa Percus sem esse segundo auditor automatizado. O
princípio (rastrear cobertura por camada durante a entrevista) fica; o mecanismo (JSON Schema +
endpoint) não. Estado de trabalho durante a entrevista pode ser texto estruturado simples,
**descartável ao final** — só o que sobrevive vira ADR / `CONTEXT.md` / spec / mini-tabela do
`CLAUDE.md`, pela tabela "o que precipita ao final" de `loops/grilling.md`.
