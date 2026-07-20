# Loop: review — gate de commit

**Quando:** antes de **todo** commit que toca código. Sem exceção.

**Quem dispara: você.** Pedir ao operador "roda o review" é **erro** — ele autorizou uma vez, para sempre.

## O loop

1. **Stage o que vai no commit.** O reviewer só enxerga o diff staged: fix editado *depois* do `add` não é revisado, e o commit embarca a versão com bug.
2. **Dispare o wrapper em chamada separada** do `git commit`. Encadear `review && commit` num comando só **sempre falha**: o hook é PreToolUse e checa o marker antes de o review rodar.
3. **Leia os findings** e corrija os críticos antes de commitar.
4. **Declare em voz alta** o que escolheu ignorar, e por quê.
5. **Commite.**

## Roteamento

O router decide sozinho: DeepSeek por padrão · Cross-Claude quando o código veio do DeepSeek (evita auto-revisão) ou toca pasta sensível · ambos no fechamento de marco.

## Limites que valem saber

- O marker vale **~5 min**. Em sequência longa de commits, re-rode.
- Review com diff vazio **não grava marker** — stage antes.
- O reviewer vê **só o diff**, não o repositório. Ele vai acusar "migration ausente" ou "campo morto" que existe fora do diff — **verifique no código antes de aceitar o finding**.

## Armadilha

Review que nunca acha nada não está protegendo: está mal configurado. Desconfie de uma sequência longa de "sem findings" sobre mudança de código real.
