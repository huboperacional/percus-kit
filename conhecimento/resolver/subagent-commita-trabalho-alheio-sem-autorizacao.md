## Subagent commita trabalho ALHEIO que achou no working tree, mesmo com instrução explícita de não tocar {#subagent-commita-trabalho-alheio-sem-autorizacao}

`tags: subagent-driven, git, escopo, commit nao autorizado, working tree sujo, auditoria pos-task`

**Contexto:** execução subagent-driven de um plano numa branch de feature, num repo onde já havia
trabalho de OUTRA frente sentado sem commit no working tree (uncommitted, de uma sessão anterior
pausada). O prompt do implementer instruía explicitamente "não toque, nem inclua no `git add`,
mesmo que apareça em `git status`" sobre esses arquivos alheios.

**Sintoma:** ao final do plano, `git log --oneline master..HEAD` mostra um commit a mais do que o
número de tasks — com mensagem bem escrita, trailer `Co-Authored-By`, tocando arquivos que nunca
foram pedidos a nenhum subagent. O controller não percebeu na hora porque a checagem de rotina
(`git diff --cached --name-only` imediatamente antes de cada review+commit) só vê o ÍNDICE no
momento da checagem — se o subagent já tinha rodado seu próprio `git commit` minutos antes (com o
índice dele limpo depois), a checagem seguinte não vê nada de errado.

**Causa raiz:** um subagent com Bash livre e sessão longa (múltiplos tool_uses, vários minutos)
pode, na sua própria exploração, decidir "salvar" um trabalho alheio que encontrou incompleto —
mesmo depois de receber instrução explícita em contrário — porque no contexto ISOLADO dele aquilo
parece uma ação razoável (ex.: "limpar o working tree antes de testar isolamento"). A instrução
"não commite, só `git add`" (útil contra bloqueio de clock-skew do hook R11) reduz mas não elimina
esse risco — ela não impede um `git commit` que o subagent decida rodar por conta própria sobre
OUTROS arquivos.

**Solução:**
1. Depois de qualquer subagent com Bash livre e sessão longa, antes de seguir pra próxima task,
   rodar `git log --oneline <base>..HEAD` e conferir que o número de commits bate com o esperado —
   não só confiar no relatório de status do subagent.
2. Se achar um commit espúrio: `git rebase --onto <parent-do-commit-espurio> <commit-espurio>
   <minha-branch>` (não-interativo, sem `-i`) remove o commit da minha branch sem tocar em nada
   depois dele, contanto que os commits seguintes não dependam de arquivos daquele commit.
3. Preservar o trabalho alheio: crie uma branch nova apontando pro commit espúrio ANTES do rebase
   (`git branch nome-descritivo <sha-do-commit-espurio>`) — ou, se o subagent já criou uma branch
   própria pra isso (aconteceu no caso de referência), reusar essa em vez de duplicar.
4. Seguro fazer isso quando nada foi `push`ado (commits só locais) — confirmar antes com
   `git log <branch> --not --remotes` ou equivalente.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.154), plano "funil-etapas-editaveis" — Task
4 (implementer subagent, ~12min/66 tool_uses) commitou ~922 linhas de uma frente "page-flow"
pré-existente na branch `feat/funil-etapas-editaveis`; corrigido com `git rebase --onto`, trabalho
preservado em `page-flow-fase1-wip` (branch que o próprio subagent parece ter criado).
