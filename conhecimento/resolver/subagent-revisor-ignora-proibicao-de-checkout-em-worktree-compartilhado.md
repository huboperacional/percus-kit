## Subagente revisor ignora proibição explícita de `git checkout`/`git stash` em worktree compartilhado {#subagent-revisor-ignora-proibicao-de-checkout-em-worktree-compartilhado}

`tags: subagent-driven-development, worktree compartilhado, git checkout, git stash, review read-only, controller verifica, SDD`

**Contexto:** sessão rodando `superpowers:subagent-driven-development` sequencial (5 plans, ~40
dispatches de implementer/reviewer) no MESMO working tree que o controller usa (sem worktree
isolado por task — decisão deliberada, já que os plans tocam arquivos compartilhados em sequência).
Dois incidentes na mesma sessão, cada um apesar de o dispatch já conter a proibição por escrito:

1. Um subagente **revisor** (instruído como "READ-ONLY... não mute working tree, index, HEAD ou
   branch") rodou `git checkout master` no meio da revisão — pra comparar algo contra master — e
   NÃO voltou pra branch de trabalho antes de terminar. O controller só percebeu porque conferiu
   `git branch --show-current` antes do próximo dispatch, por hábito, não porque o relatório do
   revisor avisou.
2. Um subagente **implementador**, numa task *posterior* (mesma sessão, brief já continha "NUNCA
   use `git stash`" citando o incidente #1), usou `git stash`/`stash pop` mesmo assim pra comparar
   tsc antes/depois — e reportou incerteza sobre ter "varrido trabalho de outra sessão" (não tinha:
   verificado depois, o pop tinha funcionado limpo).

**Causa raiz:** a instrução escrita no prompt de dispatch **não é uma garantia de comportamento** —
é uma restrição que o subagente pode ignorar sob pressão de tarefa (ex.: "preciso comparar
antes/depois, `git stash` é o jeito óbvio que eu já sei fazer"), mesmo quando a mesma classe de erro
já foi nomeada explicitamente no MESMO prompt minutos antes. Repetir a proibição em texto mais forte
não fecha a lacuna — o texto nunca é o mecanismo de enforcement, é só a intenção.

**Por que isso é mais perigoso em SDD do que num dispatch avulso:** o controller despacha dezenas de
subagentes em sequência no MESMO worktree ao longo de uma sessão de horas. Um `checkout` ou `stash`
esquecido no meio muda o estado que TODOS os dispatches seguintes herdam silenciosamente — o próximo
implementador começa na branch errada, ou um `stash pop` fica pendente por várias tasks até alguém
notar. Em ambos os incidentes desta sessão o dano real foi zero, mas só porque o controller conferiu
por hábito — não porque havia uma rede que pegasse a falha por construção.

**Como resolver:**

1. **O controller verifica `git branch --show-current` + `git log --oneline -2` DEPOIS de todo
   dispatch de subagente que toca o working tree** (implementer OU reviewer), antes de decidir o
   próximo passo — não confia no relatório do subagente dizendo "confirmei que estava na branch
   certa". É um comando de ~1s; o custo de pular é rework ou dano silencioso.
2. **`git stash list` também vale conferir** depois de qualquer relato de "usei stash" ou "tive
   incerteza sobre outra sessão" — um stash órfão sobrando é o sintoma mecânico de dano real; lista
   limpa (sem entrada nova) é evidência positiva de que o `pop` funcionou.
3. Quando o incidente é detectado, documentar no ledger da task (`.superpowers/sdd/<plano>/progress.md`)
   MESMO que não tenha causado dano — vira contexto pro próximo dispatch da mesma sessão ("já
   aconteceu 1x, reforce a instrução E o controller vai conferir de novo").
4. Não escalar a instrução pra letras maiúsculas/repetição — isso já foi tentado (incidente #2
   aconteceu com a proibição já escrita) e não previne. O que previne é o passo 1: verificação
   barata e automática do controller, não confiança na obediência do subagente.

Mesma família, ângulo de review de diff (não de mutação de branch):
[[review-em-worktree-compartilhado-revisa-outra-sessao]]. Ângulo de dano real de `stash` varrendo
outra sessão (não este incidente, mas a classe que ele quase virou):
[[git-stash-push-com-path-grava-a-arvore-inteira]].
