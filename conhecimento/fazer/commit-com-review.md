## Commitar no canon / projeto (com review obrigatório R11) {#commit-com-review}

`tags: git, commit, review, R11, pre-commit, push, canon, co-authored`

**Quando:** qualquer commit que toca código ou docs do canon.

**Passos:**
1. Rode o review **antes** do commit (R11 — hook bloqueia se não houver review nos últimos 5 min):
   `pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"` (ou `.sh` no Unix).
2. Se o stderr trouxer `__PERCUS_NEEDS_CROSS_CLAUDE__`, dispare o subagent Sonnet e salve em
   `.deepseek/reviews/<ts>-cross-claude.jsonl`.
3. Trate findings de bug/regressão antes de commitar; "preferência de estilo" pode ignorar (declare).
4. Commit com trailer de autoria. Multi-linha em PowerShell: here-string single-quoted `@'...'@`.

**Comando (trailer canônico):**
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
Se aplicou saída do wrapper DeepSeek (R13): adicione `Co-implemented-by: deepseek-v4`.
Se marcou `[5-T]`: adicione `CRUD-verified: YYYY-MM-DD HH:MM`.

**Armadilhas:** nunca `--no-verify`; nunca commitar sem review fresco; em `main` do canon, branch antes
se for mudança grande. Ver [origin-stale-resume](../resolver/origin-stale-resume.md) (fetch+compare origin antes).
