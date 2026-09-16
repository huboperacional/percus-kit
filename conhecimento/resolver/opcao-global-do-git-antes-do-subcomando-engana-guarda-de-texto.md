## Opção global do git antes do subcomando engana a guarda que procura `git push` no texto {#opcao-global-do-git-antes-do-subcomando-engana-guarda-de-texto}

`tags: git, push, git -C, git -c, opcao global, external-action-guard, R20, guarda de texto, regex, PreToolUse, autorizacao, auditoria, fail-open, seguranca, bypass`

**Sintoma:** push sai sem autorização e sem linha de auditoria, embora o hook de ação externa esteja
registrado e "funcionando" nos testes. Visto como sintoma brando: "o hook não gravou a auditoria".

**Caso medido (2026-09-16, percus-kit).** Os 2 pushes do dia foram feitos com
`git -C "D:/Claud Automations/percus-kit" push origin main`. Nenhum gerou a linha em
`.percus/autorizacoes-usadas.jsonl`. Na investigação: o `external-action-guard` (`.ps1` e `.sh`)
casava a ação com um padrão do tipo `git\s+push` — subcomando **colado** no `git`. Com qualquer opção
global no meio, o hook não via ação externa nenhuma e saía 0 **antes** de ler a autorização. Liberavam
sem autorização: `git -C <dir> push`, `git -C '<dir>' push`, `git -c k=v push`, `git --no-pager push`,
`git.exe push`. A autorização daquele dia existia — o hook só nunca olhou. No dia anterior o push foi
feito com `cd <dir> && git push` e a auditoria foi gravada, o que mascarou o furo.

**Por que passou despercebido:** os testes do guard usavam a forma canônica `git push`. O sintoma
visível era a falta de auditoria (parece bug de log), e não o bloqueio ausente (que só aparece
quando alguém empurra SEM autorização).

**Regra para guarda que casa comando por texto:**
- O subcomando do git vem depois de **zero ou mais opções globais**: `-C <dir>`, `-c <k=v>`,
  `--git-dir=`, `--work-tree=`, `--no-pager`, `--exec-path`, e o executável pode ser `git.exe` ou
  caminho absoluto. Case o subcomando pulando essas opções, não colado no `git`.
- Teste a guarda com a **matriz de formas de invocação**, não só com a canônica — inclusive `;`, `&&`,
  `|`, `$(...)`, `bash -c "..."`.
- Onde a forma não puder ser resolvida com certeza (`-C "$VAR"`, `-C` relativo depois de `cd` no mesmo
  comando), **bloqueie** (fail-closed). Guarda de ação externa não pode ser fail-open por não entender.
- Sintoma "hook não gravou auditoria" em ação externa é, até prova em contrário, **hook que não viu a
  ação** — investigue como bypass, não como bug de log.

**Relacionado:** [[git-c-com-variavel-o-hook-le-o-texto-e-procura-o-repo-errado]] (a mesma forma `-C`
enganando outro hook) · [[guarda-de-path-protegido-tokeniza-por-espaco-e-corta-o-alvo]].
