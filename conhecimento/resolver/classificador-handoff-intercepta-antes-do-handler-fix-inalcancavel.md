## Classificador de handoff roda incondicionalmente ANTES do handler de confirmação — fix novo em `_processConfirmation` pode nascer morto {#classificador-handoff-intercepta-antes-do-handler-fix-inalcancavel}

tags: whatsapp, bot, confirmacao, handoff, classificador, regressao silenciosa, teste unitario pula camada, ambiguidade, reply novo ambiguo fallback, testes chamam funcao direto

**Sintoma:** um fix aplicado dentro do handler de um estado de confirmação (`_processConfirmation`)
tem 47 testes unitários passando, foi deployado há semanas, e continua **não funcionando** quando
testado ao vivo contra prod — a mensagem que deveria disparar o fix nunca chega nem perto dele; o
bot responde com um menu de ambiguidade genérico ("Não ficou claro o que você quis dizer...").

**Causa raiz:** existe uma camada de classificação (`handoff_detector.classificarMensagemPendente`)
que roda **incondicionalmente**, ANTES de qualquer handler de estado, sempre que a sessão está num
estado de confirmação pendente — decide se a mensagem é `reply` (segue pro handler normal), `novo`
(abre menu de gasto novo), `ambiguo` (abre menu de esclarecimento) ou `fallback`. Essa camada foi
escrita numa sessão ANTERIOR ao fix, e o fix novo assumiu (documentado no próprio docstring do
código) que "mensagens de X nunca chegam aqui, o guard já desvia antes" — mas o guard desviava só
UM tipo de mensagem (gasto novo com verbo+dinheiro), não o tipo que o fix precisava alcançar
(correção de data, que tem número mas não bate nenhum padrão de "reply" conhecido pelo
classificador) → cai em "ambíguo" → NUNCA chega no handler onde o fix mora. **Os testes do fix nunca
pegaram isso porque chamam a função do handler DIRETO** (`await _processConfirmation(texto, sessao,
...)`), pulando inteiramente a camada de classificação que roda no pipeline real.

**Solução:** quando um bot/pipeline conversacional tem MÚLTIPLAS camadas de classificação em
sequência (roteador de intent → classificador de estado pendente → handler do estado), um fix
dentro da camada mais interna (o handler) só é *alcançável de verdade* se TODAS as camadas
anteriores também souberem reconhecer o padrão novo como "deixa passar". Ao escrever um teste pra um
fix de handler, pelo menos UM teste tem que exercitar o PIPELINE INTEIRO (webhook → classificador →
handler), não só a função isolada — testes que chamam a função-alvo direto (`await
_handler(texto, ...)`) provam que o handler está certo, mas não provam que a mensagem CHEGA nele.
Um smoke/e2e ao vivo contra prod (ou um teste de caracterização do pipeline completo) é o que pega
esse tipo de regressão — testes unitários isolados por design não pegam.

**Ref:** Família Milionária, sessão 2026-08-07 — `handoff_detector.classificarMensagemPendente` +
`_isGenuineReply` em `familia-api/app/modules/whatsapp/handoff_detector.py`, vs. o fix de
`_detectDateCorrection` em `_processConfirmation` (commit `413d286`, 2026-07-24). Fix: novo
`is_date_correction()` em `correction_patterns.py` (módulo-folha compartilhado), ligado no
classificador. Achado por `execution/smoke_confirmando_ajuste_data.py` (script novo, injeta mensagem
real assinada no webhook de produção) — não pelos 47 testes unitários da 413d286, que datam de ANTES
desta descoberta e nunca detectaram o gap porque testam só o handler isolado.
