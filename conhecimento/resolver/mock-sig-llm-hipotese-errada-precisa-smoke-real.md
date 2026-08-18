## Fix de guard dependente de sinal do LLM passa 100% dos testes (mockados) e reproduz em PROD — o mock provou a hipótese ERRADA sobre o que o LLM extrai {#mock-sig-llm-hipotese-errada-precisa-smoke-real}

`tags: llm, sig, mock, tdd, teste mockado, hipotese errada, root cause, guard, cancelamento, desired cart, structured output, tool call, smoke real, reproduzir em prod, deterministico, backstop, contrato mockado nao substitui sistema vivo`

**Contexto:** tiatendo, 2026-08-03. Achado no smoke (C14): `"mudei de ideia, vou retirar"` no
meio de um pedido abandonava o rascunho inteiro em vez de trocar o modo de entrega. 1ª hipótese:
o guard de cancelamento (`sig["cancel"]`) não checava se `sig["delivery"]`/`sig["payment"]`
também vieram no mesmo turno — fix aplicado, TDD com `sig[]` mockado à mão (`DesiredCart(cancel=
True, delivery="takeout")`), suíte inteira verde (2510 passed), deployado. **Re-smoke ao vivo em
PROD reproduziu o bug de novo, idêntico.**

**Causa raiz:** o teste mockava um `sig` que **nunca acontece de verdade**. Medido ao vivo (logs +
banco): pra essa frase o LLM devolve `cancelar_pedido=true` com `entrega`/`pagamento` **VAZIOS** —
ele não ignora o segundo sinal, ele nunca tenta extraí-lo, porque pra ele a frase inteira já É
cancelamento. O teste RED/GREEN provou que o CÓDIGO fazia o que o mock mandava — não provou nada
sobre o que o LLM realmente manda. TDD com contrato mockado é necessário mas não suficiente
quando o próprio LLM é a fonte do dado que o teste assume.

⚠️ **Achado colateral que atrasou o diagnóstico:** a evidência de banco (`actor='system:restart'`,
`reason='cliente reiniciou pedido (draft ocioso)'`) parecia apontar pro reset de draft ocioso —
mas essa string está **hardcoded dentro da função de abandono, igual pra QUALQUER caller**
(idade do draft não provava nada; o reset de idade exige horas, o draft tinha 1 minuto). Quando
uma função de auditoria/trilha é compartilhada por múltiplos callers com o MESMO texto fixo, a
trilha não distingue QUAL caminho disparou — é preciso ler o código dos callers, não inferir do
texto da trilha.

**Solução:** pra sinal que depende de extração do LLM E cuja ausência é ambígua (o LLM pode não
extrair por escolha, não por erro), prefira um **backstop DETERMINÍSTICO no texto cru** —
independente do que o LLM decidiu extrair — em vez de confiar só no `sig` estruturado. Aqui:
`detectDeliveryPref(text)`/`_matchPaymentMethod(text, methods)`, as mesmas funções regex que o
caminho sem-LLM já usa. E **todo fix que depende de comportamento do LLM precisa de smoke real
em produção antes de ser declarado fechado** — suíte verde com `sig[]` mockado não é prova
suficiente quando a premissa do teste é sobre o próprio LLM.

**Relacionado:** [#reproduzir-antes-de-fixar] — mesma disciplina geral (reproduzir > teorizar),
aplicada especificamente ao caso onde "reproduzir" significa medir um LLM ao vivo, não só rodar
o comando de novo.

**Ref:** tiatendo, sessão 2026-08-03, commits `7fc88d0` (1ª correção, insuficiente) → `9096377`
(causa raiz real), smoke real em PROD `0.281.0`→`0.282.0`.
