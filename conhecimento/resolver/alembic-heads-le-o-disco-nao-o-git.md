## `alembic heads` lê o disco, não o git — árvore compartilhada encadeia numa revisão fantasma {#alembic-heads-le-o-disco-nao-o-git}

`tags: alembic, migration, down_revision, arvore-de-trabalho-compartilhada, duas-sessoes-uma-arvore, untracked, CI quebrado, head fantasma, revisao inexistente`

**Contexto:** vários agentes/sessões trabalham na MESMA árvore de trabalho (não em worktrees
isoladas) — padrão comum quando o projeto prioriza throughput sobre isolamento e coordena por
`ListAgents`/mensagem em vez de branch por sessão. Uma task cria uma migration Alembic nova e,
antes de escrever `down_revision`, roda `python -m alembic heads` pra descobrir o head atual —
prática correta, recomendada, e mesmo assim o resultado sai errado.

**Causa raiz:** `alembic heads` enumera os arquivos **físicos** dentro de
`alembic/versions/`, não os arquivos rastreados pelo git. Se OUTRA sessão, na mesma árvore, já
tiver escrito (mas ainda não commitado) o arquivo de uma migration própria, esse arquivo
**conta como head candidato** para qualquer `alembic heads`/`alembic revision --head` rodado
por qualquer sessão, inclusive uma que não tem nada a ver com ele. A migration nova encadeia
(`down_revision = '<revisão do arquivo alheio untracked>'`) e o commit sai limpo — a suíte de
testes não pega, porque roda contra SQLite via `create_all()`/metadata, nunca `alembic upgrade`
de verdade.

**Por que ninguém vê antes do deploy/CI:** o defeito só se manifesta num checkout **sem** o
arquivo untracked alheio — um clone limpo, um container de CI, o próximo `git pull` de outra
máquina. Nesses ambientes, `alembic upgrade head` (ou `alembic heads`) falha porque a revisão
referenciada em `down_revision` não existe em nenhum arquivo — nem rastreado, nem no disco. Na
própria árvore de trabalho onde o bug nasceu, tudo continua funcionando (o arquivo fantasma
ainda está lá), então até `alembic heads` rodado de novo, na mesma sessão, "confirma" que está
tudo certo — o próprio ato de verificar usa a fonte contaminada.

**Diagnóstico:**
1. `git ls-tree -r HEAD -- <pasta de migrations>` (ou `git ls-files`) — lista só o que está no
   commit. Compare com `ls <pasta de migrations>` (disco). Qualquer arquivo no disco ausente do
   `ls-tree` é suspeito.
2. Se a migration nova aponta (`down_revision`) pra um desses arquivos ausentes do git, é o
   bug: a cadeia está presa numa revisão que não existe fora desta árvore de trabalho.
3. Recalcule o head "de verdade" olhando só os arquivos rastreados — normalmente é a última
   migration commitada antes da sua task começar.

**Fix:** troque o `down_revision` pra apontar pro head **commitado** real. Não apague nem
toque no arquivo alheio untracked — ele pertence a outra sessão/task e vai encadear sozinho
quando ela commitar.

**Prevenção:** antes de confiar em `alembic heads` numa árvore compartilhada, rode também
`git status --short <pasta de migrations>` — qualquer `??` ali é um head candidato que o git
não reconhece. Numa árvore com N sessões ativas, isso é rotina, não exceção; é a mesma classe
de risco que "duas sessões, uma árvore de trabalho" já cobre pra `commit`/`add`, só que
Alembic tem sua PRÓPRIA noção de "o que existe", desacoplada do índice do git.

**Ref:** Empresa Milionária, 28/08 — Task 10 do plano `2026-08-28-orcamento-pj-backend.md`
(`AlertaOrcadoEnviado`) encadeou em `a8ad43d2efd4`, um arquivo untracked de outra sessão
(`a8ad43d2efd4_trigger_soma_zero_liquidacao.py`). Achado pelo task-reviewer antes do commit
chegar a produção; corrigido trocando `down_revision` pro head commitado real (`29a736aaa1ce`).
