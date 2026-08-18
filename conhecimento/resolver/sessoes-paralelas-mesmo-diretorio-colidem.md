## Duas sessões Claude no MESMO diretório de trabalho colidem em checkout E em deploy, não só em commit {#sessoes-paralelas-mesmo-diretorio-colidem}

`tags: git worktree, sessão paralela, checkout compartilhado, deploy autônomo, colisão, race condition, docker service update, migration alembic`

**Contexto:** duas sessões Claude Code trabalhando ao mesmo tempo em frentes DIFERENTES do mesmo
projeto (`Paid Media Automation`), cada uma com autonomia de deploy (R5/R9), sem worktree isolado —
ambas operando no mesmo `d:/.../repo` compartilhado. Uma sabia da outra ("existe uma sessão principal
rodando em paralelo"); a outra não tinha visibilidade nenhuma.

**Sintoma, em duas camadas:**
1. **Git:** a outra sessão rodou `git checkout -b nova-branch` no meio da minha sessão. Meu próximo
   `git commit` foi silenciosamente parar NO BRANCH DELA (checkout compartilhado = HEAD compartilhado),
   sem eu perceber até checar `git branch --show-current` depois do fato.
2. **Deploy (mais grave, produção real):** minutos depois do meu `docker service update` convergir,
   o dela convergiu por cima — sem coordenação, cada `docker service update` simplesmente vence o
   anterior. Confirmado via `docker service inspect --format '{{.PreviousSpec...Image}}'`: minha
   imagem tinha sido a `PreviousSpec`. A outra sessão, sem contexto da minha, tratou meu deploy como
   "não autorizado" e reverteu (incluindo downgrade de uma migration Alembic aditiva — sem perda de
   dado, mas ainda assim uma ação de schema disparada por engano).

**Causa raiz:** autonomia de deploy (R5/R9) foi desenhada pensando em UMA sessão por vez. Duas
sessões autônomas, mesmo diretório, mesmo alvo de produção = duas escritoras sem lock. Nem git
worktree nem coordenação de deploy são automáticos — cada um exige ação deliberada.

**Solução:**
- **Git:** ao saber (ou suspeitar) de sessão paralela no MESMO projeto, criar um `git worktree`
  isolado **ANTES do primeiro commit**, não depois do primeiro susto. `git branch --show-current`
  antes de qualquer commit se a suspeita surgir tarde.
- **Deploy:** depois de QUALQUER `docker service update`, reconfirmar `docker service ls`/
  `docker service inspect` antes de assumir que o estado permanece — não é garantido, mesmo minutos
  depois. Se detectar sobrescrita: **não** brigar de volta cegamente (vira cabo-de-guerra). Em vez
  disso, criar um branch novo a partir do commit ATUALMENTE deployado (`git checkout -b X <sha-atual>`),
  mergear o próprio trabalho por cima (preserva as DUAS frentes), rebuildar e redeployar uma imagem
  ÚNICA que contém tudo — resolve de vez, não só reverte a reversão.
- **Recuperação de trabalho perdido no meio da confusão:** antes de assumir perda, checar
  `git stash list` — uma sessão cuidadosa que precisa trocar de branch/ref debaixo de outra costuma
  stashar em vez de descartar (inclusive `git stash -u`, capturando arquivos novos/untracked). `git
  stash show --stat stash@{N}` mostra o conteúdo sem aplicar.
- **Migration Alembic pode já ter rodado sozinha:** conferir se o serviço tem
  `alembic upgrade head` automático no `entrypoint.sh` (padrão fail-closed comum) ANTES de assumir
  que uma migration "ainda não aplicada" continua pendente depois de qualquer cutover novo — o boot
  do container pode ter aplicado sem nenhum comando manual.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156) — frente "Fluxo de Páginas" colidindo
com "Funil etapas editáveis", reconciliadas via `feat/page-flow-merged` → `master` (`758946e8`).
