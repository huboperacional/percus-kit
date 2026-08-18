## Conselho "revisa a coisa errada" / prompt stale entre runs {#conselho-prompt-stale}

`tags: council, conselho, orchestrator, prompt stale, /tmp, arquivo fixo, windows path, revisa errado, repetido`

**Contexto:** ao rodar o `council-orchestrator` duas vezes seguidas, a 2ª rodada "revisa a pergunta
antiga" — o conselho responde sobre o prompt anterior, não o novo.

**Causa raiz:** command docs salvavam a pergunta num **nome de arquivo FIXO** (`/tmp/council-q.txt`).
No Windows `/tmp/...` resolve pra `d:\tmp\...`; se a 2ª escrita não sobrescreveu, o orchestrator leu o
prompt VELHO. NÃO era cache do orchestrator (ele lê `Get-Content -Raw` fresco) nem o
`prompt_cache_hit_tokens` da DeepSeek (red herring de cache de prefixo server-side).

**Solução:** arquivo temp **único por invocação** — `Join-Path $env:TEMP "council-q-$([guid]::NewGuid().ToString('N')).txt"`
(Windows) ou `mktemp` (Unix), escrito e consumido na mesma invocação, com cleanup. Idem pro
`-CrossClaudeFile`. Alternativa à prova de stale: passar o prompt por **stdin**. Corrigido em v6.16.1.

**Ref:** `CANON_VERSION.md` changelog v6.16.1; memória `project_council_stale_prompt_bug`.
