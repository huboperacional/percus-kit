## Hook pre-commit (R11) é PreToolUse: "review && commit" numa chamada só sempre bloqueia {#pretooluse-review-commit}

`tags: pre-commit, hook, PreToolUse, percus-review-auto, marker stale, R11, git commit bloqueado, review antes de commit, chamada separada`

**Contexto:** o hook `pre-commit-check` bloqueia `git commit` se o último `.deepseek/reviews/*.jsonl` tem >5min. A tentação é encadear `git add ... && pwsh percus-review-auto.ps1 && git commit` numa **única** chamada Bash — e ela é bloqueada mesmo depois do review rodar.

**Causa raiz:** o hook é **PreToolUse** (inspeciona o comando Bash e barra ANTES de executá-lo), não um git hook nativo. Ele vê o `git commit` no comando e checa a freshness do marker **no instante do pre-check** — quando o `percus-review-auto.ps1` do mesmo comando ainda NÃO rodou. Marker velho → bloqueia o comando inteiro (o review nem chega a rodar). (Observado também: ele barra `cat >>`/writes a arquivos tracked do repo com marker velho.)

**Solução:** rodar o review em uma chamada Bash **SEPARADA** do commit:
1. `git add <arquivos>`
2. (chamada separada) `pwsh -File "...\percus-review-auto.ps1"` — escreve o marker fresco.
3. (chamada separada) `git commit ...` — agora o pre-check vê o marker <5min e passa.
Corolário: o review com **diff vazio** (nada staged/tracked) NÃO escreve marker — stage o arquivo antes de rodar o review. O marker vale ~5min: em features com muitos commits, re-rode antes de cada commit fora da janela.

**Ref:** sessão Session Resume auth-service 2026-07-12; memória `session_resume_implementado_2026-07-12`.
