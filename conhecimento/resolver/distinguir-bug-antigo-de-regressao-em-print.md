## Distinguir bug antigo (já corrigido) de regressão nova ao receber print de conversa real {#distinguir-bug-antigo-de-regressao-em-print}

`tags: print de conversa, whatsapp, hora local do aparelho, regressao ou bug antigo, timestamp relativo, Today, triagem de relato, evidencia do operador`

**Sintoma:** operador manda screenshot de uma conversa real do WhatsApp mostrando um bug que "parece"
já ter sido corrigido numa sessão anterior — risco de (a) assumir que é regressão e sair caçando o
que "quebrou de novo" sem necessidade, ou (b) assumir que já está resolvido sem checar e ignorar uma
regressão real.

**Solução:** o app do WhatsApp mostra hora local do aparelho e agrupa por "Today" relativo a QUANDO
o screenshot foi tirado — não é confiável pra saber se aconteceu antes ou depois de um deploy do
mesmo dia. Achar a conversa exata no banco por conteúdo (`messages.content ILIKE`), pegar o
`created_at` (sempre UTC), e comparar contra o horário REAL do deploy/commit do fix (não só o texto
"hoje"). Se o fuso do operador for BRT (UTC-3), uma conversa "de ontem à noite, tipo 22h" pode cair
como UTC do dia SEGUINTE — o oposto do que a intuição sugere. Prova mais forte que só timestamp:
achar uma ocorrência IDÊNTICA do mesmo cenário numa conversa DIFERENTE, depois do deploy, e checar se
o comportamento lá já saiu correto — evidência comportamental direta bate qualquer inferência de
timestamp.

**Ref:** tiatendo, sessão 2026-08-07 (bug de desambiguação multi-sabor — conversa reportada era de
ANTES do fix `0.291.0`, não regressão).
