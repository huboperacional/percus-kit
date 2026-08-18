## Smoke que depende de serviço externo precisa distinguir DEGRADADO de ERRADO {#smoke-degradado-vs-errado}

`tags: smoke producao, servico externo fora, cota estourada, sem credito, INCONCLUSIVO vs FALHOU, falso alarme, diagnostico, caminho deterministico, fallback de erro, LLM indisponivel`

**Sintoma.** O smoke de produção passa a reportar o alarme mais grave que ele sabe emitir (ex.:
*"FALSO NEGATIVO — ação legítima engolida"*), e o produto está correto. A causa é externa: cota de
API estourada, provedor fora, credencial vencida.

**Causa.** O smoke afirma sobre COMPORTAMENTO usando um caminho que depende de terceiro. Sem o
terceiro, a mensagem não alcança handler nenhum — e "não aconteceu nada" é indistinguível de
"aconteceu errado" para uma asserção negativa.

**Correção.**
- Detecte a resposta de fallback do próprio produto e reporte **INCONCLUSIVO** (não mediu), nunca
  FALHOU (produto errado). Bloquear os dois é correto; o que muda é o **diagnóstico**, e é ele que
  decide se a próxima sessão vai caçar um defeito inexistente.
- Melhor ainda: tenha **pelo menos um caso que não dependa do terceiro**. Caminhos determinísticos
  (regex/roteamento que roda antes da chamada externa) provam a mudança mesmo com o serviço fora —
  foi o único caso que deu PASS ao vivo numa noite com a API de LLM sem crédito.
