## Commit passa sem review R11 e ninguém percebe: hook novo não registrado nesta máquina {#r11-hook-nao-registrado-maquina}

`tags: R11, review, deepseek, cross-claude, pre-commit, hook, percus:health, drift de versao, matcher, settings.json, enforcement, gate silencioso, latest.jsonl`

**Sintoma:** um `git commit` que toca pasta sensível (ex.: `services/api/app/core/`) passa direto,
sem nenhum sinal de review — nada trava, nada avisa. O único indício é o aviso do hook
`SessionStart`/`SessionStart:resume` do `percus:health`: *"1 problema(s) no enforcement: versão
instalada (X) diferente da do kit (Y) — mudança de REGISTRO (matcher, hook novo) ainda não vale
nesta máquina"*. Fácil de tratar como ruído porque o próprio aviso diz "não bloqueia nada".

**Causa raiz:** o gate R11 (DeepSeek + Cross-Claude no pre-commit) depende de um hook
`PreToolUse`/`PostToolUse` registrado em `.claude/settings.json` do repo-alvo. Quando o plugin
`percus-review` sobe de versão e o **registro** desse hook muda (novo matcher, novo hook), a
atualização não se propaga sozinha pra cada máquina onde o repo foi clonado — a máquina continua
com o registro da versão anterior (ou sem registro nenhum) até alguém reinstalar. Verificação
direta: `.deepseek/reviews/latest.jsonl` não muda de tamanho/data depois do commit (fica com o
timestamp da ÚLTIMA vez que o hook rodou de verdade, possivelmente dias/semanas atrás), e
`cat .claude/settings.json` do repo não tem seção `hooks` nenhuma.

**Como confirmar (evidência, ~10s):** antes de confiar que "o review vai rodar sozinho no commit",
rode:
```bash
ls -la .deepseek/reviews/latest.jsonl   # data recente = hook rodou recentemente; velha = suspeita
grep -c '"hooks"' .claude/settings.json  # 0 = sem hook registrado nesta maquina
```

**Solução imediata (não espera reinstalar):** o `Skill` tool bloqueia invocação direta de
`percus-review:review` (`disable-model-invocation` — reservado pra invocação explícita do
operador), então o agente **não pode** disparar sozinho. Só o operador digitando
`/percus-review:review` roda de verdade. Se o commit já aconteceu sem review, rode o comando
retroativamente com `--base <commit-anterior-ao-seu>` (o router, sem `--base`, revisa o working
tree atual — que pode estar vazio ou ser outra coisa se você já commitou) e trate os findings antes
de considerar o commit "revisado".

**Solução definitiva:** reinstalar/atualizar o gate nesta máquina especificamente (skill
`percus-review:install-git-hooks`) — a versão do plugin sozinha (`plugins update`) não repropaga o
registro do hook pro `.claude/settings.json` de cada repo já clonado.

**Ref:** auth-service, registro da audience `empresa-milionaria`, 2026-08-14. Plugin instalado
6.35.0, kit em 6.36.0 no momento do incidente.
