## Gate de commit (R11) trava com "invalid_request_error: deepseek-chat" {#deepseek-chat-modelo-descontinuado}

`tags: deepseek, deepseek-chat, deepseek-v4, invalid_request_error, modelo descontinuado, review, R11, gate de commit, hook pre-commit, percus-review, nao consigo commitar`

**Contexto:** o hook pre-commit (R11) exige um `/percus-review:review` fresco (<5 min) e bloqueia o
commit. Ao rodar o review (via bypass `deepseek-review.ps1` ou pela skill), a chamada à DeepSeek
falha com `{"error":{"message":"The supported API model names are deepseek-v4-pro or
deepseek-v4-flash, but you passed deepseek-chat.","type":"invalid_request_error"}}`. Sem review
que grave `latest.jsonl`, **nenhum commit passa** — trava todos os projetos Percus de uma vez.

**Causa raiz:** a DeepSeek **descontinuou o alias `deepseek-chat`** (e `deepseek-reasoner`). Os
scripts do plugin `percus-review` (ex.: `deepseek-review.ps1`, `review-router.ps1`) têm o modelo
antigo **hardcoded como default** (`[string]$Model = "deepseek-chat"`). Enquanto o default não for
atualizado, toda invocação quebra — inclusive a auto-invocada pelo gate.

**Solução:** passe o modelo novo na chamada — `deepseek-v4-flash` (barato, serve pra review de
docs/diff pequeno) ou `deepseek-v4-pro` (diffs grandes/sensíveis):

```powershell
& "...\percus-review\<versão>\scripts\deepseek-review.ps1" -Model deepseek-v4-flash
```

Isso regrava `.deepseek/reviews/latest.jsonl` e o hook libera o commit. **Fix definitivo (dono do
canon/plugin):** trocar o default `deepseek-chat` → `deepseek-v4-flash` em TODOS os scripts do
plugin (`deepseek-review.ps1`, `deepseek-impl.{ps1,sh}` do R13, `review-router.ps1`) e no
`.sh` equivalente. Enquanto não sai, o override por `-Model` é o desbloqueio.

**Ref:** Família Milionária, checkpoint de 2026-07-24 (o `deepseek-chat` funcionou às 18:56 de
07-23 e quebrou overnight). Plugin `percus-review` 6.29.0.
