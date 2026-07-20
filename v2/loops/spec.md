# Loop: spec — requisito testável

**Quando:** feature não-trivial, depois do `grilling` e antes de qualquer código.

**Por quê:** requisito que não dá para testar não dá para verificar — e vira discussão no fim, quando custa caro.

## Formato: EARS

Cada requisito funcional é **gatilho + resposta observável**:

`QUANDO <gatilho> O SISTEMA DEVE <resposta observável>`

- ✅ QUANDO o usuário envia OTP expirado, O SISTEMA DEVE responder 401 com `error_code: otp_expired`.
- ❌ "O sistema deve tratar OTP expirado corretamente." — "corretamente" não é observável.

Variações: `ENQUANTO <estado> ... DEVE ...` (condição de estado) · `DEVE SEMPRE ...` (invariante) · `SE <condição de erro> ENTÃO DEVE ...` (caminho indesejado).

## Estrutura mínima

1. **Problema** — o que dói hoje, com evidência. Não "seria bom ter".
2. **Não-objetivos** — o que fica fora. *Esta seção evita mais retrabalho que todas as outras juntas.*
3. **Requisitos funcionais** — EARS, numerados.
4. **Critério de pronto** — mensurável. "Rápido" não é; "p95 < 300ms" é.
5. **Riscos e decisões em aberto.**

## Ao fechar

**Rode o conselho automaticamente** (`loops/conselho.md`, modo `analyze`). Sem pedir permissão.

O veredito volta como `PRONTA | AJUSTAR | BLOQUEADA`:

- **PRONTA** → cole o veredito na spec; a feature vira `[0]` no `PLANO.md`.
- **AJUSTAR / BLOQUEADA** → corrija e re-rode. Não avance com spec bloqueada.

## Armadilhas

- **Vazar o COMO para dentro do O QUÊ.** Stack, biblioteca e schema vivem no plano, não na spec.
- **Critério de pronto que ninguém sabe medir.** Se você não sabe como verificar, o requisito ainda não existe.
- **Spec longa como sinal de rigor.** Rigor é requisito testável, não volume.
